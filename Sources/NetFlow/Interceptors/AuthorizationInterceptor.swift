import Foundation

/// Adds authorization header to requests
/// Users provide a closure that returns the access token
public struct AuthorizationInterceptor: RequestInterceptor {
    private let getAccessToken: @Sendable () async -> String?

    /// Initialize with a closure that provides the access token
    /// - Parameter getAccessToken: Closure that returns the current access token
    public init(getAccessToken: @escaping @Sendable () async -> String?) {
        self.getAccessToken = getAccessToken
    }

    public func adapt(_ request: URLRequest, options: RequestOptions) async throws -> URLRequest {
        var request = request

        if options.requiresAuthorization,
           let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
}

