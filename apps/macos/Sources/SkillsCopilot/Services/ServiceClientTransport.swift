import Foundation

struct ServiceRequest<Params: Encodable>: Encodable {
    let id: String
    let method: String
    let params: Params
}

struct ServiceEnvelope<ResultPayload: Decodable>: Decodable {
    let id: String?
    let ok: Bool
    let result: ResultPayload?
    let error: ServiceErrorPayload?
}

extension ServiceClient {
    func call<ResultPayload: Decodable, Params: Encodable>(
        method: String,
        params: Params,
        timeoutMS: Int? = nil
    ) async throws -> ResultPayload {
        let request = ServiceRequest(
            id: UUID().uuidString,
            method: method,
            params: params
        )
        let input = try JSONEncoder().encode(request)
        let output = try await runService(input: input, timeoutMS: timeoutMS)
        let envelope: ServiceEnvelope<ResultPayload>
        do {
            envelope = try JSONDecoder().decode(ServiceEnvelope<ResultPayload>.self, from: output)
        } catch {
            let rawOutput = String(data: output, encoding: .utf8) ?? "<binary>"
            throw ClientError.invalidOutput("decode failed: \(error). output: \(rawOutput)")
        }
        if envelope.ok, let result = envelope.result {
            return result
        }
        if let error = envelope.error {
            throw ClientError.service(error)
        }
        throw ClientError.invalidOutput(String(data: output, encoding: .utf8) ?? "<binary>")
    }

    private func runService(input: Data, timeoutMS: Int?) async throws -> Data {
        let timeoutNanoseconds = timeoutMS.map { UInt64(max($0, 50)) * 1_000_000 }
        return try await processRunner.run(
            executableURL: resolveServiceURL(),
            input: input,
            timeoutNanoseconds: timeoutNanoseconds
        )
    }

    private func resolveServiceURL() throws -> URL {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["SKILLS_COPILOT_SERVICE_PATH"],
           !override.isEmpty {
            let overrideURL = URL(fileURLWithPath: override)
            if FileManager.default.isExecutableFile(atPath: overrideURL.path) {
                return overrideURL
            }
        }
        #endif
        if let url = Bundle.main.url(forResource: "skills-copilot-service", withExtension: nil) {
            return url
        }
        throw ClientError.missingBinary
    }
}
