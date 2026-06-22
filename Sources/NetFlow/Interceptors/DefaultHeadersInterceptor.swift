import Foundation

public struct DefaultHeadersInterceptor: RequestInterceptor {
    public init() {}

    public func adapt(_ request: URLRequest, options: RequestOptions) async throws -> URLRequest {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if request.httpBody != nil,
           request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        options.additionalHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let timeoutInterval = options.timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }

        return request
    }
}
