import Foundation
import Testing
@testable import VoiceNotesCore

struct ServerConfigTests {
    @Test func decodesConfigAndIgnoresExtraKeys() throws {
        let json = """
        {"model":"ivrit/ivrit-large-v3-turbo","models":[
          {"id":"ivrit/ivrit-large-v3-turbo","title":"ivrit.ai Hebrew","description":"Hebrew tuned"},
          {"id":"whisper/whisper-large-v3-turbo","title":"Whisper large-v3-turbo","description":"Multilingual"}
        ],"publicUrl":"https://notes.example","version":"1.2.3"}
        """
        let config = try JSONDecoder().decode(ServerConfig.self, from: Data(json.utf8))

        #expect(config.model == "ivrit/ivrit-large-v3-turbo")
        #expect(config.models.map(\.id) == ["ivrit/ivrit-large-v3-turbo", "whisper/whisper-large-v3-turbo"])
        #expect(config.models.first == TranscriptionModel(
            id: "ivrit/ivrit-large-v3-turbo",
            title: "ivrit.ai Hebrew",
            description: "Hebrew tuned"
        ))
    }
}
