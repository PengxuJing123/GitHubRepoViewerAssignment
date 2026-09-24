//
//  GitHubAPIClientNetworkTests.swift
//  GitHubRepoViewerTests
//
//  Created by Holdenjing on 2026/4/19.
//
import XCTest
@testable import GitHubRepoViewer

final class GitHubAPIClientNetworkTests: XCTestCase {
    private let client = GitHubAPIClient.shared
    
    override class func setUp() {
        super.setUp()
        URLProtocol.registerClass(URLProtocolStub.self)
    }
    
    override class func tearDown() {
        URLProtocol.unregisterClass(URLProtocolStub.self)
        super.tearDown()
    }
    
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }
    
    func test_request_withInvalidURL_returnsInvalidURL() async {
        let result = await client.request(urlString: "")
        
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure(.invalidURL), got success")
        }
        
        guard case .invalidURL = error else {
            return XCTFail("Expected .invalidURL, got \(error)")
        }
    }
    
    func test_request_with2xx_returnsData() async throws {
        let expectedData = Data(#"{"ok":true}"#.utf8)
        let token = await GitHubAPIConfiguration.token
        
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token \(token)")
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, expectedData)
        }
        
        let result = await client.request(urlString: "https://api.github.com/users/demo/repos")
        
        guard case .success(let data) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(data, expectedData)
    }
    
    func test_request_withNon2xx_returnsInvalidResponse() async throws {
        let body = Data(#"{"message":"Not Found"}"#.utf8)
        let urlString = "https://api.github.com/users/demo/repos"
        
        URLProtocolStub.handler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, body)
        }
        
        let result = await client.request(urlString: urlString)
        
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure(.invalidResponse), got success")
        }
        
        guard case .invalidResponse(let url, let code, let data) = error else {
            return XCTFail("Expected .invalidResponse, got \(error)")
        }
        
        XCTAssertEqual(url, urlString)
        XCTAssertEqual(code, 404)
        XCTAssertEqual(data, body)
    }
    
    func test_request_whenNetworkFails_returnsNetworkError() async {
        let expected = URLError(.notConnectedToInternet)
        
        URLProtocolStub.handler = { _ in
            throw expected
        }
        
        let result = await client.request(urlString: "https://api.github.com/users/demo/repos")
        
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure(.networkError), got success")
        }
        
        guard case .networkError(let underlying) = error else {
            return XCTFail("Expected .networkError, got \(error)")
        }
        
        XCTAssertEqual((underlying as NSError).domain, NSURLErrorDomain)
        XCTAssertEqual((underlying as NSError).code, expected.errorCode)
    }
}

/// URLProtocol stub that intercepts URLSession traffic for deterministic network tests.
private final class URLProtocolStub: URLProtocol {
    /// Test-provided request handler that returns a mocked response payload.
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    /// Intercept all requests in this test target.
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    /// Keep request unchanged.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            // Forward mocked failure back into URLSession's error path.
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}
