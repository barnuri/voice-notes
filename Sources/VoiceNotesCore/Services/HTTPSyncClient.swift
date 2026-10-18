import Foundation

public struct HTTPSyncClient: Syncing {
    private static let requestTimeout: TimeInterval = 30
    private static let unauthorizedStatus = 401
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func sync(_ records: [Note], endpoint: SyncEndpoint) async throws -> [Note] {
        let request = try makeRequest(records: records, endpoint: endpoint)
        let payload = try await send(request, endpoint: endpoint, decoding: SyncPayload.self)
        return payload.notes
    }

    public func fetchConfig(endpoint: SyncEndpoint) async throws -> ServerConfig {
        try await send(makeConfigRequest(endpoint: endpoint), endpoint: endpoint, decoding: ServerConfig.self)
    }

    public func selectModel(_ id: String, endpoint: SyncEndpoint) async throws -> String {
        let request = try makeSelectModelRequest(id, endpoint: endpoint)
        return try await send(request, endpoint: endpoint, decoding: ModelSelection.self).model
    }

    func makeRequest(records: [Note], endpoint: SyncEndpoint) throws -> URLRequest {
        var request = makeEndpointRequest(url: endpoint.url, method: "POST", endpoint: endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try ISO8601DateCoding.makeEncoder().encode(SyncPayload(notes: records))
        return request
    }

    func makeConfigRequest(endpoint: SyncEndpoint) -> URLRequest {
        makeEndpointRequest(url: endpoint.configURL, method: "GET", endpoint: endpoint)
    }

    func makeSelectModelRequest(_ id: String, endpoint: SyncEndpoint) throws -> URLRequest {
        var request = makeEndpointRequest(url: endpoint.settingsURL, method: "PUT", endpoint: endpoint)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ModelSelection(model: id))
        return request
    }

    private func makeEndpointRequest(url: URL, method: String, endpoint: SyncEndpoint) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.httpMethod = method
        if !endpoint.token.isEmpty {
            request.setValue("Bearer \(endpoint.token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send<Response: Decodable>(
        _ request: URLRequest,
        endpoint: SyncEndpoint,
        decoding type: Response.Type
    ) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SyncError.unreachable(host: endpoint.url.host() ?? endpoint.url.absoluteString)
        }
        guard let http = response as? HTTPURLResponse else { throw SyncError.unreadableResponse }
        guard http.statusCode != Self.unauthorizedStatus else { throw SyncError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.server(status: http.statusCode, message: WhisperTranscriptionClient.errorMessage(from: data))
        }
        guard let decoded = try? ISO8601DateCoding.makeDecoder().decode(type, from: data) else {
            throw SyncError.unreadableResponse
        }
        return decoded
    }
}
