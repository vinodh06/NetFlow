# NetFlow

A lightweight, type-safe HTTP networking library for Swift, built with Swift Concurrency (`async/await`).

NetFlow provides a clean `Endpoint` abstraction, typed responses, request and response interceptors, request-body builders, retry support, cancellation, and URLProtocol-based HTTP mocking for tests.

## Features

* ⚡ **Swift Concurrency** — Built with `async/await`
* 🔒 **Type-safe endpoints** — Define each API endpoint with its own response type
* 🧩 **Request & response interceptors** — Add authentication, logging, retry, status-code handling, and custom behavior
* 📦 **Zero dependencies** — Built on Foundation and `URLSession`
* 📝 **Request body builders** — JSON, form URL-encoded, multipart, text, and raw data
* 🔄 **Retry support** — Configurable retry behavior with exponential backoff
* ❌ **Typed errors** — Centralized `NetworkError`
* 🛑 **Task cancellation** — Works with Swift structured concurrency
* 🧪 **URLProtocol testing** — Mock HTTP responses without making real network requests
* 🧵 **Swift 6 compatible** — Designed for strict concurrency

## Requirements

* Swift 6.3+
* iOS 15+
* macOS 12+
* tvOS 15+
* watchOS 8+

## Installation

### Swift Package Manager

Add NetFlow to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/vinodh06/NetFlow.git",
        from: "1.0.0"
    )
]
```

Then add `NetFlow` to your target dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: [
        "NetFlow"
    ]
)
```

Or add the package directly through Xcode:

**File → Add Package Dependencies...**

Then enter:

```text
https://github.com/vinodh06/NetFlow.git
```

## Quick Start

### Create a client

```swift
import NetFlow

let client = HTTPClient()
```

### Send a URLRequest

For cases where you need direct control over the request:

```swift
import NetFlow

let url = URL(string: "https://api.example.com/users/123")!

var request = URLRequest(url: url)
request.httpMethod = "GET"

let (data, response) = try await client.send(request)
```

### Decode a URLRequest response

```swift
let user: User = try await client.sendDecodable(request)
```

However, for most application code, using `Endpoint` is recommended.

---

# Endpoints

The `Endpoint` protocol provides a type-safe way to describe an API request and its expected response.

```swift
struct User: Codable, Sendable {
    let id: Int
    let name: String
    let email: String
}

struct GetUserEndpoint: Endpoint {

    typealias Response = User

    let userID: Int

    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        "/users/\(userID)"
    }

    var method: HTTPMethod {
        .get
    }
}
```

Then:

```swift
let user = try await client.send(
    GetUserEndpoint(userID: 123)
)

print(user.name)
```

The response type is inferred directly from the endpoint:

```swift
let user: User = try await client.send(
    GetUserEndpoint(userID: 123)
)
```

## Different endpoints can have different response types

```swift
struct GetUsersEndpoint: Endpoint {

    typealias Response = [User]

    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        "/users"
    }

    var method: HTTPMethod {
        .get
    }
}
```

And:

```swift
let users = try await client.send(
    GetUsersEndpoint()
)
```

Each endpoint defines its own `Response` type.

This keeps API definitions strongly typed and avoids manually passing response types around the application.

---

# Endpoint Configuration

An endpoint provides:

```swift
public protocol Endpoint: Sendable {

    associatedtype Response: Codable & Sendable

    var baseURL: URL { get }

    var path: String { get }

    var method: HTTPMethod { get }

    var headers: [String: String] { get }

    var queryItems: [URLQueryItem] { get }

    var body: Data? { get }

    var options: RequestOptions { get }

    var decoder: JSONDecoder { get }
}
```

The following properties have default implementations:

* `headers`
* `queryItems`
* `body`
* `options`
* `decoder`

So a simple GET endpoint only needs:

```swift
struct GetUserEndpoint: Endpoint {

    typealias Response = User

    let userID: Int

    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        "/users/\(userID)"
    }

    var method: HTTPMethod {
        .get
    }
}
```

---

# Query Parameters

Query parameters can be defined directly on an endpoint:

```swift
struct GetPostsEndpoint: Endpoint {

    typealias Response = [Post]

    let userID: Int

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
        [
            URLQueryItem(
                name: "userId",
                value: "\(userID)"
            )
        ]
    }
}
```

NetFlow builds the final URL automatically.

---

# Headers

Add endpoint-specific headers:

```swift
struct GetUserEndpoint: Endpoint {

    typealias Response = User

    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        "/users/123"
    }

    var method: HTTPMethod {
        .get
    }

    var headers: [String: String] {
        [
            "Accept": "application/json",
            "X-API-Version": "2"
        ]
    }
}
```

For headers that should apply to every request, use a request interceptor instead.

---

# Request Bodies

NetFlow provides `HTTPBody` for common request-body formats.

## JSON

```swift
struct CreateUserRequest: Codable, Sendable {
    let name: String
    let email: String
}

struct CreateUserEndpoint: Endpoint {

    typealias Response = User

    let request: CreateUserRequest

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
        try? HTTPBody.json(request).data
    }
}
```

Usage:

```swift
let user = try await client.send(
    CreateUserEndpoint(
        request: CreateUserRequest(
            name: "John",
            email: "john@example.com"
        )
    )
)
```

## URL-Encoded Form

```swift
let body = try HTTPBody.urlEncoded([
    "username": "john",
    "password": "secret"
])
```

## Plain Text

```swift
let body = HTTPBody.text("Hello, world!")
```

## Raw Data

```swift
let body = HTTPBody.raw(
    imageData,
    contentType: "image/jpeg"
)
```

## Multipart Form Data

```swift
let parts = [
    try MultipartFormPart.field(
        name: "title",
        value: "My Photo"
    ),

    MultipartFormPart.file(
        name: "photo",
        data: imageData,
        filename: "photo.jpg",
        mimeType: "image/jpeg"
    )
]

let body = try HTTPBody.multipart(parts)
```

---

# Custom Request Construction

Most endpoints can use the default `makeRequest()` implementation.

For more complex requests, an endpoint can override it:

```swift
struct UploadPhotoEndpoint: Endpoint {

    typealias Response = PhotoResponse

    let imageData: Data
    let caption: String

    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        "/photos/upload"
    }

    var method: HTTPMethod {
        .post
    }

    func makeRequest() throws -> URLRequest {

        let parts = [
            try MultipartFormPart.field(
                name: "caption",
                value: caption
            ),

            MultipartFormPart.file(
                name: "photo",
                data: imageData,
                filename: "photo.jpg",
                mimeType: "image/jpeg"
            )
        ]

        let body = try HTTPBody.multipart(parts)

        return try makeRequest(with: body)
    }
}
```

---

# HTTPClient

`HTTPClient` is the main entry point for networking.

```swift
let client = HTTPClient()
```

You can also provide your own `URLSession`:

```swift
let configuration = URLSessionConfiguration.default

configuration.timeoutIntervalForRequest = 30
configuration.waitsForConnectivity = true

let session = URLSession(
    configuration: configuration
)

let client = HTTPClient(
    session: session
)
```

## Available APIs

### Send a URLRequest

```swift
let (data, response) = try await client.send(request)
```

### Send and decode

```swift
let user: User = try await client.sendDecodable(request)
```

### Send an Endpoint

```swift
let user = try await client.send(
    GetUserEndpoint(userID: 123)
)
```

The endpoint-based API automatically:

1. Builds the `URLRequest`
2. Applies request interceptors
3. Executes the request
4. Processes response interceptors
5. Decodes the response using the endpoint's `Response` type

---

# Request Options

`RequestOptions` allows request-specific configuration.

```swift
let options = RequestOptions(
    requiresAuthorization: false,
    additionalHeaders: [
        "X-Custom-Header": "value"
    ],
    timeoutInterval: 30
)
```

An endpoint can provide its own options:

```swift
struct PublicEndpoint: Endpoint {

    typealias Response = User

    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        "/public/user"
    }

    var method: HTTPMethod {
        .get
    }

    var options: RequestOptions {
        RequestOptions(
            requiresAuthorization: false
        )
    }
}
```

---

# Interceptors

Interceptors provide a clean way to implement cross-cutting networking behavior.

NetFlow supports:

* Request interceptors
* Response interceptors

## Request Interceptor

A request interceptor can modify a request before it is sent.

```swift
struct APIVersionInterceptor: RequestInterceptor {

    let version: String

    func adapt(
        _ request: URLRequest,
        options: RequestOptions
    ) async throws -> URLRequest {

        var request = request

        request.setValue(
            version,
            forHTTPHeaderField: "X-API-Version"
        )

        return request
    }
}
```

Configure it:

```swift
let client = HTTPClient(
    requestInterceptors: [
        APIVersionInterceptor(version: "2")
    ]
)
```

---

# Built-in Interceptors

## DefaultHeadersInterceptor

Adds common HTTP headers and applies request configuration.

```swift
let client = HTTPClient(
    requestInterceptors: [
        DefaultHeadersInterceptor()
    ]
)
```

## AuthorizationInterceptor

Adds authorization information to requests.

```swift
let client = HTTPClient(
    requestInterceptors: [
        AuthorizationInterceptor {
            await AuthManager.shared.accessToken
        }
    ]
)
```

## StatusCodeInterceptor

Validates HTTP responses and converts unsuccessful status codes into networking errors.

```swift
let client = HTTPClient(
    responseInterceptors: [
        StatusCodeInterceptor()
    ]
)
```

## LoggingInterceptor

Logs networking activity.

```swift
let client = HTTPClient(
    responseInterceptors: [
        LoggingInterceptor()
    ]
)
```

A custom logger can also be provided when supported by the interceptor configuration.

## RetryInterceptor

Retries eligible failures using exponential backoff.

```swift
let retryInterceptor = RetryInterceptor(
    maxRetries: 3,
    retryableStatusCodes: [
        408,
        429,
        500,
        502,
        503,
        504
    ],
    baseDelay: 1.0
)

let client = HTTPClient(
    responseInterceptors: [
        retryInterceptor
    ]
)
```

A typical retry sequence with a base delay of `1.0` seconds is:

```text
1s → 2s → 4s → ...
```

Retry behavior should be chosen carefully for non-idempotent operations.

---

# Combining Interceptors

Interceptors can be composed:

```swift
let client = HTTPClient(

    requestInterceptors: [
        DefaultHeadersInterceptor(),
        AuthorizationInterceptor {
            await AuthManager.shared.accessToken
        }
    ],

    responseInterceptors: [
        LoggingInterceptor(),
        RetryInterceptor(maxRetries: 3),
        StatusCodeInterceptor()
    ]
)
```

This keeps the `HTTPClient` focused on request execution while individual concerns remain independently testable.

---

# Error Handling

NetFlow provides `NetworkError` for common networking failures.

```swift
do {

    let user = try await client.send(
        GetUserEndpoint(userID: 123)
    )

    print(user)

} catch NetworkError.unauthorized {

    print("Please log in")

} catch NetworkError.httpStatus(
    let statusCode,
    let message
) {

    print(
        "HTTP \(statusCode): \(message ?? "Unknown error")"
    )

} catch NetworkError.decodingFailed(
    let message
) {

    print(
        "Decoding failed: \(message)"
    )

} catch {

    print(
        "Network error: \(error.localizedDescription)"
    )
}
```

Common error cases include:

```swift
NetworkError.invalidResponse

NetworkError.unauthorized

NetworkError.refreshFailed

NetworkError.httpStatus(
    statusCode: Int,
    message: String?
)

NetworkError.noRefreshToken

NetworkError.invalidRequest(String)

NetworkError.decodingFailed(String)
```

---

# Task Cancellation

NetFlow uses Swift structured concurrency and supports task cancellation.

```swift
let task = Task {

    try await client.send(
        GetUserEndpoint(userID: 123)
    )
}

task.cancel()
```

This allows networking operations to participate in Swift's normal cancellation model.

---

# Testing

NetFlow supports testing the networking stack without making real HTTP requests.

The test infrastructure uses `URLProtocol` to intercept requests made by an isolated `URLSession`.

The flow is:

```text
Test
  ↓
HTTPClient
  ↓
Endpoint
  ↓
URLSession
  ↓
MockURLProtocol
  ↓
Mock HTTP Response
  ↓
HTTPClient
  ↓
Decoded Endpoint.Response
```

This means the test exercises the actual `HTTPClient` request and decoding flow instead of replacing the HTTP client itself.

## MockHTTPClient

`MockHTTPClient` provides a convenient test interface for configuring responses.

```swift
import XCTest
import NetFlow
import NetFlowTestSupport
```

Create the mock client:

```swift
let mockClient = MockHTTPClient()
```

Define an endpoint:

```swift
struct GetUserEndpoint: Endpoint {

    typealias Response = User

    let userID: Int

    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        "/users/\(userID)"
    }

    var method: HTTPMethod {
        .get
    }
}
```

Configure a response:

```swift
let expectedUser = User(
    id: 123,
    name: "Vinodh",
    email: "vinodh@example.com"
)

try mockClient.mock(
    GetUserEndpoint(userID: 123),
    response: expectedUser
)
```

Then use the real `HTTPClient`:

```swift
let user = try await mockClient.client.send(
    GetUserEndpoint(userID: 123)
)

XCTAssertEqual(user.id, 123)
XCTAssertEqual(user.name, "Vinodh")
```

## Mock HTTP Errors

HTTP errors can be simulated:

```swift
try mockClient.mockError(
    GetUserEndpoint(userID: 123),
    statusCode: 500
)
```

Then:

```swift
do {

    _ = try await mockClient.client.send(
        GetUserEndpoint(userID: 123)
    )

    XCTFail("Expected request to fail")

} catch {

    // Assert expected error
}
```

## Mock Network Errors

Network-level failures can also be simulated:

```swift
let error = URLError(
    .notConnectedToInternet
)

try mockClient.mockNetworkError(
    GetUserEndpoint(userID: 123),
    error: error
)
```

This allows tests to verify behavior for offline or connectivity failures without depending on an actual network connection.

## Reset the Mock

Reset the mock after each test:

```swift
override func tearDown() {

    mockClient.reset()
    mockClient = nil

    super.tearDown()
}
```

This prevents one test's mock configuration from affecting another test.

---

# URLProtocol Testing

`MockURLProtocol` is the Foundation-level component that intercepts requests from the test `URLSession`.

A simplified setup looks like:

```swift
let configuration =
    URLSessionConfiguration.ephemeral

configuration.protocolClasses = [
    MockURLProtocol.self
]

let session = URLSession(
    configuration: configuration
)

let client = HTTPClient(
    session: session
)
```

The important part is that the application is still using the real `HTTPClient`:

```text
                    ┌─────────────────────┐
                    │      Test Case      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │     HTTPClient      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      URLSession     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   MockURLProtocol   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Mock HTTP Data    │
                    └─────────────────────┘
```

This approach allows tests to cover:

* Endpoint request construction
* HTTP response handling
* JSON encoding and decoding
* HTTP status failures
* Network failures
* Interceptors
* Retry behavior
* Cancellation
* `HTTPClient.send(_:)`

without contacting a real API.

---

# SwiftUI Previews

The same mock networking infrastructure can also be used when `NetFlowTestSupport` is available to a preview target.

For example:

```swift
import SwiftUI
import NetFlow
import NetFlowTestSupport

#Preview {

    let mockClient = MockHTTPClient()

    let song = Song(
        id: "1",
        artistName: "Taylor Swift",
        name: "Cruel Summer",
        releaseDate: "2024-01-01",
        kind: .songs,
        artistID: "100",
        artistURL: "https://example.com/artist",
        artworkUrl100: "https://example.com/artwork.jpg",
        genres: [
            Song.Genre(
                genreID: "14",
                name: "Pop",
                url: "https://example.com/pop"
            )
        ],
        url: "https://example.com/song",
        contentAdvisoryRating: nil
    )

    let response = SongFeed(
        feed: Feed(
            songs: [song]
        )
    )

    try? mockClient.mock(
        TopSongsEndPoint(),
        response: response
    )

    // Inject mockClient.client into your view model.
    return SongListView(...)
}
```

This allows previews to display deterministic API data without depending on the live API.

---

# Organizing Endpoints

For larger applications, related endpoints can be grouped using namespaces.

```swift
enum UserEndpoints {

    struct GetAll: Endpoint {

        typealias Response = [User]

        var baseURL: URL {
            URL(string: "https://api.example.com")!
        }

        var path: String {
            "/users"
        }

        var method: HTTPMethod {
            .get
        }
    }

    struct GetByID: Endpoint {

        typealias Response = User

        let id: Int

        var baseURL: URL {
            URL(string: "https://api.example.com")!
        }

        var path: String {
            "/users/\(id)"
        }

        var method: HTTPMethod {
            .get
        }
    }

    struct Create: Endpoint {

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
            try? HTTPBody.json([
                "name": name,
                "email": email
            ]).data
        }
    }
}
```

Usage:

```swift
let users = try await client.send(
    UserEndpoints.GetAll()
)

let user = try await client.send(
    UserEndpoints.GetByID(id: 123)
)

let newUser = try await client.send(
    UserEndpoints.Create(
        name: "John",
        email: "john@example.com"
    )
)
```

---

# Shared API Configuration

Applications can define a protocol for common API configuration:

```swift
protocol APIEndpoint: Endpoint {

    var apiPath: String { get }
}
```

Then provide shared defaults:

```swift
extension APIEndpoint {

    var baseURL: URL {
        URL(
            string: "https://api.example.com"
        )!
    }

    var path: String {
        "/api/v1\(apiPath)"
    }

    var headers: [String: String] {
        [
            "X-API-Version": "1.0"
        ]
    }
}
```

Individual endpoints then become smaller:

```swift
struct GetUserEndpoint: APIEndpoint {

    typealias Response = User

    let id: Int

    var apiPath: String {
        "/users/\(id)"
    }

    var method: HTTPMethod {
        .get
    }
}
```

---

# Example API Client

A small API client can wrap the underlying `HTTPClient`:

```swift
import NetFlow

final class APIClient {

    static let shared = APIClient()

    private let client: HTTPClient

    private init() {

        client = HTTPClient(

            requestInterceptors: [
                DefaultHeadersInterceptor()
            ],

            responseInterceptors: [
                LoggingInterceptor(),
                StatusCodeInterceptor(),
                RetryInterceptor(
                    maxRetries: 2
                )
            ]
        )
    }

    func getUser(
        id: Int
    ) async throws -> User {

        try await client.send(
            GetUserEndpoint(
                userID: id
            )
        )
    }
}
```

Application code then remains simple:

```swift
let user = try await APIClient.shared.getUser(
    id: 123
)
```

---

# Architecture

NetFlow keeps responsibilities separated:

```text
┌──────────────────────────────┐
│          Application         │
│                              │
│       API / ViewModel        │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│           Endpoint           │
│                              │
│ URL + Path + Method + Body   │
│ + Response Type              │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│         HTTPClient           │
│                              │
│ Request Interceptors         │
│ URLSession                   │
│ Response Interceptors        │
│ Decoding                     │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│         URLSession           │
└──────────────────────────────┘
```

This keeps endpoint definitions independent from request execution while allowing networking behavior to be extended through interceptors.

---

# Why Endpoint-Based Networking?

Without an endpoint abstraction, application code often contains:

```swift
var request = URLRequest(...)
request.httpMethod = "GET"

let (data, _) = try await URLSession.shared.data(
    for: request
)

let user = try JSONDecoder().decode(
    User.self,
    from: data
)
```

With NetFlow:

```swift
let user = try await client.send(
    GetUserEndpoint(userID: 123)
)
```

The endpoint owns the API definition while `HTTPClient` owns the networking lifecycle.

This gives you:

* Strong response typing
* Centralized request construction
* Reusable networking behavior
* Testable API definitions
* Cleaner application code
* A consistent async/await API

---

# Design Principles

NetFlow is designed around a few simple principles:

### 1. Type safety

The endpoint declares its expected response:

```swift
typealias Response = User
```

### 2. Separation of concerns

Endpoints describe requests.

`HTTPClient` executes requests.

Interceptors handle cross-cutting behavior.

### 3. Composition

Networking behavior can be composed using interceptors rather than being hard-coded into `HTTPClient`.

### 4. Testability

The HTTP layer can be tested using `URLProtocol` without requiring real network access.

### 5. Swift Concurrency

The API is designed around `async/await` and Swift's structured concurrency model.

---

# Project Structure

A typical NetFlow package is organized as:

```text
NetFlow/
│
├── Package.swift
│
├── Sources/
│   └── NetFlow/
│       ├── HTTPClient.swift
│       ├── Endpoint.swift
│       ├── HTTPBody.swift
│       ├── HTTPMethod.swift
│       ├── NetworkError.swift
│       ├── RequestOptions.swift
│       └── ...
│
└── Tests/
    └── NetFlowTests/
        ├── HTTPClientTests.swift
        ├── MockHTTPClient.swift
        ├── MockURLProtocol.swift
        └── ...
```

If the test support is exposed as a separate reusable module, it can be organized as:

```text
Sources/
├── NetFlow/
│
└── NetFlowTestSupport/
    ├── MockHTTPClient.swift
    └── MockURLProtocol.swift
```

---

# Migration from URLSession

If your existing code uses:

```swift
let (data, response) = try await URLSession.shared.data(
    for: request
)
```

you can introduce NetFlow incrementally.

Start by defining an endpoint:

```swift
struct GetUserEndpoint: Endpoint {

    typealias Response = User

    let id: Int

    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        "/users/\(id)"
    }

    var method: HTTPMethod {
        .get
    }
}
```

Then replace the networking call:

```swift
let user = try await client.send(
    GetUserEndpoint(id: 123)
)
```

You can then add interceptors for authentication, logging, retries, and status-code handling as the application grows.

---

# Concurrency

NetFlow is built for Swift's concurrency model.

The main HTTP client is `Sendable`:

```swift
public final class HTTPClient: Sendable
```

Endpoints are also `Sendable`:

```swift
public protocol Endpoint: Sendable
```

Endpoint responses are required to conform to:

```swift
Codable & Sendable
```

This allows NetFlow to work naturally with modern Swift concurrency and Swift 6 strict concurrency checking.

---

# License

NetFlow is open source.

See the repository for the current license and contribution information.

## Repository

GitHub:

https://github.com/vinodh06/NetFlow
