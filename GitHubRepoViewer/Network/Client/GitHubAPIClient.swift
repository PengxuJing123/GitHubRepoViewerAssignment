//
//  GitHubAPIClient.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/18.
//

import Foundation

final class GitHubAPIClient: GitHubAPIClientProtocol {
    static let shared = GitHubAPIClient()
    // Fallback code used when URLSession response is not HTTPURLResponse.
    private let kNonHTTPStatusCode = -1
    
    private init() {}
    
    func request(urlString: String) async -> Result<Data, GitHubError> {
        Logger.debug("HTTP request started: \(urlString)")
        guard let url = URL(string: urlString) else {
            Logger.warning("Request aborted due to invalid URL: \(urlString)")
            return .failure(.invalidURL)
        }
        
        var request = URLRequest(url: url)
        // GitHub PAT authentication for API requests.
        request.setValue("token \(GitHubAPIConfiguration.token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.warning("Non-HTTP response for URL: \(urlString)")
                return .failure(
                    .invalidResponse(
                        url: urlString,
                        statusCode: kNonHTTPStatusCode,
                        data: Data()
                    )
                )
            }
            
            // Treat only 2xx responses as success.
            guard (200...299).contains(httpResponse.statusCode) else {
                Logger.warning("HTTP request failed with status \(httpResponse.statusCode) for URL: \(urlString)")
                return .failure(
                    .invalidResponse(
                        url: urlString,
                        statusCode: httpResponse.statusCode,
                        data: data
                    )
                )
            }
            Logger.debug("HTTP request succeeded: status=\(httpResponse.statusCode), bytes=\(data.count), URL=\(urlString)")
            return .success(data)
        } catch {
            Logger.error("Network request error for URL \(urlString): \(error)")
            return .failure(.networkError(error))
        }
    }
}
