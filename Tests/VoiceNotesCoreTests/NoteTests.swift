import Foundation
import Testing
@testable import VoiceNotesCore

struct NoteTests {
    @Test func appendAddsSpaceBetweenSegments() {
        var note = Note(text: "Hello")
        note.append(transcript: "  world. \n")
        #expect(note.text == "Hello world.")
    }

    @Test func appendCollapsesWhitespaceInsideTranscript() {
        var note = Note(text: "A")
        note.append(transcript: " the lake.\n Remember  this. ")
        #expect(note.text == "A the lake. Remember this.")
    }

    @Test func appendJoinsHyphenLineBreak() {
        var note = Note()
        note.append(transcript: "לפני ה-\n meeting.")
        #expect(note.text == "לפני ה-meeting.")
    }

    @Test func appendKeepsUserTrailingWhitespace() {
        var note = Note(text: "Line one\n")
        note.append(transcript: "line two")
        #expect(note.text == "Line one\nline two")
    }

    @Test func appendIgnoresBlankTranscript() {
        let before = Date(timeIntervalSince1970: 0)
        var note = Note(text: "Keep", updatedAt: before)
        note.append(transcript: "   ")
        #expect(note.text == "Keep")
        #expect(note.updatedAt == before)
    }

    @Test func titleUsesFirstLineAndTruncates() {
        #expect(Note().title == "New note")
        #expect(Note(text: "Groceries\nmilk").title == "Groceries")
        let long = String(repeating: "a", count: 80)
        #expect(Note(text: long).title == String(repeating: "a", count: 60) + "…")
    }

    @Test func matchesIsCaseInsensitiveAndEmptyMatchesAll() {
        let note = Note(text: "שלום Meeting notes")
        #expect(note.matches(""))
        #expect(note.matches("meeting"))
        #expect(note.matches("שלום"))
        #expect(!note.matches("budget"))
    }
}
