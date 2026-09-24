//
//  GitHubAPIClientProtocol.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/18.
//

import Foundation

/// Transport abstraction for raw API requests; useful for mocking in tests.
protocol GitHubAPIClientProtocol {
    /// Executes a request and returns raw response data on success.
    func request(urlString: String) async -> Result<Data, GitHubError>
}
