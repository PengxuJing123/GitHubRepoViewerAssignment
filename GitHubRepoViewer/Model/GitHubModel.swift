//
//  GitHubModel.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/16.
//

import Foundation

/// Repository payload used by list APIs and table rendering.
nonisolated struct GitHubRepoModel: Codable {
    let id: Int
    let name: String
    let description: String?
    let starCount: Int
    let forksCount: Int
    let watchersCount: Int
    let language: String?
    let fullName: String
    let htmlUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case starCount = "stargazers_count"
        case forksCount = "forks_count"
        case watchersCount = "watchers_count"
        case language
        case fullName = "full_name"
        case htmlUrl = "html_url"
    }
}

/// Minimal commit payload; only SHA is needed by the current UI.
nonisolated struct CommitModel: Codable {
    let sha: String?
}
