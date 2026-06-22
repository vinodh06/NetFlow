# Advanced Endpoint Patterns

This document shows advanced patterns for organizing and using struct-based endpoints.

## Table of Contents
- [Basic Struct Endpoints](#basic-struct-endpoints)
- [Namespace Organization](#namespace-organization)
- [Shared Configuration with Protocols](#shared-configuration-with-protocols)
- [Generic Endpoints](#generic-endpoints)
- [Paginated Endpoints](#paginated-endpoints)
- [File Upload Endpoints](#file-upload-endpoints)

---

## Basic Struct Endpoints

The simplest pattern - each endpoint is its own struct with its own response type:

```swift
struct GetUserEndpoint: Endpoint {
    typealias Response = User
    
    let userId: Int
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String { "/users/\(userId)" }
    var method: HTTPMethod { .get }
}

struct CreateUserEndpoint: Endpoint {
    typealias Response = User
    
    let name: String
    let email: String
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String { "/users" }
    var method: HTTPMethod { .post }
    var body: Data? {
        try? HTTPBody.json(["name": name, "email": email]).data
    }
}

// Usage
let user = try await client.send(GetUserEndpoint(userId: 123))
let newUser = try await client.send(CreateUserEndpoint(name: "John", email: "john@example.com"))
```

---

## Namespace Organization

Organize related endpoints in namespaces using enums:

```swift
enum Users {
    struct GetAll: Endpoint {
        typealias Response = [User]
        
        var baseURL: URL { Config.apiBaseURL }
        var path: String { "/users" }
        var method: HTTPMethod { .get }
    }
    
    struct GetById: Endpoint {
        typealias Response = User
        let id: Int
        
        var baseURL: URL { Config.apiBaseURL }
        var path: String { "/users/\(id)" }
        var method: HTTPMethod { .get }
    }
    
    struct Create: Endpoint {
        typealias Response = User
        let name: String
        let email: String
        
        var baseURL: URL { Config.apiBaseURL }
        var path: String { "/users" }
        var method: HTTPMethod { .post }
        var body: Data? {
            try? HTTPBody.json(["name": name, "email": email]).data
        }
    }
    
    struct Update: Endpoint {
        typealias Response = User
        let id: Int
        let name: String
        let email: String
        
        var baseURL: URL { Config.apiBaseURL }
        var path: String { "/users/\(id)" }
        var method: HTTPMethod { .put }
        var body: Data? {
            try? HTTPBody.json(["name": name, "email": email]).data
        }
    }
    
    struct Delete: Endpoint {
        typealias Response = EmptyResponse
        let id: Int
        
        var baseURL: URL { Config.apiBaseURL }
        var path: String { "/users/\(id)" }
        var method: HTTPMethod { .delete }
    }
}

// Usage - clean and organized!
let users = try await client.send(Users.GetAll())
let user = try await client.send(Users.GetById(id: 123))
let newUser = try await client.send(Users.Create(name: "John", email: "john@example.com"))
try await client.send(Users.Delete(id: 123))
```

---

## Shared Configuration with Protocols

Create a base protocol to share common configuration:

```swift
// Base protocol for all API endpoints
protocol APIEndpoint: Endpoint {
    var apiPath: String { get }
}

extension APIEndpoint {
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String {
        "/api/v2\(apiPath)"
    }
    
    var headers: [String: String] {
        ["X-API-Version": "2.0"]
    }
}

// Now endpoints are much cleaner
struct GetUserEndpoint: APIEndpoint {
    typealias Response = User
    let userId: Int
    
    var apiPath: String { "/users/\(userId)" }
    var method: HTTPMethod { .get }
}

struct GetPostsEndpoint: APIEndpoint {
    typealias Response = [Post]
    
    var apiPath: String { "/posts" }
    var method: HTTPMethod { .get }
}

// For authenticated endpoints
protocol AuthenticatedEndpoint: APIEndpoint {}

extension AuthenticatedEndpoint {
    var options: RequestOptions {
        RequestOptions(requiresAuthorization: true)
    }
}

struct GetProfileEndpoint: AuthenticatedEndpoint {
    typealias Response = UserProfile
    
    var apiPath: String { "/profile" }
    var method: HTTPMethod { .get }
}

// For public endpoints
protocol PublicEndpoint: APIEndpoint {}

extension PublicEndpoint {
    var options: RequestOptions {
        RequestOptions(requiresAuthorization: false)
    }
}

struct LoginEndpoint: PublicEndpoint {
    typealias Response = AuthToken
    let username: String
    let password: String
    
    var apiPath: String { "/auth/login" }
    var method: HTTPMethod { .post }
    var body: Data? {
        try? HTTPBody.json(["username": username, "password": password]).data
    }
}
```

---

## Generic Endpoints

Create reusable endpoint patterns:

```swift
// Generic list endpoint
struct ListEndpoint<T: Decodable & Sendable>: Endpoint {
    typealias Response = [T]
    
    let resource: String
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String { "/\(resource)" }
    var method: HTTPMethod { .get }
}

// Generic get by ID endpoint
struct GetByIdEndpoint<T: Decodable & Sendable>: Endpoint {
    typealias Response = T
    
    let resource: String
    let id: Int
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String { "/\(resource)/\(id)" }
    var method: HTTPMethod { .get }
}

// Usage
let users: [User] = try await client.send(ListEndpoint<User>(resource: "users"))
let user: User = try await client.send(GetByIdEndpoint<User>(resource: "users", id: 123))
let posts: [Post] = try await client.send(ListEndpoint<Post>(resource: "posts"))
```

---

## Paginated Endpoints

Handle pagination elegantly:

```swift
struct PaginatedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: [T]
    let page: Int
    let totalPages: Int
    let totalItems: Int
}

struct GetPaginatedEndpoint<T: Decodable & Sendable>: Endpoint {
    typealias Response = PaginatedResponse<T>
    
    let resource: String
    let page: Int
    let pageSize: Int
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String { "/\(resource)" }
    var method: HTTPMethod { .get }
    
    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "pageSize", value: "\(pageSize)")
        ]
    }
}

// Usage
let response = try await client.send(
    GetPaginatedEndpoint<User>(resource: "users", page: 1, pageSize: 20)
)
print("Fetched \(response.data.count) users")
print("Page \(response.page) of \(response.totalPages)")

// Fetch all pages
func fetchAllUsers() async throws -> [User] {
    var allUsers: [User] = []
    var currentPage = 1
    
    while true {
        let response = try await client.send(
            GetPaginatedEndpoint<User>(resource: "users", page: currentPage, pageSize: 100)
        )
        allUsers.append(contentsOf: response.data)
        
        if currentPage >= response.totalPages {
            break
        }
        currentPage += 1
    }
    
    return allUsers
}
```

---

## File Upload Endpoints

Handle file uploads with multipart form data:

```swift
struct UploadImageEndpoint: Endpoint {
    typealias Response = UploadedImage
    
    let imageData: Data
    let filename: String
    let caption: String?
    let tags: [String]
    
    var baseURL: URL {
        URL(string: "https://api.example.com")!
    }
    
    var path: String { "/images/upload" }
    var method: HTTPMethod { .post }
    
    func makeRequest() throws -> URLRequest {
        var parts = [MultipartFormPart]()
        
        // Add image file
        parts.append(
            MultipartFormPart.file(
                name: "image",
                data: imageData,
                filename: filename,
                mimeType: mimeType(for: filename)
            )
        )
        
        // Add optional caption
        if let caption = caption {
            parts.append(try MultipartFormPart.field(name: "caption", value: caption))
        }
        
        // Add tags as JSON
        if !tags.isEmpty {
            let tagsJSON = try JSONEncoder().encode(tags)
            parts.append(MultipartFormPart(name: "tags", data: tagsJSON))
        }
        
        let body = try HTTPBody.multipart(parts)
        return try makeRequest(with: body)
    }
    
    private func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        default: return "application/octet-stream"
        }
    }
}

// Usage
let image = try await client.send(
    UploadImageEndpoint(
        imageData: imageData,
        filename: "vacation.jpg",
        caption: "Summer vacation 2024",
        tags: ["travel", "beach", "summer"]
    )
)
print("Uploaded image ID: \(image.id)")
```

---

## Complete Real-World Example

Putting it all together:

```swift
// MARK: - Configuration

enum Config {
    static let apiBaseURL = URL(string: "https://api.myapp.com")!
}

// MARK: - Base Protocols

protocol APIEndpoint: Endpoint {
    var apiPath: String { get }
}

extension APIEndpoint {
    var baseURL: URL { Config.apiBaseURL }
    var path: String { "/api/v1\(apiPath)" }
}

protocol AuthenticatedEndpoint: APIEndpoint {}

extension AuthenticatedEndpoint {
    var options: RequestOptions {
        RequestOptions(requiresAuthorization: true)
    }
}

// MARK: - Models

struct User: Codable, Sendable {
    let id: Int
    let username: String
    let email: String
}

struct Post: Codable, Sendable {
    let id: Int
    let userId: Int
    let title: String
    let content: String
}

struct AuthToken: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
}

struct EmptyResponse: Codable, Sendable {}

// MARK: - Endpoints

enum Auth {
    struct Login: APIEndpoint {
        typealias Response = AuthToken
        let username: String
        let password: String
        
        var apiPath: String { "/auth/login" }
        var method: HTTPMethod { .post }
        var options: RequestOptions {
            RequestOptions(requiresAuthorization: false)
        }
        var body: Data? {
            try? HTTPBody.json(["username": username, "password": password]).data
        }
    }
    
    struct Logout: AuthenticatedEndpoint {
        typealias Response = EmptyResponse
        
        var apiPath: String { "/auth/logout" }
        var method: HTTPMethod { .post }
    }
}

enum Users {
    struct GetProfile: AuthenticatedEndpoint {
        typealias Response = User
        
        var apiPath: String { "/users/me" }
        var method: HTTPMethod { .get }
    }
    
    struct UpdateProfile: AuthenticatedEndpoint {
        typealias Response = User
        let username: String
        let email: String
        
        var apiPath: String { "/users/me" }
        var method: HTTPMethod { .put }
        var body: Data? {
            try? HTTPBody.json(["username": username, "email": email]).data
        }
    }
}

enum Posts {
    struct GetAll: AuthenticatedEndpoint {
        typealias Response = [Post]
        
        var apiPath: String { "/posts" }
        var method: HTTPMethod { .get }
    }
    
    struct GetById: AuthenticatedEndpoint {
        typealias Response = Post
        let id: Int
        
        var apiPath: String { "/posts/\(id)" }
        var method: HTTPMethod { .get }
    }
    
    struct Create: AuthenticatedEndpoint {
        typealias Response = Post
        let title: String
        let content: String
        
        var apiPath: String { "/posts" }
        var method: HTTPMethod { .post }
        var body: Data? {
            try? HTTPBody.json(["title": title, "content": content]).data
        }
    }
}

// MARK: - Usage

class APIService {
    let client: HTTPClient
    
    init() {
        self.client = HTTPClient(
            requestInterceptors: [
                DefaultHeadersInterceptor(),
                AuthorizationInterceptor { await TokenManager.shared.accessToken }
            ],
            responseInterceptors: [
                LoggingInterceptor(),
                RetryInterceptor(maxRetries: 2),
                StatusCodeInterceptor()
            ]
        )
    }
    
    func login(username: String, password: String) async throws -> AuthToken {
        try await client.send(Auth.Login(username: username, password: password))
    }
    
    func getProfile() async throws -> User {
        try await client.send(Users.GetProfile())
    }
    
    func updateProfile(username: String, email: String) async throws -> User {
        try await client.send(Users.UpdateProfile(username: username, email: email))
    }
    
    func getPosts() async throws -> [Post] {
        try await client.send(Posts.GetAll())
    }
    
    func createPost(title: String, content: String) async throws -> Post {
        try await client.send(Posts.Create(title: title, content: content))
    }
}
```

---

## Summary

**Key Benefits of Struct-Based Endpoints:**

1. ✅ **Type Safety**: Each endpoint has its own response type
2. ✅ **Flexibility**: Mix different response types in your API
3. ✅ **Organization**: Easy to group in namespaces
4. ✅ **Reusability**: Share configuration through protocols
5. ✅ **Testability**: Each endpoint is a discrete, testable unit
6. ✅ **Clarity**: No complex switch statements or type erasure

**When to Use Each Pattern:**

- **Basic Structs**: Small APIs or getting started
- **Namespaces**: Medium to large APIs with many endpoints
- **Protocol Hierarchies**: APIs with common configuration (base URLs, headers, auth)
- **Generics**: RESTful APIs with predictable patterns
- **Custom `makeRequest()`**: Complex body construction (multipart, custom encoding)
