import Foundation

public struct RequestLoggingInterceptor: RequestInterceptor {
    private let logger: NetworkLogger

    public init(logger: NetworkLogger) {
        self.logger = logger
    }

    public func adapt(_ request: URLRequest, options: RequestOptions) async throws -> URLRequest {
        logger.logRequest(request)
        return request
    }
}
