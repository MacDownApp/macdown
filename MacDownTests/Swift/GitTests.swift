import XCTest
@testable import MacDown

// MARK: - Parsing (no git needed)

final class GitParserTests: XCTestCase {
    private func nul(_ parts: [String]) -> Data { Data((parts.joined(separator: "\0") + "\0").utf8) }

    func testStatusParsing() {
        let data = nul([
            "# branch.oid abc123", "# branch.head main", "# branch.upstream origin/main", "# branch.ab +2 -1",
            "1 .M N... 100644 100644 100644 aaa bbb notes.md",
            "1 A. N... 000000 100644 100644 000 ccc new file.md",
            "1 MM N... 100644 100644 100644 aaa bbb both.md",
            "2 R. N... 100644 100644 100644 aaa bbb R100 renamed.md", "old name.md",
            "u UU N... 100644 100644 100644 100644 a b c conflict.md",
            "? untracked.md",
        ])
        let s = GitParser.parseStatus(data)
        XCTAssertEqual(s.branch, "main")
        XCTAssertEqual(s.commit, "abc123")
        XCTAssertEqual(s.upstream, "origin/main")
        XCTAssertEqual(s.ahead, 2)
        XCTAssertEqual(s.behind, 1)
        XCTAssertEqual(s.entries.map(\.path), ["notes.md", "new file.md", "both.md", "renamed.md", "conflict.md", "untracked.md"])
        XCTAssertEqual(s.entries[0].unstaged, .modified)
        XCTAssertNil(s.entries[0].staged)
        XCTAssertEqual(s.entries[1].staged, .added)
        XCTAssertEqual(s.entries[2].staged, .modified)
        XCTAssertEqual(s.entries[2].unstaged, .modified)
        XCTAssertEqual(s.entries[3].staged, .renamed)
        XCTAssertEqual(s.entries[3].originalPath, "old name.md")
        XCTAssertTrue(s.entries[4].isConflicted)
        XCTAssertTrue(s.entries[5].isUntracked)
    }

    func testDetachedHeadAndInitialCommit() {
        let s = GitParser.parseStatus(nul(["# branch.oid (initial)", "# branch.head (detached)"]))
        XCTAssertNil(s.branch)
        XCTAssertNil(s.commit)
        XCTAssertTrue(s.isClean)
    }

    func testHunkParsingAndGutter() {
        let diff = """
        diff --git a/a.md b/a.md
        index 111..222 100644
        --- a/a.md
        +++ b/a.md
        @@ -2,0 +3,2 @@
        +added one
        +added two
        @@ -5 +7 @@
        -old
        +new
        @@ -10,2 +11,0 @@
        -gone 1
        -gone 2

        """
        let hunks = GitParser.parseHunks(diff)
        XCTAssertEqual(hunks.count, 3)
        XCTAssertEqual(hunks[0].newStart, 3); XCTAssertEqual(hunks[0].newCount, 2); XCTAssertEqual(hunks[0].oldCount, 0)
        XCTAssertEqual(hunks[1].oldCount, 1); XCTAssertEqual(hunks[1].newCount, 1)
        XCTAssertTrue(hunks[1].patchText.hasPrefix("@@ -5 +7 @@\n-old\n+new"))
        let gutter = GitParser.gutterChanges(hunks)
        XCTAssertEqual(gutter, [
            GutterChange(kind: .added, lines: 3...4),
            GutterChange(kind: .modified, lines: 7...7),
            GutterChange(kind: .removed, lines: 11...11),
        ])
    }

    func testHunkHeaderEdgeCases() {
        XCTAssertNil(GitParser.parseHunkHeader("not a header"))
        XCTAssertEqual(GitParser.parseHunkHeader("@@ -1 +1 @@")?.1, 1)
        XCTAssertNil(GitParser.parseHunkHeader("@@ -x +y @@"))
    }
}

// MARK: - Real repositories

final class GitRepositoryTests: XCTestCase {
    private var dir: URL!
    private var runner: GitRunner!

    override func setUpWithError() throws {
        runner = try XCTUnwrap(GitRunner(), "git is required for these tests")
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("macdown-git-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        dir = base.resolvingSymlinksInPath()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func git(_ args: [String]) async throws {
        _ = try await runner.run(args, in: dir)
    }

    /// A repository with a user, one commit, and file "a.md".
    private func makeRepository(commit: Bool = true) async throws -> GitRepository {
        try await git(["init", "-q", "-b", "main"])
        try await git(["config", "user.email", "test@example.com"])
        try await git(["config", "user.name", "Test"])
        try await git(["config", "commit.gpgsign", "false"])
        if commit {
            try "line 1\nline 2\nline 3\n".write(to: dir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
            try await git(["add", "a.md"])
            try await git(["commit", "-q", "-m", "first"])
        }
        let opened = await GitRepository.open(containing: dir, runner: runner)
        return try XCTUnwrap(opened)
    }

    private func write(_ name: String, _ text: String) throws {
        try text.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func testOpenFindsRootFromSubdirectoryAndRejectsNonRepos() async throws {
        let repo = try await makeRepository()
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub/deep"), withIntermediateDirectories: true)
        let inner = await GitRepository.open(containing: dir.appendingPathComponent("sub/deep"), runner: runner)
        XCTAssertEqual(inner?.root.resolvingSymlinksInPath().path, repo.root.resolvingSymlinksInPath().path)

        let other = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: other) }
        // Only a failure if the temp directory itself is inside a repository, which it is not.
        let none = await GitRepository.open(containing: other, runner: runner)
        XCTAssertNil(none)
    }

    func testCleanStatusAndBranch() async throws {
        let repo = try await makeRepository()
        let status = try await repo.status()
        XCTAssertTrue(status.isClean)
        XCTAssertEqual(status.branch, "main")
        XCTAssertNotNil(status.commit)
    }

    func testStatusSeesModifiedUntrackedAndStagedFiles() async throws {
        let repo = try await makeRepository()
        try write("a.md", "changed\n")
        try write("new file.md", "x\n")
        try write("ünï.md", "x\n")
        try await repo.stage(["ünï.md"])
        let status = try await repo.status()
        let byPath = Dictionary(uniqueKeysWithValues: status.entries.map { ($0.path, $0) })
        XCTAssertEqual(byPath["a.md"]?.unstaged, .modified)
        XCTAssertTrue(byPath["new file.md"]?.isUntracked ?? false)
        XCTAssertEqual(byPath["ünï.md"]?.staged, .added)
    }

    func testStageUnstageAndCommit() async throws {
        let repo = try await makeRepository()
        try write("a.md", "changed\n")
        try await repo.stage(["a.md"])
        var status = try await repo.status()
        XCTAssertEqual(status.entries.first?.staged, .modified)

        try await repo.unstage(["a.md"])
        status = try await repo.status()
        XCTAssertNil(status.entries.first?.staged)
        XCTAssertEqual(status.entries.first?.unstaged, .modified)

        try await repo.stage([dir.appendingPathComponent("a.md").path])   // Absolute paths work.
        try await repo.commit(message: "Second\n\nWith a body and \"quotes\" and $(not run)")
        status = try await repo.status()
        XCTAssertTrue(status.isClean)
        let log = try await runner.run(["log", "-1", "--format=%B"], in: dir)
        XCTAssertTrue(log.text.contains("$(not run)"))
    }

    func testCommitNeedsAMessage() async throws {
        let repo = try await makeRepository()
        try write("a.md", "changed\n")
        try await repo.stage(["a.md"])
        do { try await repo.commit(message: "  \n"); XCTFail("Should throw") } catch {}
    }

    func testUnstageInRepositoryWithoutCommits() async throws {
        let repo = try await makeRepository(commit: false)
        try write("first.md", "x\n")
        try await repo.stage(["first.md"])
        var status = try await repo.status()
        XCTAssertEqual(status.entries.first?.staged, .added)
        try await repo.unstage(["first.md"])
        status = try await repo.status()
        XCTAssertTrue(status.entries.first?.isUntracked ?? false)
        let hasCommits = await repo.hasCommits()
        XCTAssertFalse(hasCommits)
    }

    func testAmend() async throws {
        let repo = try await makeRepository()
        try await repo.commit(message: "Amended message", amend: true)
        let log = try await runner.run(["log", "--format=%s"], in: dir)
        XCTAssertEqual(log.text.trimmingCharacters(in: .whitespacesAndNewlines), "Amended message")
    }

    func testGutterChangesForSavedFile() async throws {
        let repo = try await makeRepository()
        try write("a.md", "line 1\nCHANGED\nline 3\nnew line 4\n")
        let changes = try await repo.gutterChanges(for: "a.md")
        XCTAssertEqual(changes, [GutterChange(kind: .modified, lines: 2...2), GutterChange(kind: .added, lines: 4...4)])
    }

    func testGutterChangesForUnsavedText() async throws {
        let repo = try await makeRepository()
        let changes = try await repo.gutterChanges(for: "a.md", text: "line 1\nline 3\n")
        XCTAssertEqual(changes, [GutterChange(kind: .removed, lines: 1...1)])
        let same = try await repo.gutterChanges(for: "a.md", text: "line 1\nline 2\nline 3\n")
        XCTAssertEqual(same, [])
    }

    func testNewFilesAreAllAdded() async throws {
        let repo = try await makeRepository()
        try write("fresh.md", "a\nb\nc\n")
        let changes = try await repo.gutterChanges(for: "fresh.md")
        XCTAssertEqual(changes, [GutterChange(kind: .added, lines: 1...3)])
    }

    func testRevertHunk() async throws {
        let repo = try await makeRepository()
        try write("a.md", "line 1\nCHANGED\nline 3\nextra\n")
        let hunks = try await repo.hunks(for: "a.md")
        XCTAssertEqual(hunks.count, 2)
        try await repo.revert(hunks[0], in: "a.md")
        let text = try String(contentsOf: dir.appendingPathComponent("a.md"), encoding: .utf8)
        XCTAssertEqual(text, "line 1\nline 2\nline 3\nextra\n")
    }

    func testDiffText() async throws {
        let repo = try await makeRepository()
        try write("a.md", "line 1\nCHANGED\nline 3\n")
        let diff = try await repo.diff(for: "a.md")
        XCTAssertTrue(diff.contains("-line 2"))
        XCTAssertTrue(diff.contains("+CHANGED"))
        try await repo.stage(["a.md"])
        let staged = try await repo.diff(for: "a.md", staged: true)
        XCTAssertTrue(staged.contains("+CHANGED"))
    }

    func testDiscardChanges() async throws {
        let repo = try await makeRepository()
        try write("a.md", "oops\n")
        try await repo.discardChanges(["a.md"])
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("a.md"), encoding: .utf8), "line 1\nline 2\nline 3\n")
    }

    func testBranches() async throws {
        let repo = try await makeRepository()
        try await repo.createBranch(named: "feature/x")
        var branches = try await repo.branches()
        XCTAssertEqual(branches.map(\.name).sorted(), ["feature/x", "main"])
        XCTAssertEqual(branches.first { $0.isCurrent }?.name, "feature/x")
        try await repo.switchBranch(to: "main")
        branches = try await repo.branches()
        XCTAssertEqual(branches.first { $0.isCurrent }?.name, "main")
        let status = try await repo.status()
        XCTAssertEqual(status.branch, "main")
    }

    func testInvalidBranchNamesAreRejected() async throws {
        let repo = try await makeRepository()
        for name in ["--force", "-x", "has space", "a..b", "", "bad~name", "end."] {
            do { try await repo.createBranch(named: name); XCTFail("Accepted \(name)") }
            catch let error as GitError { XCTAssertEqual(error, .invalidName(name)) }
        }
    }

    func testPathOutsideRepositoryIsRejected() async throws {
        let repo = try await makeRepository()
        XCTAssertThrowsError(try repo.relativePath("/etc/hosts"))
        XCTAssertEqual(try repo.relativePath("docs/a.md"), "docs/a.md")
    }

    func testFailingCommandReportsGitsMessage() async throws {
        let repo = try await makeRepository()
        do { try await repo.switchBranch(to: "does-not-exist"); XCTFail("Should throw") }
        catch let error as GitError {
            if case let .failed(_, _, message) = error { XCTAssertFalse(message.isEmpty) } else { XCTFail("\(error)") }
        }
    }

    func testCommandTimeout() async throws {
        let slow = GitRunner(executable: runner.executable, timeout: 0.2)
        // `git hash-object --stdin` waits for input that never ends: stdin is /dev/null, so
        // use a command that sleeps instead: an alias running `sleep`.
        do {
            _ = try await slow.run(["-c", "alias.nap=!sleep 5", "nap"], in: dir)
            XCTFail("Should time out")
        } catch let error as GitError {
            XCTAssertEqual(error, .timedOut(command: "-c"))
        }
    }

    func testStatusOfLargeRepositoryIsFast() async throws {
        let repo = try await makeRepository()
        for i in 0..<1500 { try write("file\(i).md", "x\n") }
        try await git(["add", "-A"])
        try await git(["commit", "-q", "-m", "many"])
        for i in stride(from: 0, to: 1500, by: 10) { try write("file\(i).md", "changed\n") }
        let start = Date()
        let status = try await repo.status()
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        XCTAssertEqual(status.entries.count, 150)
    }

    func testConcurrentCommands() async throws {
        let repo = try await makeRepository()
        try write("a.md", "changed\n")
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<20 { group.addTask { (try? await repo.status().entries.count) ?? -1 } }
            for await count in group { XCTAssertEqual(count, 1) }
        }
    }
}
