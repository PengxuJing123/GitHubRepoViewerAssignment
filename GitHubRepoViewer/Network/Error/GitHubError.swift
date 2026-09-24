//
//  GitHubError.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/18.
//

import Foundation

/// Domain-specific error type used across networking and decoding layers.
enum GitHubError: Error {
    /// URL construction failed before making a request.
    case invalidURL
    /// Non-success HTTP response or non-HTTP response mapped with a synthetic code.
    case invalidResponse(url: String, statusCode: Int, data: Data?)
    /// JSON decoding failed for a successful HTTP response payload.
    case decodingFailed(Error)
    /// Transport-layer failure from URLSession.
    case networkError(Error)

    /// Human-readable summary for logging/debug output.
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .invalidResponse(let url, let code, _):
            "Invalid Response | URL: \(url) | status code: \(code)"
        case .decodingFailed(let error):
            "Decoding Failed: \(error.localizedDescription)"
        case .networkError(let error):
            "Network Error: \(error.localizedDescription)"
        }
    }
}
