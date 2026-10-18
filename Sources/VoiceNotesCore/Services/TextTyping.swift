import Foundation

@MainActor
public protocol TextTyping: AnyObject {
    func type(_ text: String) throws
}
