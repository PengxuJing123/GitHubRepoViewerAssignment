//
//  GitHubAPIConfig.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/18.
//

import Foundation

enum GitHubAPIConfiguration {
    static let baseURL = "https://api.github.com/"
    // Note: hardcoded tokens should be moved to secure storage for production use.
    static let token = ""
}

enum GitHubAPIEndpoint {
    case repos(user: String)
    case commits(fullName: String)
    
    /// Builds a complete URL string for each endpoint.
    var urlString: String {
        var components = URLComponents(string: GitHubAPIConfiguration.baseURL)
        
        switch self {
        case .repos(let user):
            components?.path += "users/\(user)/repos"
        case .commits(let fullName):
            components?.path += "repos/\(fullName)/commits"
        }
        
        return components?.url?.absoluteString ?? ""
    }
}
