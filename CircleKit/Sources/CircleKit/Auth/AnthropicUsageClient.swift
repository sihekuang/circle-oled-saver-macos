import Foundation

/// Decoded response from `/api/oauth/usage`. Subscription-tied accounts get a
/// payload like:
/// ```
/// {
///   "five_hour":        {"utilization": 35.0, "resets_at": "2026-04-28T01:20:00+00:00"},
///   "seven_day":        {"utilization": 48.0, "resets_at": "2026-04-28T12:00:00+00:00"},
///   "seven_day_sonnet": {"utilization": 12.0, "resets_at": "..."},
///   ...
/// }
/// ```
public struct AnthropicUsage: Decodable {
    public let fiveHour: Bucket?
    public let sevenDay: Bucket?
    public let sevenDaySonnet: Bucket?

    public struct Bucket: Decodable {
        public let utilization: Double
        public let resetsAt: Date?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }

    public static func decode(_ data: Data) throws -> AnthropicUsage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let s = try container.decode(String.self)
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: s) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized ISO8601 date: \(s)"
            )
        }
        return try decoder.decode(AnthropicUsage.self, from: data)
    }
}

/// Calls `/api/oauth/usage` with the current access token from Claude Code's
/// keychain entry. Claude Code itself does the OAuth refresh dance — we just
/// read whatever access token is current at fetch time.
public final class AnthropicUsageClient {
    public enum ClientError: Error {
        case missingToken
        case http(Int, String)
        case decoding(Error)
        case transport(Error)
    }

    private let session: URLSession
    private let tokenProvider: () -> String?

    public init(
        session: URLSession = .shared,
        tokenProvider: @escaping () -> String? = { ClaudeCodeKeychain.readAccessToken() }
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    public func fetchUsage() async throws -> AnthropicUsage {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw ClientError.missingToken
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("circle-oled-saver/1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClientError.transport(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(http.statusCode, body)
        }

        do {
            return try AnthropicUsage.decode(data)
        } catch {
            throw ClientError.decoding(error)
        }
    }
}
