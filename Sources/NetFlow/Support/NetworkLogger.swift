import Foundation

public protocol NetworkLogger: Sendable {
    func logRequest(_ request: URLRequest)
    func logResponse(_ response: HTTPURLResponse, data: Data)
    func logError(_ error: Error, request: URLRequest)
}

public struct ConsoleNetworkLogger: NetworkLogger {
    public init() {}

    public func logRequest(_ request: URLRequest) {
        #if DEBUG
        print("➡️ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        print("Headers:", request.allHTTPHeaderFields ?? [:])
        if let body = request.httpBody,
           let text = String(data: body, encoding: .utf8) {
            print("Body:", text)
        }
        #endif
    }

    public func logResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
        print("⬅️ [\(response.statusCode)] \(response.url?.absoluteString ?? "")")
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            print("Response:", text)
        }
        #endif
    }

    public func logError(_ error: Error, request: URLRequest) {
        #if DEBUG
        print("❌ \(request.url?.absoluteString ?? "")")
        print("Error:", error.localizedDescription)
        #endif
    }
}
