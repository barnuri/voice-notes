import Foundation

extension Error {
    var userMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}
