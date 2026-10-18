import Foundation

enum ISO8601DateCoding {
    private static let fractionalStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let wholeSecondStyle = Date.ISO8601FormatStyle()

    static var encodingStrategy: JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(fractionalStyle))
        }
    }

    static var decodingStrategy: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected an ISO-8601 date, got \(text)")
            }
            return date
        }
    }

    static func parse(_ text: String) -> Date? {
        (try? fractionalStyle.parse(text)) ?? (try? wholeSecondStyle.parse(text))
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = encodingStrategy
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = decodingStrategy
        return decoder
    }
}
