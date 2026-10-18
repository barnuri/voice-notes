import Foundation

public enum TranscriptionLanguage: String, CaseIterable, Sendable {
    case hebrewWithEnglish
    case english
    case auto

    public var title: String {
        switch self {
        case .hebrewWithEnglish: "Hebrew + English words"
        case .english: "English"
        case .auto: "Auto-detect"
        }
    }

    public var shortTitle: String {
        switch self {
        case .hebrewWithEnglish: "עב+EN"
        case .english: "EN"
        case .auto: "Auto"
        }
    }

    public var languageCode: String {
        switch self {
        case .hebrewWithEnglish: "he"
        case .english: "en"
        case .auto: "auto"
        }
    }

    public var prompt: String? {
        switch self {
        case .hebrewWithEnglish: "שלום, היום עשינו deploy לשרת ושלחנו email לצוות לפני ה-meeting."
        case .english, .auto: nil
        }
    }
}
