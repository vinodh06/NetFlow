//
//  MockHTTPClient.swift
//  NetFlow
//
//  Created by vino on 02/10/26.
//


import Foundation
@testable import NetFlow

public final class MockHTTPClient {

    public let client: HTTPClient

    public init() {
        let configuration = URLSessionConfiguration.ephemeral

        configuration.protocolClasses = [
            MockURLProtocol.self
        ]

        let session = URLSession(configuration: configuration)

        client = HTTPClient(session: session)
    }

    // MARK: - Success

    public func mock<E: Endpoint>(
        _ endpoint: E,
        response: E.Response
    ) throws {

        let data = try JSONEncoder().encode(response)

        MockURLProtocol.requestHandler = { request in

            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json"
                ]
            )!

            return (
                httpResponse,
                data
            )
        }
    }

    // MARK: - HTTP Error

    public func mockError<E: Endpoint>(
        _ endpoint: E,
        statusCode: Int,
        data: Data = Data()
    ) {

        MockURLProtocol.requestHandler = { request in

            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!

            return (
                httpResponse,
                data
            )
        }
    }

    // MARK: - Network Error

    public func mockNetworkError<E: Endpoint>(
        _ endpoint: E,
        error: Error
    ) {

        MockURLProtocol.requestHandler = { _ in
            throw error
        }
    }

    // MARK: - Reset

    public func reset() {
        MockURLProtocol.requestHandler = nil
    }
}
