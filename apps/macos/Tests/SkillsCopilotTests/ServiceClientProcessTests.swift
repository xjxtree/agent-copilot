import Darwin
import Foundation
@testable import SkillsCopilot

struct ServiceClientProcessTests {
    func run() async throws {
        try await cancelledCallTerminatesSidecarProcess()
        try await cancelledCallForceKillsTermIgnoringSidecarProcess()
        try await hangingCallTimesOutAndTerminatesSidecarProcess()
        try await malformedOutputMapsToInvalidOutput()
        try await emptyOutputMapsToInvalidOutput()
        try await truncatedOutputMapsToInvalidOutput()
        try await stderrOnlyFailureMapsToProcessFailed()
    }

    private func cancelledCallTerminatesSidecarProcess() async throws {
        let fake = try CancellableServiceScript()
        defer { fake.cleanup() }
        fake.activate()

        let call = Task {
            try await ServiceClient().status()
        }

        let pid = try await fake.waitForPID()
        call.cancel()

        do {
            _ = try await call.value
            throw NativeModelTestFailure(description: "Cancelled service call should not return a status result.")
        } catch is CancellationError {
            // Expected: the process runner maps caller cancellation to Swift cancellation.
        }

        try await waitUntil("Cancelled sidecar process should be reaped.") {
            !processExists(pid)
        }
        try expectContains(fake.calls(), "\"method\":\"service.status\"", "Cancellation test should launch the expected service method.")
    }

    private func cancelledCallForceKillsTermIgnoringSidecarProcess() async throws {
        let fake = try CancellableServiceScript(ignoresTermination: true)
        defer { fake.cleanup() }
        fake.activate()

        let call = Task {
            try await ServiceClient().status()
        }

        let pid = try await fake.waitForPID()
        call.cancel()

        do {
            _ = try await call.value
            throw NativeModelTestFailure(description: "Cancelled stubborn service call should not return a status result.")
        } catch is CancellationError {
            // Expected: the process runner escalates from terminate() to SIGKILL after the cleanup timeout.
        }

        try await waitUntil("TERM-ignoring sidecar should be force-killed after the cleanup timeout.", timeout: 4) {
            !processExists(pid)
        }
        try expectContains(fake.calls(), "\"method\":\"service.status\"", "Force-kill test should launch the expected service method.")
    }

    private func hangingCallTimesOutAndTerminatesSidecarProcess() async throws {
        let fake = try CancellableServiceScript()
        defer { fake.cleanup() }
        fake.activate()

        let call = Task {
            try await ServiceClient(
                processRunner: StdioServiceProcessRunner(timeoutNanoseconds: 1_000_000_000)
            ).status()
        }

        let pid = try await fake.waitForPID()
        do {
            _ = try await call.value
            throw NativeModelTestFailure(description: "Hanging service call should time out.")
        } catch ServiceClient.ClientError.processTimedOut {
            // Expected: the runner maps a sidecar that never closes stdout to a bounded timeout.
        }

        try await waitUntil("Timed-out sidecar process should be reaped.", timeout: 4) {
            !processExists(pid)
        }
        try expectContains(fake.calls(), "\"method\":\"service.status\"", "Timeout test should launch the expected service method.")
    }

    private func malformedOutputMapsToInvalidOutput() async throws {
        let fake = try StaticServiceScript(mode: "malformed")
        defer { fake.cleanup() }
        fake.activate()

        do {
            _ = try await ServiceClient().status()
            throw NativeModelTestFailure(description: "Malformed service output should fail.")
        } catch ServiceClient.ClientError.invalidOutput(let output) {
            try expectContains(output, "decode failed", "Malformed output should include decode context.")
            try expectContains(output, "not-json", "Malformed output should include a raw output snippet.")
        }
    }

    private func emptyOutputMapsToInvalidOutput() async throws {
        let fake = try StaticServiceScript(mode: "empty")
        defer { fake.cleanup() }
        fake.activate()

        do {
            _ = try await ServiceClient().status()
            throw NativeModelTestFailure(description: "Empty service output should fail.")
        } catch ServiceClient.ClientError.invalidOutput(let output) {
            try expectContains(output, "decode failed", "Empty output should include decode context.")
        }
    }

    private func truncatedOutputMapsToInvalidOutput() async throws {
        let fake = try StaticServiceScript(mode: "truncated")
        defer { fake.cleanup() }
        fake.activate()

        do {
            _ = try await ServiceClient().status()
            throw NativeModelTestFailure(description: "Truncated service output should fail.")
        } catch ServiceClient.ClientError.invalidOutput(let output) {
            try expectContains(output, "decode failed", "Truncated output should include decode context.")
            try expectContains(output, "\"result\":", "Truncated output should include a raw output snippet.")
        }
    }


    private func stderrOnlyFailureMapsToProcessFailed() async throws {
        let fake = try StaticServiceScript(mode: "failure")
        defer { fake.cleanup() }
        fake.activate()

        do {
            _ = try await ServiceClient().status()
            throw NativeModelTestFailure(description: "Nonzero service exit should fail.")
        } catch ServiceClient.ClientError.processFailed(let status, let stderr) {
            try expectEqual(status, 7, "Process failure should preserve exit status.")
            try expectContains(stderr, "sidecar failed", "Process failure should preserve stderr.")
        }
    }

    private func waitUntil(_ label: String, timeout: TimeInterval = 2, predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() {
            if Date() > deadline {
                throw NativeModelTestFailure(description: label)
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func processExists(_ pid: pid_t) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }
}

private final class StaticServiceScript {
    private let directory: URL
    private let executableURL: URL
    private let mode: String

    init(mode: String) throws {
        self.mode = mode
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("skills-copilot-static-service-\(UUID().uuidString)", isDirectory: true)
        executableURL = directory.appendingPathComponent("fake-static-service.sh")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try script.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: executableURL.path
        )
    }

    func activate() {
        setenv("SKILLS_COPILOT_SERVICE_PATH", executableURL.path, 1)
        setenv("SKILLS_COPILOT_STATIC_SERVICE_MODE", mode, 1)
    }

    func cleanup() {
        unsetenv("SKILLS_COPILOT_SERVICE_PATH")
        unsetenv("SKILLS_COPILOT_STATIC_SERVICE_MODE")
        try? FileManager.default.removeItem(at: directory)
    }

    private var script: String {
        """
        #!/bin/sh
        cat >/dev/null
        case "${SKILLS_COPILOT_STATIC_SERVICE_MODE:-malformed}" in
          malformed)
            printf 'not-json'
            exit 0
            ;;
          empty)
            exit 0
            ;;
          failure)
            printf 'sidecar failed' >&2
            exit 7
            ;;
          truncated)
            printf '{"id":"test","ok":true,"result":'
            exit 0
            ;;
          *)
            printf 'not-json'
            exit 0
            ;;
        esac
        """
    }
}

private final class CancellableServiceScript {
    private let directory: URL
    private let executableURL: URL
    private let callsURL: URL
    private let pidURL: URL
    private let ignoresTermination: Bool

    init(ignoresTermination: Bool = false) throws {
        self.ignoresTermination = ignoresTermination
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("skills-copilot-cancellable-service-\(UUID().uuidString)", isDirectory: true)
        executableURL = directory.appendingPathComponent("fake-cancellable-service.sh")
        callsURL = directory.appendingPathComponent("calls.log")
        pidURL = directory.appendingPathComponent("pid")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: callsURL.path, contents: nil)
        try script.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: executableURL.path
        )
    }

    func activate() {
        setenv("SKILLS_COPILOT_SERVICE_PATH", executableURL.path, 1)
        setenv("SKILLS_COPILOT_CANCELLABLE_SERVICE_CALLS", callsURL.path, 1)
        setenv("SKILLS_COPILOT_CANCELLABLE_SERVICE_PID", pidURL.path, 1)
        setenv("SKILLS_COPILOT_CANCELLABLE_SERVICE_IGNORE_TERM", ignoresTermination ? "1" : "0", 1)
    }

    func cleanup() {
        if let pid = try? currentPID(), kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }
        unsetenv("SKILLS_COPILOT_SERVICE_PATH")
        unsetenv("SKILLS_COPILOT_CANCELLABLE_SERVICE_CALLS")
        unsetenv("SKILLS_COPILOT_CANCELLABLE_SERVICE_PID")
        unsetenv("SKILLS_COPILOT_CANCELLABLE_SERVICE_IGNORE_TERM")
        try? FileManager.default.removeItem(at: directory)
    }

    func calls() -> String {
        (try? String(contentsOf: callsURL, encoding: .utf8)) ?? ""
    }

    func waitForPID(timeout: TimeInterval = 2) async throws -> pid_t {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if let pid = try? currentPID() {
                return pid
            }
            if Date() > deadline {
                throw NativeModelTestFailure(description: "Fake sidecar should publish its PID before cancellation.")
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func currentPID() throws -> pid_t {
        let raw = try String(contentsOf: pidURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int32(raw) else {
            throw NativeModelTestFailure(description: "Fake sidecar PID should be numeric.")
        }
        return pid_t(value)
    }

    private var script: String {
        """
        #!/bin/sh
        input=$(cat)
        printf '%s\\n' "$input" >> "$SKILLS_COPILOT_CANCELLABLE_SERVICE_CALLS"
        printf '%s\\n' "$$" > "$SKILLS_COPILOT_CANCELLABLE_SERVICE_PID"
        if [ "${SKILLS_COPILOT_CANCELLABLE_SERVICE_IGNORE_TERM:-0}" = "1" ]; then
          trap '' TERM
          while :; do
            :
          done
        fi
        while :; do
          sleep 1
        done
        """
    }
}
