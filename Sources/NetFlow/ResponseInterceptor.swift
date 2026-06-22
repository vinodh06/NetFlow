import Foundation

/// A protocol for intercepting and processing responses after they are received.
///
/// Response interceptors are called in order after a response is received from the server.
/// They can validate responses, handle errors, retry requests, or transform the response data.
///
/// ## Example
///
/// ```swift
/// struct ErrorHandlerInterceptor: ResponseInterceptor {
///     func intercept(
///         result: Result<(Data, HTTPURLResponse), Error>,
///         originalRequest: URLRequest,
///         options: RequestOptions,
///         retryCount: Int,
///         retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
///     ) async throws -> (Data, HTTPURLResponse) {
///         switch result {
///         case .success(let value):
///             return value
///         case .failure(let error):
///             // Custom error handling
///             throw error
///         }
///     }
/// }
/// ```
public protocol ResponseInterceptor: Sendable {
    /// Intercepts a response and optionally retries the request.
    ///
    /// - Parameters:
    ///   - result: The result of the request (success with data/response or failure with error).
    ///   - originalRequest: The original URLRequest that was sent.
    ///   - options: Options for this request.
    ///   - retryCount: The number of times this request has been retried.
    ///   - retry: A closure that can be called to retry the request with updated parameters.
    /// - Returns: The validated response data and HTTP response.
    /// - Throws: An error if the response is invalid or retry fails.
    func intercept(
        result: Result<(Data, HTTPURLResponse), Error>,
        originalRequest: URLRequest,
        options: RequestOptions,
        retryCount: Int,
        retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse)
}
