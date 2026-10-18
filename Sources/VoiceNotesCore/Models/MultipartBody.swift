import Foundation

public struct MultipartBody: Sendable {
    public let boundary: String
    private var data = Data()

    public init(boundary: String = "VoiceNotes-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    public var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    public mutating func addField(name: String, value: String) {
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"\(name)\"")
        appendLine("")
        appendLine(value)
    }

    public mutating func addFile(name: String, filename: String, mimeType: String, contents: Data) {
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"")
        appendLine("Content-Type: \(mimeType)")
        appendLine("")
        data.append(contents)
        appendLine("")
    }

    public func finalized() -> Data {
        var result = data
        result.append(Data("--\(boundary)--\r\n".utf8))
        return result
    }

    private mutating func appendLine(_ line: String) {
        data.append(Data("\(line)\r\n".utf8))
    }
}
