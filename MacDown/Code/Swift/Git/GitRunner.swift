import Foundation

/// Result of one git command.
struct GitOutput {
    var status: Int32
    var stdout: Data
    var stderr: String

    var text: String { String(decoding: stdout, as: UTF8.self) }
}

enum GitError: Error, Equatable, LocalizedError {
    case gitNotFound
    case failed(command: String, status: Int32, message: String)
    case timedOut(command: String)
    case notARepository
    case invalidName(String)

    var errorDescription: String? {
        switch self {
        case .gitNotFound: return "Git is not installed."
        case let .failed(_, _, message): return message.isEmpty ? "The Git command failed." : message
        case let .timedOut(command): return "Git took too long (\(command))."
        case .notARepository: return "This folder is not a Git repository."
        case let .invalidName(name): return "“\(name)” is not a valid branch name."
        }
    }
}

/// Runs the system `git` as a child process.
///
/// - Never uses a shell, so file names and messages cannot inject commands.
/// - Never waits for input: terminal prompts are off, so a command that needs a
///   password fails instead of hanging.
/// - Has a time limit, and is async, so callers stay off the main thread.
/// - Output language is fixed to C, so parsing does not depend on the user's locale.
struct GitRunner {
    var executable: URL
    var timeout: TimeInterval = 30

    /// Finds git: Homebrew and /usr/local first (newer), then /usr/bin/git.
    static func locate() -> URL? {
        let candidates = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"]
        return candidates.map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    init?(timeout: TimeInterval = 30) {
        guard let url = GitRunner.locate() else { return nil }
        executable = url
        self.timeout = timeout
    }

    init(executable: URL, timeout: TimeInterval = 30) {
        self.executable = executable
        self.timeout = timeout
    }

    /// Runs `git <arguments>` in `directory`. A non-zero exit status is returned, not thrown.
    func run(_ arguments: [String], in directory: URL, input: Data? = nil,
             allowedExitCodes: Set<Int32> = [0]) async throws -> GitOutput {
        let output = try await execute(arguments, in: directory, input: input)
        guard allowedExitCodes.contains(output.status) else {
            throw GitError.failed(command: arguments.first ?? "", status: output.status,
                                  message: output.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    private func execute(_ arguments: [String], in directory: URL, input: Data?) async throws -> GitOutput {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_OPTIONAL_LOCKS"] = "0"     // Status must not block other git commands.
        environment["LC_ALL"] = "C"
        environment["GIT_PAGER"] = "cat"
        environment.removeValue(forKey: "GIT_ASKPASS")
        process.environment = environment

        let outPipe = Pipe(), errPipe = Pipe(), inPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = input == nil ? FileHandle.nullDevice : inPipe

        let timeout = self.timeout
        let command = arguments.first ?? ""

        return try await withCheckedThrowingContinuation { continuation in
            // Read both pipes while the process runs, so a full pipe cannot block git.
            let group = DispatchGroup()
            var outData = Data(), errData = Data()
            let readQueue = DispatchQueue(label: "git.read", attributes: .concurrent)
            group.enter()
            readQueue.async { outData = outPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            group.enter()
            readQueue.async { errData = errPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }

            let lock = NSLock()
            var finished = false
            var timedOut = false
            func finish(_ result: Result<GitOutput, Error>) {
                lock.lock(); defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                continuation.resume(with: result)
            }

            process.terminationHandler = { proc in
                group.notify(queue: .global()) {
                    lock.lock(); let didTimeOut = timedOut; lock.unlock()
                    if didTimeOut {
                        finish(.failure(GitError.timedOut(command: command)))
                    } else {
                        finish(.success(GitOutput(status: proc.terminationStatus, stdout: outData,
                                                  stderr: String(decoding: errData, as: UTF8.self))))
                    }
                }
            }
            do {
                try process.run()
            } catch {
                try? outPipe.fileHandleForWriting.close()
                try? errPipe.fileHandleForWriting.close()
                finish(.failure(error))
                return
            }
            if let input = input {
                DispatchQueue.global().async {
                    try? inPipe.fileHandleForWriting.write(contentsOf: input)
                    try? inPipe.fileHandleForWriting.close()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    lock.lock(); timedOut = true; lock.unlock()
                    process.terminate()
                }
            }
        }
    }
}
