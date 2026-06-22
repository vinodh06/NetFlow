import Foundation

public struct ResponseLoggingInterceptor: ResponseInterceptor {
    private let logger: NetworkLogger

    public init(logger: NetworkLogger) {
        self.logger = logger
    }

    public func intercept(
        result: Result<(Data, HTTPURLResponse), Error>,
        originalRequest: URLRequest,
        options: RequestOptions,
        retryCount: Int,
        retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        switch result {
        case .success(let value):
            logger.logResponse(value.1, data: value.0)
            return value
        case .failure(let error):
            logger.logError(error, request: originalRequest)
            throw error
        }
    }
}
