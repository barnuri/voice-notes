import Foundation

public struct WhisperTranscriptionClient: Transcribing {
    private static let requestTimeout: TimeInterval = 120
    private static let modelField = "model"
    private static let formatField = "response_format"
    private static let jsonFormat = "json"
    private static let languageField = "language"
    private static let promptField = "prompt"
    private static let fileField = "file"
    private static let audioMimeType = "audio/mp4"
    private static let errorPreviewBytes = 300
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func transcribe(fileURL: URL, endpoint: TranscriptionEndpoint) async throws -> String {
        let request = try makeRequest(fileURL: fileURL, endpoint: endpoint)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranscriptionError.unreachable(host: endpoint.url.host() ?? endpoint.url.absoluteString)
        }
        guard let http = response as? HTTPURLResponse else { throw TranscriptionError.unreadableResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw TranscriptionError.server(status: http.statusCode, message: Self.errorMessage(from: data))
        }
        guard let text = Self.decodeText(from: data) else { throw TranscriptionError.unreadableResponse }
        return text
    }

    func makeRequest(fileURL: URL, endpoint: TranscriptionEndpoint) throws -> URLRequest {
        var body = MultipartBody()
        body.addField(name: Self.modelField, value: endpoint.model)
        body.addField(name: Self.formatField, value: Self.jsonFormat)
        body.addField(name: Self.languageField, value: endpoint.language.languageCode)
        if let prompt = endpoint.language.prompt {
            body.addField(name: Self.promptField, value: prompt)
        }
        body.addFile(
            name: Self.fileField,
            filename: fileURL.lastPathComponent,
            mimeType: Self.audioMimeType,
            contents: try Data(contentsOf: fileURL)
        )
        var request = URLRequest(url: endpoint.url, timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        if !endpoint.apiKey.isEmpty {
            request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body.finalized()
        return request
    }

    static func decodeText(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = object["text"] as? String else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func errorMessage(from data: Data) -> String {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let nested = object?["error"] as? [String: Any], let message = nested["message"] as? String {
            return message
        }
        if let message = object?["error"] as? String {
            return message
        }
        return String(decoding: data.prefix(errorPreviewBytes), as: UTF8.self)
    }
}
