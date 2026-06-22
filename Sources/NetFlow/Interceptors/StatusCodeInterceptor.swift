import Foundation

/// Validates HTTP status codes and throws errors for unsuccessful responses.
///
/// This interceptor checks if the response status code is in the 2xx range.
/// For 401 (Unauthorized), it throws `NetworkError.unauthorized`.
/// For other error status codes, it throws `NetworkError.httpStatus` with an optional message.
public struct StatusCodeInterceptor: ResponseInterceptor {
    public init() {}

    public func intercept(
        result: Result<(Data, HTTPURLResponse), Error>,
        originalRequest: URLRequest,
        options: RequestOptions,
        retryCount: Int,
        retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        switch result {
        case .success(let (data, response)):
            guard (200...299).contains(response.statusCode) else {
                if response.statusCode == 401 {
                    throw NetworkError.unauthorized
                }
                
                // Try to extract error message from response body
                let message = String(data: data, encoding: .utf8)
                throw NetworkError.httpStatus(statusCode: response.statusCode, message: message)
            }
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}
