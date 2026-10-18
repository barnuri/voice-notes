import Foundation
import Testing
@testable import VoiceNotesCore

struct MultipartBodyTests {
    @Test func encodesFieldsThenFileWithClosingBoundary() {
        var body = MultipartBody(boundary: "B")
        body.addField(name: "model", value: "whisper/x")
        body.addFile(name: "file", filename: "a.m4a", mimeType: "audio/mp4", contents: Data("AUDIO".utf8))
        let expected = "--B\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\nwhisper/x\r\n"
            + "--B\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.m4a\"\r\n"
            + "Content-Type: audio/mp4\r\n\r\nAUDIO\r\n--B--\r\n"
        #expect(String(decoding: body.finalized(), as: UTF8.self) == expected)
        #expect(body.contentType == "multipart/form-data; boundary=B")
    }
}
