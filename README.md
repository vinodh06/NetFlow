# HTTPClient

A modern, type-safe HTTP networking library for Swift built with Swift concurrency (async/await). Designed for iOS 15+, macOS 12+, tvOS 15+, and watchOS 8+.

## Features

✨ **Modern Swift Concurrency** - Built from the ground up with async/await  
🔒 **Type-Safe** - Leverage Swift's type system with the `Endpoint` protocol  
🔌 **Extensible** - Powerful interceptor pattern for cross-cutting concerns  
📦 **Lightweight** - Zero dependencies, built on URLSession  
🎯 **Easy to Use** - Clean, intuitive API with sensible defaults  
🧪 **Sendable Throughout** - Fully compatible with Swift 6 strict concurrency  

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
  - [HTTPClient](#httpclient-1)
  - [Endpoints](#endpoints)
  - [Request Bodies](#request-bodies)
  - [Interceptors](#interceptors)
- [Built-in Interceptors](#built-in-interceptors)
- [Error Handling](#error-handling)
- [Advanced Usage](#advanced-usage)
- [Examples](#examples)
- [Migration Guide](#migration-guide)
- [Advanced Endpoint Patterns](ENDPOINT_PATTERNS.md) 📘

---

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/HTTPClient.git", from: "1.0.0")
]
```

Or add it directly in Xcode via **File > Add Packages...**

---

## Quick Start

### Basic Request

```swift
import HTTPClient

// Create a client
let client = HTTPClient()

// Make a simple request
let url = URL(string: "https://api.example.com/users/123")!
var request = URLRequest(url: url)
request.httpMethod = "GET"

let (data, response) = try await client.send(request)
```

### Type-Safe Request with Endpoint Protocol

```swift
// Define your models
struct User: Codable, Sendable {
    let id: Int
    let name: String
    let email: String
}

struct Post: Codable, Sendable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

// Define your endpoints as structs
struct GetUserEndpoint: Endpoint {
    typealias Response = User
    
    let userId: Int
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String {
        "/users/\(userId)"
    }
    
    var method: HTTPMethod {
        .get
    }
}

struct CreateUserEndpoint: Endpoint {
    typealias Response = User
    
    let name: String
    let email: String
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String {
        "/users"
    }
    
    var method: HTTPMethod {
        .post
    }
    
    var body: Data? {
        try? HTTPBody.json(["name": name, "email": email]).data
    }
}

struct GetUserPostsEndpoint: Endpoint {
    typealias Response = [Post]  // Different response type!
    
    let userId: Int
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String {
        "/posts"
    }
    
    var method: HTTPMethod {
        .get
    }
    
    var queryItems: [URLQueryItem] {
        [URLQueryItem(name: "userId", value: "\(userId)")]
    }
}

// Use them - each has its own response type!
let user = try await client.send(GetUserEndpoint(userId: 123))
print(user.name) // Type-safe User!

let posts = try await client.send(GetUserPostsEndpoint(userId: 123))
print(posts.count) // Type-safe [Post]!
```

---

## Core Concepts

### HTTPClient

The main entry point for making HTTP requests. Configure it once with your interceptors and reuse it throughout your app.

```swift
let client = HTTPClient(
    session: .shared,
    requestInterceptors: [
        DefaultHeadersInterceptor(),
        AuthorizationInterceptor { await AuthManager.shared.accessToken }
    ],
    responseInterceptors: [
        LoggingInterceptor(),
        RetryInterceptor(maxRetries: 3),
        StatusCodeInterceptor()
    ]
)
```

#### Methods

**Send URLRequest**
```swift
func send(_ request: URLRequest, options: RequestOptions = RequestOptions()) 
    async throws -> (Data, HTTPURLResponse)
```

**Send and Decode**
```swift
func sendDecodable<T: Decodable & Sendable>(_ request: URLRequest, 
                                             options: RequestOptions = RequestOptions(),
                                             decoder: JSONDecoder = JSONDecoder()) 
    async throws -> T
```

**Send Endpoint**
```swift
func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response
```

### Endpoints

The `Endpoint` protocol provides a type-safe way to define API endpoints. Each endpoint struct can have its own unique response type.

```swift
public protocol Endpoint: Sendable {
    associatedtype Response: Decodable & Sendable
    
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }          // Optional
    var queryItems: [URLQueryItem] { get }         // Optional
    var body: Data? { get }                        // Optional
    var options: RequestOptions { get }            // Optional
    var decoder: JSONDecoder { get }               // Optional
}
```

**Default implementations** are provided for `headers`, `queryItems`, `body`, `options`, and `decoder`.

**Why Use Structs Instead of Enums?**

Defining endpoints as structs (rather than enums) gives you several advantages:

1. **Multiple Response Types**: Each endpoint can have its own response type
2. **Better Composition**: Easily compose endpoints with shared base URLs or headers
3. **Type Safety**: The compiler enforces the correct response type for each endpoint
4. **Cleaner Code**: No need for complex switch statements or wrapper types

**Example:**

```swift
// Each endpoint has its own response type
struct GetUserEndpoint: Endpoint {
    typealias Response = User  // Returns User
    let id: Int
    // ...
}

struct GetPostsEndpoint: Endpoint {
    typealias Response = [Post]  // Returns [Post]
    let userId: Int
    // ...
}

// Type-safe usage
let user: User = try await client.send(GetUserEndpoint(id: 123))
let posts: [Post] = try await client.send(GetPostsEndpoint(userId: 123))
```

### Request Bodies

The `HTTPBody` builder makes it easy to create request bodies in various formats.

#### JSON

```swift
struct CreateUserRequest: Encodable, Sendable {
    let name: String
    let email: String
}

let body = try HTTPBody.json(CreateUserRequest(name: "John", email: "john@example.com"))
```

#### URL-Encoded Form

```swift
let body = try HTTPBody.urlEncoded([
    "username": "john",
    "password": "secret"
])
```

#### Multipart Form Data

```swift
let parts = [
    try MultipartFormPart.field(name: "title", value: "My Photo"),
    MultipartFormPart.file(
        name: "photo",
        data: imageData,
        filename: "photo.jpg",
        mimeType: "image/jpeg"
    )
]

let body = try HTTPBody.multipart(parts)
```

#### Plain Text

```swift
let body = try HTTPBody.text("Hello, world!")
```

#### Raw Data

```swift
let body = HTTPBody.raw(data, contentType: "application/octet-stream")
```

### Using HTTPBody with Endpoints

```swift
struct CreateUserEndpoint: Endpoint {
    typealias Response = User
    
    let name: String
    let email: String
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String { "/users" }
    var method: HTTPMethod { .post }
    
    // Option 1: Use body property directly
    var body: Data? {
        try? HTTPBody.json(["name": name, "email": email]).data
    }
}

// Or for more complex cases:
struct UploadPhotoEndpoint: Endpoint {
    typealias Response = PhotoResponse
    
    let userId: Int
    let imageData: Data
    let caption: String
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String { "/photos/upload" }
    var method: HTTPMethod { .post }
    
    // Option 2: Override makeRequest for full control
    func makeRequest() throws -> URLRequest {
        let parts = [
            try MultipartFormPart.field(name: "userId", value: "\(userId)"),
            try MultipartFormPart.field(name: "caption", value: caption),
            MultipartFormPart.file(
                name: "photo",
                data: imageData,
                filename: "photo.jpg",
                mimeType: "image/jpeg"
            )
        ]
        let body = try HTTPBody.multipart(parts)
        return try makeRequest(with: body)  // Automatically sets Content-Type
    }
}

// Usage
let user = try await client.send(CreateUserEndpoint(name: "John", email: "john@example.com"))
let photo = try await client.send(UploadPhotoEndpoint(userId: 1, imageData: data, caption: "Sunset"))
```

### Interceptors

Interceptors allow you to add cross-cutting concerns like authentication, logging, and retry logic.

#### Request Interceptors

Modify requests before they are sent:

```swift
public protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest, options: RequestOptions) async throws -> URLRequest
}
```

#### Response Interceptors

Process responses and handle errors:

```swift
public protocol ResponseInterceptor: Sendable {
    func intercept(
        result: Result<(Data, HTTPURLResponse), Error>,
        originalRequest: URLRequest,
        options: RequestOptions,
        retryCount: Int,
        retry: @Sendable (URLRequest, RequestOptions, Int) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse)
}
```

---

## Built-in Interceptors

### DefaultHeadersInterceptor

Adds standard headers to all requests:
- Sets `Accept: application/json`
- Sets `Content-Type: application/json` for requests with a body
- Applies custom timeout intervals from `RequestOptions`

```swift
let interceptor = DefaultHeadersInterceptor()
```

### AuthorizationInterceptor

Adds Bearer token authorization to requests:

```swift
let interceptor = AuthorizationInterceptor {
    await AuthManager.shared.accessToken
}
```

### StatusCodeInterceptor

Validates HTTP status codes and throws errors for non-2xx responses:

```swift
let interceptor = StatusCodeInterceptor()
```

### LoggingInterceptor

Logs requests and responses for debugging:

```swift
let interceptor = LoggingInterceptor()
// Or with a custom logger
let interceptor = LoggingInterceptor(logger: MyCustomLogger())
```

### RetryInterceptor

Automatically retries failed requests with exponential backoff:

```swift
let interceptor = RetryInterceptor(
    maxRetries: 3,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504],
    baseDelay: 1.0
)
```

**Retry Logic:**
- Retries on network errors (timeouts, connection lost, etc.)
- Retries on specific HTTP status codes
- Uses exponential backoff: 1s, 2s, 4s, 8s, etc.

---

## Error Handling

All errors conform to `NetworkError`:

```swift
public enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case refreshFailed
    case httpStatus(statusCode: Int, message: String? = nil)
    case noRefreshToken
    case invalidRequest(String)
    case decodingFailed(String)
}
```

### Handling Errors

```swift
do {
    let user = try await client.send(UserAPI.getUser(id: 123))
    print(user)
} catch NetworkError.unauthorized {
    // Handle unauthorized access
    print("Please log in")
} catch NetworkError.httpStatus(let code, let message) {
    // Handle HTTP errors
    print("HTTP \(code): \(message ?? "Unknown error")")
} catch NetworkError.decodingFailed(let message) {
    // Handle decoding errors
    print("Failed to decode: \(message)")
} catch {
    // Handle other errors
    print("Network error: \(error.localizedDescription)")
}
```

---

## Advanced Usage

### Custom Request Options

```swift
let options = RequestOptions(
    requiresAuthorization: false,
    additionalHeaders: ["X-Custom-Header": "value"],
    timeoutInterval: 30
)

let (data, response) = try await client.send(request, options: options)
```

### Custom Interceptor

```swift
struct APIVersionInterceptor: RequestInterceptor {
    let version: String
    
    func adapt(_ request: URLRequest, options: RequestOptions) async throws -> URLRequest {
        var request = request
        request.setValue(version, forHTTPHeaderField: "X-API-Version")
        return request
    }
}

let client = HTTPClient(
    requestInterceptors: [APIVersionInterceptor(version: "2.0")]
)
```

### Task Cancellation

All requests support Swift's task cancellation:

```swift
let task = Task {
    try await client.send(GetUserEndpoint(id: 123))
}

// Cancel the request
task.cancel()
```

### Organizing Endpoints

For better organization, group related endpoints in namespaces:

```swift
enum UserEndpoints {
    struct GetAll: Endpoint {
        typealias Response = [User]
        
        var baseURL: URL { URL(string: "https://api.example.com")! }
        var path: String { "/users" }
        var method: HTTPMethod { .get }
    }
    
    struct GetById: Endpoint {
        typealias Response = User
        let id: Int
        
        var baseURL: URL { URL(string: "https://api.example.com")! }
        var path: String { "/users/\(id)" }
        var method: HTTPMethod { .get }
    }
    
    struct Create: Endpoint {
        typealias Response = User
        let name: String
        let email: String
        
        var baseURL: URL { URL(string: "https://api.example.com")! }
        var path: String { "/users" }
        var method: HTTPMethod { .post }
        var body: Data? {
            try? HTTPBody.json(["name": name, "email": email]).data
        }
    }
}

// Usage
let users = try await client.send(UserEndpoints.GetAll())
let user = try await client.send(UserEndpoints.GetById(id: 123))
let newUser = try await client.send(UserEndpoints.Create(name: "John", email: "john@example.com"))
```

### Shared Base Configuration

Create a protocol to share common configuration across endpoints:

```swift
protocol APIEndpoint: Endpoint {
    var apiPath: String { get }
}

extension APIEndpoint {
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String {
        "/api/v1\(apiPath)"
    }
    
    var headers: [String: String] {
        ["X-API-Version": "1.0"]
    }
}

// Now endpoints are cleaner
struct GetUserEndpoint: APIEndpoint {
    typealias Response = User
    let id: Int
    
    var apiPath: String { "/users/\(id)" }
    var method: HTTPMethod { .get }
}

struct GetPostsEndpoint: APIEndpoint {
    typealias Response = [Post]
    
    var apiPath: String { "/posts" }
    var method: HTTPMethod { .get }
}
```

### Custom URLSession Configuration

```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30
configuration.waitsForConnectivity = true

let session = URLSession(configuration: configuration)
let client = HTTPClient(session: session)
```

---

## Examples

### Complete API Client

```swift
import HTTPClient

// MARK: - Models

struct User: Codable, Sendable {
    let id: Int
    let name: String
    let email: String
}

struct Post: Codable, Sendable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

struct CreatePostRequest: Codable, Sendable {
    let userId: Int
    let title: String
    let body: String
}

// MARK: - Endpoint Definitions

struct GetUsersEndpoint: Endpoint {
    typealias Response = [User]
    
    var baseURL: URL {
        URL(string: "https://jsonplaceholder.typicode.com")!
    }
    
    var path: String { "/users" }
    var method: HTTPMethod { .get }
}

struct GetUserEndpoint: Endpoint {
    typealias Response = User
    
    let id: Int
    
    var baseURL: URL {
        URL(string: "https://jsonplaceholder.typicode.com")!
    }
    
    var path: String { "/users/\(id)" }
    var method: HTTPMethod { .get }
}

struct GetUserPostsEndpoint: Endpoint {
    typealias Response = [Post]
    
    let userId: Int
    
    var baseURL: URL {
        URL(string: "https://jsonplaceholder.typicode.com")!
    }
    
    var path: String { "/posts" }
    var method: HTTPMethod { .get }
    
    var queryItems: [URLQueryItem] {
        [URLQueryItem(name: "userId", value: "\(userId)")]
    }
}

struct CreatePostEndpoint: Endpoint {
    typealias Response = Post
    
    let userId: Int
    let title: String
    let postBody: String
    
    var baseURL: URL {
        URL(string: "https://jsonplaceholder.typicode.com")!
    }
    
    var path: String { "/posts" }
    var method: HTTPMethod { .post }
    
    var body: Data? {
        let request = CreatePostRequest(userId: userId, title: title, body: postBody)
        return try? HTTPBody.json(request).data
    }
}

// MARK: - Client Setup

class APIClient {
    static let shared = APIClient()
    
    let client: HTTPClient
    
    private init() {
        self.client = HTTPClient(
            requestInterceptors: [
                DefaultHeadersInterceptor(),
                LoggingInterceptor()
            ],
            responseInterceptors: [
                RetryInterceptor(maxRetries: 2),
                StatusCodeInterceptor()
            ]
        )
    }
    
    // MARK: - Convenience Methods
    
    func getUsers() async throws -> [User] {
        try await client.send(GetUsersEndpoint())
    }
    
    func getUser(id: Int) async throws -> User {
        try await client.send(GetUserEndpoint(id: id))
    }
    
    func getPosts(userId: Int) async throws -> [Post] {
        try await client.send(GetUserPostsEndpoint(userId: userId))
    }
    
    func createPost(userId: Int, title: String, body: String) async throws -> Post {
        try await client.send(CreatePostEndpoint(userId: userId, title: title, postBody: body))
    }
}

// MARK: - Usage

Task {
    do {
        let users = try await APIClient.shared.getUsers()
        print("Fetched \(users.count) users")
        
        if let firstUser = users.first {
            let posts = try await APIClient.shared.getPosts(userId: firstUser.id)
            print("User \(firstUser.name) has \(posts.count) posts")
            
            // Create a new post
            let newPost = try await APIClient.shared.createPost(
                userId: firstUser.id,
                title: "My New Post",
                body: "This is the content"
            )
            print("Created post with ID: \(newPost.id)")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

### Upload Image with Multipart Form Data

```swift
func uploadProfilePhoto(_ imageData: Data, userId: Int) async throws {
    let parts = [
        try MultipartFormPart.field(name: "userId", value: "\(userId)"),
        MultipartFormPart.file(
            name: "photo",
            data: imageData,
            filename: "profile.jpg",
            mimeType: "image/jpeg"
        )
    ]
    
    let body = try HTTPBody.multipart(parts)
    
    var request = URLRequest(url: URL(string: "https://api.example.com/upload")!)
    request.httpMethod = "POST"
    request.httpBody = body.data
    request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
    
    let _ = try await client.send(request)
}
```

---

## Migration Guide

### From URLSession

**Before:**
```swift
let url = URL(string: "https://api.example.com/users")!
let (data, response) = try await URLSession.shared.data(from: url)
guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode) else {
    throw URLError(.badServerResponse)
}
let users = try JSONDecoder().decode([User].self, from: data)
```

**After:**
```swift
let client = HTTPClient(responseInterceptors: [StatusCodeInterceptor()])
let users: [User] = try await client.sendDecodable(
    URLRequest(url: URL(string: "https://api.example.com/users")!)
)
```

### From Alamofire

**Before:**
```swift
AF.request("https://api.example.com/users")
    .validate()
    .responseDecodable(of: [User].self) { response in
        switch response.result {
        case .success(let users):
            print(users)
        case .failure(let error):
            print(error)
        }
    }
```

**After:**
```swift
let client = HTTPClient(responseInterceptors: [StatusCodeInterceptor()])

Task {
    do {
        let users: [User] = try await client.sendDecodable(
            URLRequest(url: URL(string: "https://api.example.com/users")!)
        )
        print(users)
    } catch {
        print(error)
    }
}
```

---

## Best Practices

### 1. Create a Shared Client Instance

```swift
extension HTTPClient {
    static let shared = HTTPClient(
        requestInterceptors: [
            DefaultHeadersInterceptor(),
            AuthorizationInterceptor { await TokenManager.token }
        ],
        responseInterceptors: [
            LoggingInterceptor(),
            RetryInterceptor(),
            StatusCodeInterceptor()
        ]
    )
}
```

### 2. Use Struct-Based Endpoints for Type Safety

Define your API endpoints as structs (not enums) to avoid restricting all endpoints to a single response type. This gives you:
- **Type safety**: Each endpoint has its own response type
- **Flexibility**: Mix different response types in your API
- **Clarity**: No complex switch statements or wrapper types

```swift
// ✅ Good - Each endpoint has its own response type
struct GetUserEndpoint: Endpoint {
    typealias Response = User
    // ...
}

struct GetPostsEndpoint: Endpoint {
    typealias Response = [Post]  // Different type!
    // ...
}

// ❌ Avoid - Enum restricts all cases to one type
enum UserAPI: Endpoint {
    typealias Response = User  // All cases must return User
    case getUser(id: Int)
    case getPosts(userId: Int)  // Can't return [Post]!
}
```

### 3. Organize Endpoints in Namespaces

Group related endpoints for better organization:

```swift
enum UserEndpoints {
    struct GetAll: Endpoint { /* ... */ }
    struct GetById: Endpoint { /* ... */ }
    struct Create: Endpoint { /* ... */ }
    struct Update: Endpoint { /* ... */ }
    struct Delete: Endpoint { /* ... */ }
}

// Usage
let users = try await client.send(UserEndpoints.GetAll())
let user = try await client.send(UserEndpoints.GetById(id: 123))
```

### 4. Handle Errors Appropriately

Always handle specific `NetworkError` cases relevant to your use case.

### 5. Configure URLSession for Your Needs

```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30
config.requestCachePolicy = .reloadIgnoringLocalCacheData

let client = HTTPClient(session: URLSession(configuration: config))
```

### 6. Order Interceptors Carefully

Response interceptors run in order, so:
1. **LoggingInterceptor** (first - log everything)
2. **RetryInterceptor** (retry before validation)
3. **StatusCodeInterceptor** (validate last)

---

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 15.0+

---

## License

MIT License - See LICENSE file for details

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## Support

For issues, questions, or suggestions, please [open an issue](https://github.com/yourusername/HTTPClient/issues).
