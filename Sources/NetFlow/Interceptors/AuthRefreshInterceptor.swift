import Foundation

/// Handles 401 responses by triggering token refresh and retrying the request
/// Users provide a closure that performs the refresh logic
public struct AuthRefreshInterceptor: ResponseInterceptor {
    private let performRefresh: @Sendable () async throws -> Void
    private let maxRetryCount: Int

    /// Initialize with a closure that performs token refresh
    /// - Parameters:
    ///   - performRefresh: Closure that refreshes the token
    ///   - maxRetryCount: Maximum number of retry attempts (default: 1)
    public init(
        performRefresh: @escaping @Sendable () async throws -> Void,
        maxRetryCount: Int = 1
    ) {
        self.performRefresh = performRefresh
        self.maxRetryCount = maxRetryCount
    }

    public func intercept(
        result: Result<(Data, HTTPURLResponse), Error>,
        originalRequest: URLRequest,
        options: RequestOptions,
        retryCount: Int,
        retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        switch result {
        case .success(let success):
            guard success.1.statusCode == 401 else {
                return success
            }

            guard options.requiresAuthorization else {
                throw NetworkError.unauthorized
            }

            guard retryCount < maxRetryCount else {
                throw NetworkError.unauthorized
            }

            // Trigger refresh
            try await performRefresh()
            
            // Retry the request
            return try await retry(originalRequest, options, retryCount + 1)

        case .failure(let error):
            throw error
        }
    }
}

