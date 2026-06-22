import Foundation

/// A modern, type-safe HTTP client built with Swift concurrency.
///
/// `HTTPClient` provides a clean API for making HTTP requests with support for:
/// - Request and response interceptors for cross-cutting concerns
/// - Type-safe endpoint definitions
/// - Automatic JSON encoding/decoding
/// - Retry logic and error handling
/// - Task cancellation support (via Swift's structured concurrency)
///
/// ## Example Usage
///
/// ```swift
/// let client = HTTPClient(
///     requestInterceptors: [DefaultHeadersInterceptor(), AuthorizationInterceptor()],
///     responseInterceptors: [StatusCodeInterceptor(), LoggingInterceptor()]
/// )
///
/// let user: User = try await client.send(UserAPI.getUser(id: 123))
/// ```
///
/// ## Cancellation
///
/// All async methods support cancellation through Swift's task cancellation:
///
/// ```swift
/// let task = Task {
///     try await client.send(request)
/// }
/// task.cancel() // Cancels the network request
/// ```
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class HTTPClient: Sendable {
    private let session: URLSession
    private let requestInterceptors: [any RequestInterceptor]
    private let responseInterceptors: [any ResponseInterceptor]

    /// Creates a new HTTP client.
    ///
    /// - Parameters:
    ///   - session: The URLSession to use for requests. Defaults to `.shared`.
    ///   - requestInterceptors: Interceptors that modify requests before they're sent.
    ///   - responseInterceptors: Interceptors that process responses and handle errors.
    public init(
        session: URLSession = .shared,
        requestInterceptors: [any RequestInterceptor] = [],
        responseInterceptors: [any ResponseInterceptor] = []
    ) {
        self.session = session
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
    }

    /// Sends a URLRequest and returns the raw data and response.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to send.
    ///   - options: Additional options for this request.
    /// - Returns: A tuple containing the response data and HTTP response.
    /// - Throws: `NetworkError` or URLSession errors.
    public func send(
        _ request: URLRequest,
        options: RequestOptions = RequestOptions()
    ) async throws -> (Data, HTTPURLResponse) {
        try await execute(request, options: options, retryCount: 0)
    }

    /// Sends a URLRequest and decodes the response to the specified type.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to send.
    ///   - options: Additional options for this request.
    ///   - decoder: The JSONDecoder to use for decoding the response.
    /// - Returns: The decoded response object.
    /// - Throws: `NetworkError.decodingFailed` if decoding fails, or other `NetworkError` types.
    public func sendDecodable<T: Decodable>(
        _ request: URLRequest,
        options: RequestOptions = RequestOptions(),
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let (data, _) = try await send(request, options: options)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error.localizedDescription)
        }
    }

    /// Sends an endpoint and returns its typed response.
    ///
    /// - Parameter endpoint: The endpoint to send.
    /// - Returns: The decoded response as defined by the endpoint's Response type.
    /// - Throws: `NetworkError` or endpoint-specific errors.
    public func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        let request = try endpoint.makeRequest()
        return try await sendDecodable(request, options: endpoint.options, decoder: endpoint.decoder)
    }

    private func execute(
        _ originalRequest: URLRequest,
        options: RequestOptions,
        retryCount: Int
    ) async throws -> (Data, HTTPURLResponse) {
        var request = originalRequest

        for interceptor in requestInterceptors {
            request = try await interceptor.adapt(request, options: options)
        }

        let baseResult: Result<(Data, HTTPURLResponse), Error>

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            baseResult = .success((data, httpResponse))
        } catch {
            baseResult = .failure(error)
        }

        var current = baseResult

        for interceptor in responseInterceptors {
            do {
                let value = try await interceptor.intercept(
                    result: current,
                    originalRequest: request,
                    options: options,
                    retryCount: retryCount,
                    retry: { [unowned self] request, options, nextRetryCount in
                        try await self.execute(request, options: options, retryCount: nextRetryCount)
                    }
                )
                current = .success(value)
            } catch {
                current = .failure(error)
            }
        }

        switch current {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
