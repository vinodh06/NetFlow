import Foundation

/// A protocol for intercepting and modifying requests before they are sent.
///
/// Request interceptors are called in order before a request is sent to the server.
/// They can modify the request by adding headers, changing the URL, or performing
/// any other transformations.
///
/// ## Example
///
/// ```swift
/// struct CustomHeaderInterceptor: RequestInterceptor {
///     func adapt(_ request: URLRequest, options: RequestOptions) async throws -> URLRequest {
///         var request = request
///         request.setValue("CustomValue", forHTTPHeaderField: "X-Custom-Header")
///         return request
///     }
/// }
/// ```
public protocol RequestInterceptor: Sendable {
    /// Adapts a request before it is sent.
    ///
    /// - Parameters:
    ///   - request: The original URLRequest.
    ///   - options: Options for this request.
    /// - Returns: The modified URLRequest.
    /// - Throws: An error if the request cannot be adapted.
    func adapt(_ request: URLRequest, options: RequestOptions) async throws -> URLRequest
}
