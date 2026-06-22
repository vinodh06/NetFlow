import Foundation

/// Options for configuring individual HTTP requests.
///
/// `RequestOptions` allows you to customize behavior for specific requests,
/// such as whether authorization is required, additional headers, and timeout settings.
///
/// ## Example
///
/// ```swift
/// let options = RequestOptions(
///     requiresAuthorization: false,
///     additionalHeaders: ["X-Custom-Header": "value"],
///     timeoutInterval: 30
/// )
///
/// let response = try await client.send(request, options: options)
/// ```
public struct RequestOptions: Sendable {
    /// Whether this request requires authorization.
    ///
    /// When `true`, request interceptors (like `AuthorizationInterceptor`)
    /// will add authentication headers to the request.
    public let requiresAuthorization: Bool
    
    /// Additional headers to include in this request.
    ///
    /// These headers are merged with any headers defined in the endpoint
    /// or added by request interceptors.
    public let additionalHeaders: [String: String]
    
    /// The timeout interval for this request in seconds.
    ///
    /// If specified, this overrides the default timeout of the URLSession.
    /// This value is applied by the `DefaultHeadersInterceptor`.
    public let timeoutInterval: TimeInterval?

    /// Creates new request options.
    ///
    /// - Parameters:
    ///   - requiresAuthorization: Whether authorization is required. Defaults to `true`.
    ///   - additionalHeaders: Extra headers to include. Defaults to empty dictionary.
    ///   - timeoutInterval: Custom timeout in seconds. Defaults to `nil` (uses session default).
    public init(
        requiresAuthorization: Bool = true,
        additionalHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval? = nil
    ) {
        self.requiresAuthorization = requiresAuthorization
        self.additionalHeaders = additionalHeaders
        self.timeoutInterval = timeoutInterval
    }
}
