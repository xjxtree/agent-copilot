import Darwin
import Foundation
@testable import SkillsCopilot

struct ServiceClientProcessTests {
    func run() async throws {
        try await cancelledCallTerminatesSidecarProcess()
        try await cancelledCallForceKillsTermIgnoringSidecarProcess()
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
