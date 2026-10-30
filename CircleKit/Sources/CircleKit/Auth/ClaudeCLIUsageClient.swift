import Foundation

/// Gets subscription usage by running `claude -p /usage`, the same report
/// Claude Code shows for `/usage`.
///
/// Circle never touches Claude Code's credentials: the CLI reads its own
/// keychain entry and refreshes its own token, so there's no keychain prompt
/// for Circle and no token in this process. The command is answered locally
/// plus one usage lookup — it doesn't call the model or spend any quota.
///
/// One process-wide instance (`shared`) caches the last result so that the
/// per-display providers and repeated overlay shows don't each spawn the CLI
/// (a run takes a couple of seconds of CPU).
public final class ClaudeCLIUsageClient {
    public enum ClientError: Error, Equatable {
        /// No `claude` executable in any of the usual install locations.
        case notInstalled
        /// The CLI ran but printed no usage lines — not signed in, or signed
        /// in with an API key rather than a Claude subscription.
        case notSignedIn
        case timedOut
        case launchFailed(String)
    }

    public static let shared = ClaudeCLIUsageClient()

    /// Successful readings are reused for this long. A bit under the
    /// provider's 5-minute poll so each poll gets a fresh reading.
    static let successMaxAge: TimeInterval = 4 * 60
    /// Failures are remembered briefly so several displays polling at once
    /// share one attempt instead of each re-running the CLI.
    static let failureMaxAge: TimeInterval = 60
    static let timeout: TimeInterval = 30

    private let clock: () -> Date
    private let locate: () -> URL?
    private let run: (URL, [String]) async throws -> String
    private let fallback: () -> AnthropicUsage?

    private let lock = NSLock()
    private var cached: (at: Date, result: Result<AnthropicUsage, ClientError>)?
    private var inFlight: Task<Result<AnthropicUsage, ClientError>, Never>?

    init(
        clock: @escaping () -> Date = { Date() },
        locate: @escaping () -> URL? = { ClaudeCLIUsageClient.locateCLI() },
        run: @escaping (URL, [String]) async throws -> String = { try await ClaudeCLIUsageClient.runProcess($0, $1) },
        fallback: @escaping () -> AnthropicUsage? = { StatusLineUsageSnapshot.read() }
    ) {
        self.clock = clock
        self.locate = locate
        self.run = run
        self.fallback = fallback
    }

    /// Returns the cached reading when it's recent enough, otherwise runs the
    /// CLI (joining a run that's already under way). `force` skips the cache,
    /// for an explicit "Check Connection" from Settings.
    public func fetchUsage(force: Bool = false) async throws -> AnthropicUsage {
        switch cachedOrInFlight(force: force) {
        case .cached(let result):
            return try result.get()
        case .wait(let task):
            let result = await task.value
            finish(task, with: result)
            return try result.get()
        }
    }

    private enum Lookup {
        case cached(Result<AnthropicUsage, ClientError>)
        case wait(Task<Result<AnthropicUsage, ClientError>, Never>)
    }

    private func cachedOrInFlight(force: Bool) -> Lookup {
        lock.lock()
        defer { lock.unlock() }
        if !force, let cached, clock().timeIntervalSince(cached.at) < maxAge(of: cached.result) {
            return .cached(cached.result)
        }
        if let inFlight { return .wait(inFlight) }
        let task = Task { await self.load() }
        inFlight = task
        return .wait(task)
    }

    private func finish(_ task: Task<Result<AnthropicUsage, ClientError>, Never>, with result: Result<AnthropicUsage, ClientError>) {
        lock.lock()
        defer { lock.unlock() }
        guard inFlight == task else { return }
        inFlight = nil
        cached = (clock(), result)
    }

    private func maxAge(of result: Result<AnthropicUsage, ClientError>) -> TimeInterval {
        if case .success = result { return Self.successMaxAge }
        return Self.failureMaxAge
    }

    private func load() async -> Result<AnthropicUsage, ClientError> {
        let result = await loadFromCLI()
        if case .failure = result, let snapshot = fallback() {
            return .success(snapshot)
        }
        return result
    }

    private func loadFromCLI() async -> Result<AnthropicUsage, ClientError> {
        guard let executable = locate() else { return .failure(.notInstalled) }
        let output: String
        do {
            output = try await run(executable, Self.arguments)
        } catch let error as ClientError {
            return .failure(error)
        } catch {
            return .failure(.launchFailed(error.localizedDescription))
        }
        guard let usage = ClaudeCLIUsageParser.parse(output, now: clock()) else {
            return .failure(.notSignedIn)
        }
        return .success(usage)
    }

    /// `--no-session-persistence` keeps each run from leaving a transcript
    /// behind; `--strict-mcp-config` and `--setting-sources project` (run from
    /// an empty directory) skip the user's MCP servers, hooks and plugins,
    /// which `/usage` doesn't need and which would only slow it down.
    static let arguments = [
        "-p", "/usage",
        "--no-session-persistence",
        "--strict-mcp-config",
        "--setting-sources", "project",
    ]

    // MARK: - Finding and running the CLI

    /// Apps launched from Finder don't inherit the shell's PATH, so look in
    /// the places Claude Code's installers put it.
    public static func locateCLI(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environmentPath: String? = ProcessInfo.processInfo.environment["PATH"],
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> URL? {
        var candidates = [
            home.appendingPathComponent(".local/bin/claude").path,       // native installer
            home.appendingPathComponent(".claude/local/claude").path,    // older local install
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            home.appendingPathComponent(".npm-global/bin/claude").path,
        ]
        candidates += (environmentPath ?? "").split(separator: ":").map { "\($0)/claude" }
        return candidates.first(where: isExecutable).map { URL(fileURLWithPath: $0) }
    }

    /// Runs the CLI from an empty working directory and returns its stdout.
    static func runProcess(_ executable: URL, _ arguments: [String]) async throws -> String {
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("circle-claude-usage", isDirectory: true)
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = workDir
        var environment = ProcessInfo.processInfo.environment
        // npm installs are a `#!/usr/bin/env node` script, so node has to be
        // findable next to wherever it was installed.
        let extraPath = [executable.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin"]
        environment["PATH"] = (extraPath + [environment["PATH"] ?? "/usr/bin:/bin"]).joined(separator: ":")
        process.environment = environment
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: ClientError.launchFailed(error.localizedDescription))
                    return
                }
                let timedOut = TimeoutFlag()
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning {
                        timedOut.set()
                        process.terminate()
                    }
                }
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if timedOut.isSet {
                    continuation.resume(throwing: ClientError.timedOut)
                } else {
                    continuation.resume(returning: String(decoding: data, as: UTF8.self))
                }
            }
        }
    }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
