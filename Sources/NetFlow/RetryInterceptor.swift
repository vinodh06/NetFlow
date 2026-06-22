import Foundation

/// An interceptor that automatically retries failed requests.
///
/// This interceptor implements exponential backoff for retrying requests that fail
/// with specific HTTP status codes or network errors. It's useful for handling
/// transient failures like rate limiting, timeouts, and server errors.
///
/// ## Example
///
/// ```swift
/// let retryInterceptor = RetryInterceptor(
///     maxRetries: 3,
///     retryableStatusCodes: [408, 429, 500, 502, 503, 504],
///     baseDelay: 1.0
/// )
///
/// let client = HTTPClient(
///     responseInterceptors: [retryInterceptor, StatusCodeInterceptor()]
/// )
/// ```
///
/// ## Exponential Backoff
///
/// The delay between retries increases exponentially:
/// - First retry: baseDelay seconds
/// - Second retry: baseDelay * 2 seconds
/// - Third retry: baseDelay * 4 seconds
/// - And so on...
public struct RetryInterceptor: ResponseInterceptor {
    private let maxRetries: Int
    private let retryableStatusCodes: Set<Int>
    private let baseDelay: TimeInterval
    
    /// Creates a new retry interceptor.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts. Defaults to 3.
    ///   - retryableStatusCodes: HTTP status codes that should trigger a retry.
    ///     Defaults to common transient error codes: 408 (Timeout), 429 (Rate Limit),
    ///     500 (Server Error), 502 (Bad Gateway), 503 (Service Unavailable), 504 (Gateway Timeout).
    ///   - baseDelay: The base delay in seconds before the first retry. Defaults to 1.0.
    ///     Subsequent retries use exponential backoff.
    public init(
        maxRetries: Int = 3,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        baseDelay: TimeInterval = 1.0
    ) {
        self.maxRetries = maxRetries
        self.retryableStatusCodes = retryableStatusCodes
        self.baseDelay = baseDelay
    }
    
    public func intercept(
        result: Result<(Data, HTTPURLResponse), Error>,
        originalRequest: URLRequest,
        options: RequestOptions,
        retryCount: Int,
        retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        switch result {
        case .success(let (data, response)):
            // Check if status code is retryable
            if retryableStatusCodes.contains(response.statusCode), retryCount < maxRetries {
                return try await performRetry(
                    request: originalRequest,
                    options: options,
                    retryCount: retryCount,
                    retry: retry
                )
            }
            return (data, response)
            
        case .failure(let error):
            // Retry on network errors (but not on client errors like invalid URLs)
            if shouldRetryError(error), retryCount < maxRetries {
                return try await performRetry(
                    request: originalRequest,
                    options: options,
                    retryCount: retryCount,
                    retry: retry
                )
            }
            throw error
        }
    }
    
    private func performRetry(
        request: URLRequest,
        options: RequestOptions,
        retryCount: Int,
        retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        // Calculate exponential backoff delay
        let delay = baseDelay * pow(2.0, Double(retryCount))
        
        // Wait before retrying
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Perform the retry
        return try await retry(request, options, retryCount + 1)
    }
    
    private func shouldRetryError(_ error: Error) -> Bool {
        // Retry on URLSession errors that are transient
        let nsError = error as NSError
        
        // Network connection errors
        let retryableURLErrorCodes: Set<Int> = [
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDNSLookupFailed,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorSecureConnectionFailed
        ]
        
        if nsError.domain == NSURLErrorDomain {
            return retryableURLErrorCodes.contains(nsError.code)
        }
        
        // Don't retry on our custom NetworkErrors (those should be handled by status code logic)
        return false
    }
}
