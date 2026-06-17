import Foundation

extension ServiceClient {
    func previewMcpServers(
        authorizedConfigPaths: [String],
        limit: Int = 20
    ) async throws -> McpServerPreviewResult {
        let params = McpServerPreviewParams(
            authorizedConfigPaths: authorizedConfigPaths,
            limit: limit
        )
        do {
            return try await call(method: "evidence.previewMcpServers", params: params)
        } catch ClientError.service(let error) where error.code == "unknown_method" {
            return .unavailable()
        }
    }
}
