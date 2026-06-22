import Foundation

// MARK: - Data Extension

private extension Data {
    /// Appends a string to the data using UTF-8 encoding.
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - HTTPBody

/// A builder for constructing HTTP request bodies in various formats.
public struct HTTPBody: Sendable {
    public let data: Data
    public let contentType: String
    
    private init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }
    
    /// Creates a JSON body from an encodable value.
    /// - Parameters:
    ///   - value: The value to encode as JSON
    ///   - encoder: The JSON encoder to use (defaults to a standard encoder)
    /// - Returns: An HTTPBody configured for JSON content
    public static func json<T: Encodable & Sendable>(
        _ value: T,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> HTTPBody {
        let data = try encoder.encode(value)
        return HTTPBody(data: data, contentType: "application/json")
    }
    
    /// Creates a URL-encoded form body from key-value pairs.
    /// - Parameter parameters: Dictionary of form field names to values
    /// - Returns: An HTTPBody configured for form-urlencoded content
    public static func urlEncoded(_ parameters: [String: String]) throws -> HTTPBody {
        var components = URLComponents()
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let query = components.query,
              let data = query.data(using: .utf8) else {
            throw NetworkError.invalidRequest("Unable to encode form parameters")
        }
        
        return HTTPBody(data: data, contentType: "application/x-www-form-urlencoded")
    }
    
    /// Creates a multipart form data body.
    /// - Parameters:
    ///   - parts: Array of multipart form parts
    ///   - boundary: Optional custom boundary string (generated if not provided)
    /// - Returns: An HTTPBody configured for multipart form data
    public static func multipart(
        _ parts: [MultipartFormPart],
        boundary: String = UUID().uuidString
    ) throws -> HTTPBody {
        var data = Data()
        
        for part in parts {
            data.appendString("--\(boundary)\r\n")
            data.appendString("Content-Disposition: form-data; name=\"\(part.name)\"")
            
            if let filename = part.filename {
                data.appendString("; filename=\"\(filename)\"")
            }
            
            data.appendString("\r\n")
            
            if let mimeType = part.mimeType {
                data.appendString("Content-Type: \(mimeType)\r\n")
            }
            
            data.appendString("\r\n")
            data.append(part.data)
            data.appendString("\r\n")
        }
        
        data.appendString("--\(boundary)--\r\n")
        
        return HTTPBody(data: data, contentType: "multipart/form-data; boundary=\(boundary)")
    }
    
    /// Creates a plain text body.
    /// - Parameters:
    ///   - text: The text content
    ///   - encoding: The string encoding to use (defaults to UTF-8)
    /// - Returns: An HTTPBody configured for plain text content
    public static func text(
        _ text: String,
        encoding: String.Encoding = .utf8
    ) throws -> HTTPBody {
        guard let data = text.data(using: encoding) else {
            throw NetworkError.invalidRequest("Unable to encode text with specified encoding")
        }
        
        return HTTPBody(data: data, contentType: "text/plain; charset=utf-8")
    }
    
    /// Creates a raw data body with a specified content type.
    /// - Parameters:
    ///   - data: The raw data
    ///   - contentType: The MIME type for the content
    /// - Returns: An HTTPBody configured with the specified content type
    public static func raw(
        _ data: Data,
        contentType: String
    ) -> HTTPBody {
        HTTPBody(data: data, contentType: contentType)
    }
}

/// Represents a single part in a multipart form data request.
public struct MultipartFormPart: Sendable {
    public let name: String
    public let data: Data
    public let filename: String?
    public let mimeType: String?
    
    public init(
        name: String,
        data: Data,
        filename: String? = nil,
        mimeType: String? = nil
    ) {
        self.name = name
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }
    
    /// Creates a text field part.
    public static func field(name: String, value: String) throws -> MultipartFormPart {
        guard let data = value.data(using: .utf8) else {
            throw NetworkError.invalidRequest("Unable to encode field value")
        }
        return MultipartFormPart(name: name, data: data)
    }
    
    /// Creates a file upload part.
    public static func file(
        name: String,
        data: Data,
        filename: String,
        mimeType: String = "application/octet-stream"
    ) -> MultipartFormPart {
        MultipartFormPart(
            name: name,
            data: data,
            filename: filename,
            mimeType: mimeType
        )
    }
}
