// Copyright (c) 2019, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
            let res  = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: data.count, textEncodingName: nil)
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

