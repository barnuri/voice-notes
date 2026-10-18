import Foundation

public enum MicrophoneSelection {
    public static func resolve(storedID: String, available: [String], defaultID: String?) -> String? {
        available.contains(storedID) ? storedID : defaultID
    }
}
