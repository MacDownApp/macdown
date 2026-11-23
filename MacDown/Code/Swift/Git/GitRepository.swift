import Foundation

/// A Git repository, driven through the system `git`.
///
/// Every method is async and runs git in a child process, so none of them can
/// block the main thread. This type holds no state beyond the repository
/// location, so it is safe to call from several tasks.
final class GitRepository {
    let root: URL
    private let runner: GitRunner

    private init(root: URL, runner: GitRunner) {
        self.root = root
        self.runner = runner
    }

    /// Opens the repository that contains `directory`. Returns nil if there is
    /// none, or if git is not installed.
    static func open(containing directory: URL, runner: GitRunner? = GitRunner()) async -> GitRepository? {
        guard let runner = runner else { return nil }
        var isDirectory: ObjCBool = false
        var start = directory
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            start = directory.deletingLastPathComponent()
        }
        guard let output = try? await runner.run(["rev-parse", "--show-toplevel"], in: start),
              let line = output.text.split(separator: "\n").first else { return nil }
        return GitRepository(root: URL(fileURLWithPath: String(line), isDirectory: true), runner: runner)
    }

    // MARK: Reading

    func status() async throws -> GitStatus {
        let output = try await runner.run(
            ["status", "--porcelain=v2", "-z", "--branch", "--untracked-files=normal"], in: root)
        return GitParser.parseStatus(output.stdout)
    }

    func hasCommits() async -> Bool {
        (try? await runner.run(["rev-parse", "--verify", "-q", "HEAD"], in: root, allowedExitCodes: [0, 1])
            .status) == 0
    }

    /// Hunks of the changes between HEAD and the working copy of `path`.
    /// Pass `text` to compare HEAD with unsaved text instead of the file on disk.
    func hunks(for path: String, text: String? = nil) async throws -> [GitHunk] {
        let relative = try relativePath(path)
        let fileURL = root.appendingPathComponent(relative)

        guard await hasCommits(),
              let head = try await runner.run(["show", "HEAD:\(relative)"], in: root, allowedExitCodes: [0, 128]) as GitOutput?,
              head.status == 0
        else {
            // New file (or no commits yet): every line is added.
            let content = try text ?? String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.isEmpty ? 0 : content.split(separator: "\n", omittingEmptySubsequences: false).count
                - (content.hasSuffix("\n") ? 1 : 0)
            guard lines > 0 else { return [] }
            return [GitHunk(oldStart: 0, oldCount: 0, newStart: 1, newCount: lines, patchText: "")]
        }

        if let text = text {
            // Compare two temporary files, so unsaved text can be checked too.
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("macdown-git-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: temp) }
            let old = temp.appendingPathComponent("old"), new = temp.appendingPathComponent("new")
            try head.stdout.write(to: old)
            try text.write(to: new, atomically: false, encoding: .utf8)
            let diff = try await runner.run(
                ["diff", "--no-index", "--no-color", "--no-ext-diff", "--unified=0", "--", old.path, new.path],
                in: temp, allowedExitCodes: [0, 1])
            return GitParser.parseHunks(diff.text)
        }
        let diff = try await runner.run(
            ["diff", "--no-color", "--no-ext-diff", "--unified=0", "HEAD", "--", relative], in: root)
        return GitParser.parseHunks(diff.text)
    }

    /// Gutter markers for the editor.
    func gutterChanges(for path: String, text: String? = nil) async throws -> [GutterChange] {
        GitParser.gutterChanges(try await hunks(for: path, text: text))
    }

    /// Full unified diff of a file, for a diff view. `staged` compares the index with HEAD.
    func diff(for path: String, staged: Bool = false) async throws -> String {
        let relative = try relativePath(path)
        var args = ["diff", "--no-color", "--no-ext-diff"]
        if staged { args.append("--cached") }
        args += ["--", relative]
        return try await runner.run(args, in: root).text
    }

    // MARK: Changing

    func stage(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        _ = try await runner.run(["add", "--"] + paths.map(relativePath), in: root)
    }

    func unstage(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        let relatives = try paths.map(relativePath)
        if await hasCommits() {
            _ = try await runner.run(["reset", "-q", "HEAD", "--"] + relatives, in: root)
        } else {
            _ = try await runner.run(["rm", "--cached", "-q", "-r", "--"] + relatives, in: root)
        }
    }

    /// Commits the staged changes. The message goes through stdin, so any text is safe.
    func commit(message: String, amend: Bool = false) async throws {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GitError.failed(command: "commit", status: 1, message: "The commit message is empty.")
        }
        var args = ["commit", "-F", "-"]
        if amend { args.append("--amend") }
        _ = try await runner.run(args, in: root, input: Data(trimmed.utf8))
    }

    /// Undoes one hunk in the working copy of `path`.
    func revert(_ hunk: GitHunk, in path: String) async throws {
        let relative = try relativePath(path)
        let patch = "diff --git a/\(relative) b/\(relative)\n--- a/\(relative)\n+++ b/\(relative)\n" + hunk.patchText
        _ = try await runner.run(["apply", "-R", "--unidiff-zero", "--whitespace=nowarn", "-"],
                                 in: root, input: Data(patch.utf8))
    }

    /// Restores tracked files to the staged (or committed) version. Cannot be undone.
    func discardChanges(_ paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        _ = try await runner.run(["restore", "--"] + paths.map(relativePath), in: root)
    }

    // MARK: Branches

    func branches() async throws -> [GitBranch] {
        let output = try await runner.run(
            ["for-each-ref", "--format=%(HEAD)|%(refname:short)", "refs/heads"], in: root)
        return output.text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return GitBranch(name: parts[1], isCurrent: parts[0] == "*")
        }
    }

    func switchBranch(to name: String) async throws {
        try await validate(branchName: name)
        _ = try await runner.run(["switch", name], in: root)
    }

    func createBranch(named name: String) async throws {
        try await validate(branchName: name)
        _ = try await runner.run(["switch", "-c", name], in: root)
    }

    private func validate(branchName name: String) async throws {
        let result = try? await runner.run(["check-ref-format", "--branch", name], in: root, allowedExitCodes: [0, 1, 128])
        guard !name.hasPrefix("-"), result?.status == 0 else { throw GitError.invalidName(name) }
    }

    // MARK: Remote

    func fetch() async throws { _ = try await networkRunner().run(["fetch", "--prune"], in: root) }
    func pull() async throws { _ = try await networkRunner().run(["pull", "--ff-only"], in: root) }
    func push() async throws { _ = try await networkRunner().run(["push"], in: root) }

    private func networkRunner() -> GitRunner {
        var r = runner
        r.timeout = max(r.timeout, 120)
        return r
    }

    // MARK: Paths

    /// Path relative to the repository root. Accepts absolute and relative paths.
    func relativePath(_ path: String) throws -> String {
        guard path.hasPrefix("/") else { return path }
        let rootPath = root.resolvingSymlinksInPath().path
        let full = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        guard full.hasPrefix(rootPath + "/") else {
            throw GitError.failed(command: "path", status: 1, message: "The file is outside the repository.")
        }
        return String(full.dropFirst(rootPath.count + 1))
    }
}
