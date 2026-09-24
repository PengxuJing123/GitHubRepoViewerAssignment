//
//  GitHubRepositoryProtocol.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/18.
//

import Foundation

/// Repository abstraction that exposes app-level GitHub data operations.
protocol GitHubRepositoryProtocol {
    /// Fetches repositories for a GitHub user.
    func fetchRepos(user: String) async -> Result<[GitHubRepoModel], GitHubError>

    /// Fetches the latest commit for a repository full name (e.g. "owner/repo").
    /// Returns `nil` on success when the commits list is empty.
    func fetchLastCommit(fullName: String) async -> Result<CommitModel?, GitHubError>
}
