//
//  MockURLProtocol.swift
//  NetFlow
//
//  Created by vino on 02/10/26.
//

import Foundation

public final class MockURLProtocol: URLProtocol {

    typealias RequestHandler = (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) static var requestHandler: RequestHandler?

    override public  class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override public  class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override public  func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.resourceUnavailable)
            )
            return
        }

        do {
            let (response, data) = try handler(request)

            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )

            client?.urlProtocol(
                self,
                didLoad: data
            )

            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(
                self,
                didFailWithError: error
            )
        }
    }

    override public func stopLoading() {}
}
