import Foundation

/// Errors that can occur during network operations.
public enum NetworkError: Error, LocalizedError, Equatable, Sendable {
    /// The server returned a non-HTTP response.
    case invalidResponse
    
    /// The request requires authentication (HTTP 401).
    case unauthorized
    
    /// Failed to refresh the authentication token.
    case refreshFailed
    
    /// The server returned an HTTP error status code.
    /// - Parameters:
    ///   - statusCode: The HTTP status code.
    ///   - message: Optional response message extracted from the response body.
    case httpStatus(statusCode: Int, message: String? = nil)
    
    /// No refresh token is available for authentication.
    case noRefreshToken
    
    /// The request could not be constructed or is invalid.
    case invalidRequest(String)
    
    /// Failed to decode the response data.
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - authentication required"
        case .refreshFailed:
            return "Failed to refresh authentication token"
        case .httpStatus(let code, let message):
            if let message = message {
                return "HTTP \(code): \(message)"
            }
            return "HTTP status code: \(code)"
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        }
    }

    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.refreshFailed, .refreshFailed),
             (.noRefreshToken, .noRefreshToken):
            return true
        case let (.httpStatus(l, lm), .httpStatus(r, rm)):
            return l == r && lm == rm
        case let (.invalidRequest(l), .invalidRequest(r)):
            return l == r
        case let (.decodingFailed(l), .decodingFailed(r)):
            return l == r
        default:
            return false
        }
    }
}
