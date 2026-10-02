import Foundation

/// A protocol for defining type-safe API endpoints.
///
/// Conforming types describe an API endpoint including its URL, HTTP method,
/// headers, and response type. The `Endpoint` protocol provides default
/// implementations for common properties.
///
/// ## Struct-Based Endpoints
///
/// It's recommended to define endpoints as structs rather than enums, as this
/// allows each endpoint to have its own unique response type without requiring
/// wrapper types or complex type erasure.
///
/// ## Example
///
/// ```swift
/// struct User: Decodable, Sendable {
///     let id: Int
///     let name: String
/// }
///
/// struct Post: Decodable, Sendable {
///     let id: Int
///     let title: String
/// }
///
/// struct GetUserEndpoint: Endpoint {
///     typealias Response = User
///
///     let userId: Int
///
///     var baseURL: URL {
///         URL(string: "https://api.example.com")!
///     }
///
///     var path: String {
///         "/users/\(userId)"
///     }
///
///     var method: HTTPMethod {
///         .get
///     }
/// }
///
/// struct GetUserPostsEndpoint: Endpoint {
///     typealias Response = [Post]  // Different response type!
///
///     let userId: Int
///
///     var baseURL: URL {
///         URL(string: "https://api.example.com")!
///     }
///
///     var path: String {
///         "/posts"
///     }
///
///     var method: HTTPMethod {
///         .get
///     }
///
///     var queryItems: [URLQueryItem] {
///         [URLQueryItem(name: "userId", value: "\(userId)")]
///     }
/// }
///
/// // Usage - each endpoint returns its own type
/// let user: User = try await client.send(GetUserEndpoint(userId: 123))
/// let posts: [Post] = try await client.send(GetUserPostsEndpoint(userId: 123))
/// ```
public protocol Endpoint: Sendable {
    /// The type of the expected response.
    associatedtype Response: Codable & Sendable

    /// The base URL for the API.
    var baseURL: URL { get }
    
    /// The path to append to the base URL.
    var path: String { get }
    
    /// The HTTP method for the request.
    var method: HTTPMethod { get }
    
    /// HTTP headers to include in the request.
    var headers: [String: String] { get }
    
    /// Query parameters to append to the URL.
    var queryItems: [URLQueryItem] { get }
    
    /// The request body data.
    var body: Data? { get }
    
    /// Additional options for the request.
    var options: RequestOptions { get }
    
    /// The JSON decoder to use for decoding the response.
    var decoder: JSONDecoder { get }
}

public extension Endpoint {
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
    var body: Data? { nil }
    var options: RequestOptions { RequestOptions() }
    var decoder: JSONDecoder { JSONDecoder() }

    /// Creates a URLRequest from the endpoint configuration.
    ///
    /// - Returns: A configured URLRequest ready to be sent.
    /// - Throws: `NetworkError.invalidRequest` if the URL cannot be constructed.
    func makeRequest() throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidRequest("Unable to create URL components for \(path)")
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidRequest("Unable to build URL for \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
    
    /// Creates a URLRequest with an HTTPBody.
    ///
    /// This is a convenience method that automatically sets the body data
    /// and Content-Type header from the HTTPBody.
    ///
    /// - Parameter httpBody: The HTTPBody to include in the request.
    /// - Returns: A configured URLRequest with the body and content type set.
    /// - Throws: `NetworkError.invalidRequest` if the URL cannot be constructed.
    func makeRequest(with httpBody: HTTPBody) throws -> URLRequest {
        var request = try makeRequest()
        request.httpBody = httpBody.data
        request.setValue(httpBody.contentType, forHTTPHeaderField: "Content-Type")
        return request
    }
}

