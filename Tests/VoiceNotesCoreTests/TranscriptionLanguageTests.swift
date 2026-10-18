import Testing
@testable import VoiceNotesCore

struct TranscriptionLanguageTests {
    @Test func rawValuesStayStable() {
        #expect(TranscriptionLanguage.allCases.map(\.rawValue) == ["hebrewWithEnglish", "english", "auto"])
    }

    @Test func autoSendsExplicitAutoCodeWithoutPrompt() {
        #expect(TranscriptionLanguage.auto.languageCode == "auto")
        #expect(TranscriptionLanguage.auto.prompt == nil)
    }

    @Test func endpointDefaultsToHebrewWithEnglish() throws {
        let endpoint = try #require(TranscriptionEndpoint(baseURL: "https://h/v1", model: "m", apiKey: ""))
        #expect(endpoint.language == .hebrewWithEnglish)
    }
}
