import Foundation

/// An interceptor that logs HTTP requests and responses.
///
/// This interceptor implements both `RequestInterceptor` and `ResponseInterceptor`
/// to provide comprehensive logging of network activity. It uses a `NetworkLogger`
/// to perform the actual logging, which allows for customization of log output.
///
/// ## Example
///
/// ```swift
/// let client = HTTPClient(
///     requestInterceptors: [LoggingInterceptor()],
///     responseInterceptors: [LoggingInterceptor()]
/// )
/// ```
public struct LoggingInterceptor: RequestInterceptor, ResponseInterceptor {
    private let logger: NetworkLogger
    
    /// Creates a new logging interceptor.
    ///
    /// - Parameter logger: The logger to use for output. Defaults to `ConsoleNetworkLogger`.
    public init(logger: NetworkLogger = ConsoleNetworkLogger()) {
        self.logger = logger
    }
    
    // MARK: - RequestInterceptor
    
    public func adapt(_ request: URLRequest, options: RequestOptions) async throws -> URLRequest {
        logger.logRequest(request)
        return request
    }
    
    // MARK: - ResponseInterceptor
    
    public func intercept(
        result: Result<(Data, HTTPURLResponse), Error>,
        originalRequest: URLRequest,
        options: RequestOptions,
        retryCount: Int,
        retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        switch result {
        case .success(let (data, response)):
            logger.logResponse(response, data: data)
            return (data, response)
        case .failure(let error):
            logger.logError(error, request: originalRequest)
            throw error
        }
    }
}
