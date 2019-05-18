//
//  TestHelpers.swift
//  OpenEmuShadersTests
//
//  Created by Stuart Carnie on 5/15/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

import Foundation

class TestSetup: NSObject {
    override init() {
        URLProtocol.registerClass(InMemProtocol.self)
    }
}

class InMemProtocol: URLProtocol {
    enum InMemProtocolError: Error {
        case urlNotFound(URL)
        case missingURL
    }
    
    static var requests: [String: String] = [:]
    
    override class func canonicalRequest(for req: URLRequest) -> URLRequest {
        return req
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == "mem"
    }
    
    override func startLoading() {
        guard let url = self.request.url else {
            self.client!.urlProtocol(self, didFailWithError: InMemProtocolError.missingURL)
            return
        }
        
        if let s = InMemProtocol.requests[url.absoluteString] {
            let data = s.data(using: .utf8)!
            let res = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: data.count, textEncodingName: nil)
            self.client!.urlProtocol(self, didReceive: res, cacheStoragePolicy: .allowedInMemoryOnly)
            self.client!.urlProtocol(self, didLoad: s.data(using: .utf8)!)
            self.client!.urlProtocolDidFinishLoading(self)
        } else {
            self.client!.urlProtocol(self, didFailWithError: InMemProtocolError.urlNotFound(url))
        }
    }
    
    override func stopLoading() {
    }
}

