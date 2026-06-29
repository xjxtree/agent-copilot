import Darwin
import Foundation

protocol ServiceProcessRunning {
    func run(executableURL: URL, input: Data, timeoutNanoseconds: UInt64?) async throws -> Data
}

final class StdioServiceProcessRunner: ServiceProcessRunning {
    private let timeoutNanoseconds: UInt64
    private let environmentOverrides: [String: String]

    init(
        timeoutNanoseconds: UInt64 = StdioServiceProcessRunner.configuredTimeoutNanoseconds(),
        environmentOverrides: [String: String] = [:]
    ) {
        self.timeoutNanoseconds = timeoutNanoseconds
        self.environmentOverrides = environmentOverrides
    }

    func run(executableURL: URL, input: Data, timeoutNanoseconds overrideTimeoutNanoseconds: UInt64? = nil) async throws -> Data {
        let invocation = StdioServiceProcessInvocation(
            executableURL: executableURL,
            input: input,
            environmentOverrides: environmentOverrides
        )
        let coordinator = StdioServiceProcessRunCoordinator(invocation: invocation)
        let effectiveTimeoutNanoseconds = overrideTimeoutNanoseconds ?? timeoutNanoseconds

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                coordinator.start(
                    timeoutNanoseconds: effectiveTimeoutNanoseconds,
                    continuation: continuation
                )
            }
        } onCancel: {
            coordinator.cancel()
        }
    }

    private static func configuredTimeoutNanoseconds() -> UInt64 {
        let defaultTimeoutMs: UInt64 = 30_000
        let raw = ProcessInfo.processInfo.environment["SKILLS_COPILOT_SERVICE_TIMEOUT_MS"]
        let parsedTimeoutMs = raw.flatMap(UInt64.init)
        let timeoutMs = parsedTimeoutMs.map { max($0, 50) } ?? defaultTimeoutMs
        return timeoutMs * 1_000_000
    }
}

private final class StdioServiceProcessRunCoordinator {
    private let invocation: StdioServiceProcessInvocation
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var completed = false

    init(invocation: StdioServiceProcessInvocation) {
        self.invocation = invocation
    }

    func start(
        timeoutNanoseconds: UInt64,
        continuation: CheckedContinuation<Data, Error>
    ) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()

        operationTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let data = try self.invocation.run()
                self.finish(.success(data))
            } catch {
                self.finish(.failure(error))
            }
        }

        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
            } catch {
                return
            }
            guard let self else { return }
            self.invocation.cancel()
            self.operationTask?.cancel()
            self.finish(.failure(ServiceClient.ClientError.processTimedOut))
        }
    }

    func cancel() {
        invocation.cancel()
        operationTask?.cancel()
        finish(.failure(CancellationError()))
    }

    private func finish(_ result: Result<Data, Error>) {
        let continuation: CheckedContinuation<Data, Error>?
        let timeoutTask: Task<Void, Never>?
        lock.lock()
        if completed {
            continuation = nil
            timeoutTask = nil
        } else {
            completed = true
            continuation = self.continuation
            self.continuation = nil
            timeoutTask = self.timeoutTask
            self.timeoutTask = nil
        }
        lock.unlock()

        timeoutTask?.cancel()
        switch result {
        case .success(let data):
            continuation?.resume(returning: data)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}

private final class StdioServiceProcessInvocation {
    private let executableURL: URL
    private let input: Data
    private let environmentOverrides: [String: String]
    private let lock = NSLock()

    private var process: Process?
    private var stdinWriter: FileHandle?
    private var stdoutReader: FileHandle?
    private var stderrReader: FileHandle?
    private var cancelled = false
    private var terminationRequested = false
    private var cleanedUp = false

    init(executableURL: URL, input: Data, environmentOverrides: [String: String]) {
        self.executableURL = executableURL
        self.input = input
        self.environmentOverrides = environmentOverrides
    }

    func run() throws -> Data {
        try Task.checkCancellation()

        let process = Process()
        process.executableURL = executableURL
        if !environmentOverrides.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            environmentOverrides.forEach { key, value in
                environment[key] = value
            }
            process.environment = environment
        }

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        register(
            process: process,
            stdinWriter: stdin.fileHandleForWriting,
            stdoutReader: stdout.fileHandleForReading,
            stderrReader: stderr.fileHandleForReading
        )

        do {
            try process.run()
            try Task.checkCancellation()
            try stdin.fileHandleForWriting.write(contentsOf: input)
            try stdin.fileHandleForWriting.close()
            clearStdinWriter(stdin.fileHandleForWriting)

            let output = stdout.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
            waitUntilExit(process)

            try Task.checkCancellation()
            guard !isCancelled else {
                throw CancellationError()
            }

            cleanup(closePipes: true)

            if process.terminationStatus != 0 {
                let message = String(data: errorOutput, encoding: .utf8) ?? ""
                throw ServiceClient.ClientError.processFailed(process.terminationStatus, message)
            }
            return output
        } catch is CancellationError {
            cancel()
            cleanup(closePipes: true)
            throw CancellationError()
        } catch {
            if Task.isCancelled || isCancelled {
                cancel()
                cleanup(closePipes: true)
                throw CancellationError()
            }
            cleanup(closePipes: true)
            throw error
        }
    }

    func cancel() {
        let snapshot = markCancelled()
        try? snapshot.stdinWriter?.close()
        if snapshot.shouldTerminate, let process = snapshot.process, process.isRunning {
            process.terminate()
            forceTerminate(process, after: .milliseconds(250))
        }
    }

    private func waitUntilExit(_ process: Process) {
        while process.isRunning {
            if Task.isCancelled || isCancelled {
                cancel()
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        process.waitUntilExit()
    }

    private func register(
        process: Process,
        stdinWriter: FileHandle,
        stdoutReader: FileHandle,
        stderrReader: FileHandle
    ) {
        lock.lock()
        self.process = process
        self.stdinWriter = stdinWriter
        self.stdoutReader = stdoutReader
        self.stderrReader = stderrReader
        let shouldCancel = cancelled
        lock.unlock()

        if shouldCancel {
            cancel()
        }
    }

    private func clearStdinWriter(_ handle: FileHandle) {
        lock.lock()
        if stdinWriter === handle {
            stdinWriter = nil
        }
        lock.unlock()
    }

    private var isCancelled: Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value
    }

    private func markCancelled() -> ProcessSnapshot {
        lock.lock()
        cancelled = true
        let shouldTerminate = process?.isRunning == true && !terminationRequested
        if shouldTerminate {
            terminationRequested = true
        }
        let stdinWriter = stdinWriter
        self.stdinWriter = nil
        let snapshot = ProcessSnapshot(
            process: process,
            stdinWriter: stdinWriter,
            stdoutReader: stdoutReader,
            stderrReader: stderrReader,
            shouldTerminate: shouldTerminate
        )
        lock.unlock()
        return snapshot
    }

    private func cleanup(closePipes: Bool) {
        let snapshot: ProcessSnapshot?
        lock.lock()
        if cleanedUp {
            snapshot = nil
        } else {
            cleanedUp = true
            snapshot = ProcessSnapshot(
                process: process,
                stdinWriter: stdinWriter,
                stdoutReader: stdoutReader,
                stderrReader: stderrReader,
                shouldTerminate: false
            )
            process = nil
            stdinWriter = nil
            stdoutReader = nil
            stderrReader = nil
        }
        lock.unlock()

        guard closePipes, let snapshot else { return }
        try? snapshot.stdinWriter?.close()
    }

    private func forceTerminate(_ process: Process, after delay: DispatchTimeInterval) {
        let pid = process.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
            if process.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }

    private struct ProcessSnapshot {
        let process: Process?
        let stdinWriter: FileHandle?
        let stdoutReader: FileHandle?
        let stderrReader: FileHandle?
        let shouldTerminate: Bool
    }
}
