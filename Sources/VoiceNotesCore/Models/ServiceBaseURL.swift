import Foundation

public enum ServiceBaseURL {
    private static let loopbackHosts: Set<String> = ["127.0.0.1", "::1", "localhost"]

    public static func parse(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              let host = url.host()?.lowercased() else { return nil }
        let allowsScheme = scheme == "https" || (scheme == "http" && loopbackHosts.contains(host))
        guard allowsScheme else { return nil }
        return url.path().hasSuffix("/") ? url : URL(string: trimmed + "/")
    }
}
