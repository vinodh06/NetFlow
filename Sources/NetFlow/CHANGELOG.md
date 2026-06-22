# Changelog

## Version 1.0.0 - Library Improvements

### Documentation Philosophy

**Struct-Based Endpoints**: This library now recommends using **structs** instead of enums for endpoint definitions. This approach provides:
- ✅ Each endpoint can have its own unique response type
- ✅ No need for complex type erasure or wrapper types
- ✅ Better type safety and compiler support
- ✅ Cleaner, more maintainable code

See [ENDPOINT_PATTERNS.md](ENDPOINT_PATTERNS.md) for comprehensive examples and patterns.

### Breaking Changes

- **NetworkError.httpStatus**: Changed from `httpStatus(Int, Data)` to `httpStatus(statusCode: Int, message: String? = nil)` for better usability and proper Equatable conformance
- **Availability**: Added `@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)` to `HTTPClient` due to use of `URLSession.data(for:)` API

### New Features

#### New Interceptors
- **LoggingInterceptor**: Implements both `RequestInterceptor` and `ResponseInterceptor` for comprehensive logging
- **RetryInterceptor**: Automatic retry with exponential backoff for transient failures
  - Configurable max retries (default: 3)
  - Configurable retryable status codes (default: 408, 429, 500, 502, 503, 504)
  - Exponential backoff strategy
  - Handles both HTTP errors and network errors

#### Enhanced HTTPMethod
- Added `head` and `options` HTTP methods

#### Endpoint Protocol Enhancement
- New `makeRequest(with httpBody: HTTPBody)` method for easier HTTPBody integration
- Automatically sets Content-Type header from HTTPBody

### Improvements

#### Documentation
- Added comprehensive DocC documentation to all public APIs
- Created detailed README.md with:
  - Quick start guide
  - Core concepts explanation
  - Built-in interceptors documentation
  - Error handling guide
  - Advanced usage examples
  - Migration guide from URLSession and Alamofire
  - Best practices

#### Code Quality
- Removed `@unchecked Sendable` from HTTPClient (now properly `Sendable`)
- Fixed weak self capture to use `unowned self` in retry closure (no retain cycle possible)
- Removed force unwraps in multipart form builder
- Added private `Data.appendString(_:)` helper for safer string appending
- Improved error messages throughout

#### HTTPBody Builder
- Removed all force unwraps (`!`) in multipart form data construction
- Safer string-to-data conversion using helper method

#### NetworkError
- Better error descriptions for all cases
- Improved Equatable implementation
- Optional message extraction from HTTP error responses

#### StatusCodeInterceptor
- Now extracts error messages from response bodies
- Passes messages to `NetworkError.httpStatus`

### Documentation Updates

#### HTTPClient
- Added class-level documentation with examples
- Added parameter documentation for all public methods
- Added cancellation documentation

#### Interceptor Protocols
- Comprehensive protocol documentation
- Usage examples for both RequestInterceptor and ResponseInterceptor

#### RequestOptions
- Full documentation for all properties
- Usage examples

#### Endpoint Protocol
- Added detailed protocol documentation
- Included complete usage example in doc comments

### Files Added

1. **LoggingInterceptor.swift** - Logging interceptor implementation
2. **RetryInterceptor.swift** - Automatic retry with exponential backoff
3. **README.md** - Comprehensive library documentation
4. **CHANGELOG.md** - This file

### Files Modified

1. **HTTPClient.swift** - Added documentation and availability annotations
2. **NetworkError.swift** - Improved error types and descriptions
3. **HTTPMethod.swift** - Added HEAD and OPTIONS methods
4. **RequestBodyBuilder.swift** - Removed force unwraps, added Data extension
5. **Endpoint.swift** - Added documentation and HTTPBody integration
6. **StatusCodeInterceptor.swift** - Added error message extraction
7. **RequestOptions.swift** - Added comprehensive documentation
8. **RequestInterceptor.swift** - Added documentation
9. **ResponseInterceptor.swift** - Added documentation

### Testing Recommendations

The following areas should have test coverage:

1. HTTPBody builders (JSON, URL-encoded, multipart, text, raw)
2. RetryInterceptor exponential backoff logic
3. LoggingInterceptor output
4. NetworkError equality and error descriptions
5. Endpoint makeRequest methods
6. HTTPClient request/response flow with various interceptors

### Migration Notes

If you're upgrading from a previous version:

1. Update any references to `NetworkError.httpStatus`:
   ```swift
   // Old:
   case .httpStatus(let code, let data)
   
   // New:
   case .httpStatus(let code, let message)
   ```

2. Ensure your minimum deployment targets are:
   - iOS 15.0+
   - macOS 12.0+
   - tvOS 15.0+
   - watchOS 8.0+

3. Consider adding the new interceptors to your client configuration:
   ```swift
   let client = HTTPClient(
       requestInterceptors: [
           DefaultHeadersInterceptor(),
           AuthorizationInterceptor(...)
       ],
       responseInterceptors: [
           LoggingInterceptor(),       // New!
           RetryInterceptor(),         // New!
           StatusCodeInterceptor()
       ]
   )
   ```
