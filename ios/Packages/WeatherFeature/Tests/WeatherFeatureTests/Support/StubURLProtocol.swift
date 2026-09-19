import Foundation
import os

struct StubResponse: Sendable {
    var statusCode: Int = 200
    var body: Data = Data()
    var error: URLError.Code? = nil
}

enum StubNetwork {
    static func session(respond: @escaping @Sendable (URLRequest) -> StubResponse) -> URLSession {
        let key = StubResponders.shared.register(respond)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [StubURLProtocol.keyHeader: key]
        return URLSession(configuration: configuration)
    }

    static func fixture(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

private final class StubResponders: Sendable {
    static let shared = StubResponders()

    private let table = OSAllocatedUnfairLock(initialState: [String: @Sendable (URLRequest) -> StubResponse]())

    func register(_ respond: @escaping @Sendable (URLRequest) -> StubResponse) -> String {
        let key = UUID().uuidString
        table.withLock { $0[key] = respond }
        return key
    }

    func responder(for key: String) -> (@Sendable (URLRequest) -> StubResponse)? {
        table.withLock { $0[key] }
    }
}

final class StubURLProtocol: URLProtocol {
    static let keyHeader = "X-Stub-Key"

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: keyHeader) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard
            let key = request.value(forHTTPHeaderField: Self.keyHeader),
            let respond = StubResponders.shared.responder(for: key)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let stub = respond(request)

        if let code = stub.error {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }

        guard let url = request.url, let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
