import Darwin
import Foundation

protocol ServiceProcessRunning {
    func run(executableURL: URL, input: Data) async throws -> Data
}

final class StdioServiceProcessRunner: ServiceProcessRunning {
    func run(executableURL: URL, input: Data) async throws -> Data {
        let invocation = StdioServiceProcessInvocation(executableURL: executableURL, input: input)
        let task = Task.detached(priority: .userInitiated) {
            try invocation.run()
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
            invocation.cancel()
        }
    }
}

private final class StdioServiceProcessInvocation {
    private let executableURL: URL
    private let input: Data
    private let lock = NSLock()

    private var process: Process?
    private var stdinWriter: FileHandle?
    private var stdoutReader: FileHandle?
    private var stderrReader: FileHandle?
    private var cancelled = false
    private var terminationRequested = false
    private var cleanedUp = false

    init(executableURL: URL, input: Data) {
        self.executableURL = executableURL
        self.input = input
    }

    func run() throws -> Data {
        try Task.checkCancellation()

        let process = Process()
        process.executableURL = executableURL

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
            stdin.fileHandleForWriting.write(input)
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
        try? snapshot.stdoutReader?.close()
        try? snapshot.stderrReader?.close()
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
