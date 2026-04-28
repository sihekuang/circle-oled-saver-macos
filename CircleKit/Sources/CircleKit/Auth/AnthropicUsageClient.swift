import Foundation

// MARK: - Token type detection

public enum AnthropicTokenType: Equatable {
    case oauth   // sk-ant-oat... — Claude Code OAuth access token
    case admin   // sk-ant-admin... — Admin API key from Console
    case unknown

    public init(rawToken: String) {
        let t = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("sk-ant-oat") { self = .oauth }
        else if t.hasPrefix("sk-ant-admin") { self = .admin }
        else { self = .unknown }
    }
}

// MARK: - OAuth response (from /api/oauth/usage)

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
        decoder.dateDecodingStrategy = .custom(decodeISO8601)
        return try decoder.decode(AnthropicUsage.self, from: data)
    }
}

// MARK: - Admin cost report response (from /v1/organizations/cost_report)

/// Decoded response from `/v1/organizations/cost_report`. Each result's
/// `amount` is a decimal string in **cents** (lowest currency units), per
/// Anthropic's Admin API: `"123.45"` in `"USD"` represents $1.2345.
public struct AnthropicCostReport: Decodable {
    public let data: [Bucket]
    public let hasMore: Bool
    public let nextPage: String?

    public struct Bucket: Decodable {
        public let startingAt: Date
        public let endingAt: Date
        public let results: [CostItem]

        enum CodingKeys: String, CodingKey {
            case startingAt = "starting_at"
            case endingAt = "ending_at"
            case results
        }
    }

    public struct CostItem: Decodable {
        public let amount: String
        public let currency: String
    }

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case nextPage = "next_page"
    }

    /// Total cost across all buckets and items, in USD.
    public var totalUSD: Double {
        let totalCents = data.reduce(0.0) { acc, bucket in
            acc + bucket.results.reduce(0.0) { sum, item in
                sum + (Double(item.amount) ?? 0)
            }
        }
        return totalCents / 100.0
    }

    public static func decode(_ data: Data) throws -> AnthropicCostReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeISO8601)
        return try decoder.decode(AnthropicCostReport.self, from: data)
    }
}

// Shared ISO8601 date strategy that accepts payloads with or without
// fractional seconds.
private func decodeISO8601(_ d: Decoder) throws -> Date {
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

// MARK: - Client

/// Calls Anthropic's usage APIs. Routes by detected token type:
/// - OAuth tokens (`sk-ant-oat...`) hit `/api/oauth/usage` for subscription
///   utilization percentages (same numbers Claude Desktop shows).
/// - Admin keys (`sk-ant-admin...`) hit `/v1/organizations/cost_report` for
///   organization-level dollar costs.
public final class AnthropicUsageClient {
    public enum ClientError: Error {
        case missingToken
        case unsupportedTokenType
        case http(Int, String)
        case decoding(Error)
        case transport(Error)
    }

    private let session: URLSession
    private let tokenProvider: () -> String?
    private let userAgent = "circle-oled-saver/1.0"

    public init(
        session: URLSession = .shared,
        tokenProvider: @escaping () -> String? = {
            KeychainStore.get(service: KeychainStore.claudeCredentialService)
        }
    ) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    /// Returns the type of the currently stored token, or `.unknown` (and `nil`
    /// raw) when nothing is stored.
    public func currentTokenType() -> AnthropicTokenType {
        guard let token = tokenProvider(), !token.isEmpty else { return .unknown }
        return AnthropicTokenType(rawToken: token)
    }

    // MARK: OAuth path

    public func fetchUsage() async throws -> AnthropicUsage {
        let token = try requireToken()
        guard AnthropicTokenType(rawToken: token) == .oauth else {
            throw ClientError.unsupportedTokenType
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data = try await perform(request)
        do {
            return try AnthropicUsage.decode(data)
        } catch {
            throw ClientError.decoding(error)
        }
    }

    // MARK: Admin path

    /// Fetches the cost report between `start` and `end` (UTC), summing all
    /// buckets and pages, and returns the total in USD.
    public func fetchCostUSD(start: Date, end: Date) async throws -> Double {
        let token = try requireToken()
        guard AnthropicTokenType(rawToken: token) == .admin else {
            throw ClientError.unsupportedTokenType
        }

        var totalUSD = 0.0
        var nextPage: String? = nil
        repeat {
            let report = try await fetchCostPage(token: token, start: start, end: end, page: nextPage)
            totalUSD += report.totalUSD
            nextPage = report.hasMore ? report.nextPage : nil
        } while nextPage != nil
        return totalUSD
    }

    private func fetchCostPage(token: String, start: Date, end: Date, page: String?) async throws -> AnthropicCostReport {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "https://api.anthropic.com/v1/organizations/cost_report")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "starting_at", value: isoFormatter.string(from: start)),
            URLQueryItem(name: "ending_at", value: isoFormatter.string(from: end)),
            URLQueryItem(name: "bucket_width", value: "1d"),
        ]
        if let page { items.append(URLQueryItem(name: "page", value: page)) }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue(token, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data = try await perform(request)
        do {
            return try AnthropicCostReport.decode(data)
        } catch {
            throw ClientError.decoding(error)
        }
    }

    // MARK: Shared

    private func requireToken() throws -> String {
        guard let token = tokenProvider(), !token.isEmpty else {
            throw ClientError.missingToken
        }
        return token
    }

    private func perform(_ request: URLRequest) async throws -> Data {
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
        return data
    }
}
