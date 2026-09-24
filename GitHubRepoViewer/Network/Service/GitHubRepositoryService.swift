//
//  GitHubRepositoryService.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/16.
//

import Foundation

final class GitHubRepositoryService: GitHubRepositoryProtocol {
    static let shared = GitHubRepositoryService()
    static let defaultUserName = "mralexgray"
    
    // Enforces singleton usage and prevents external initialization.
    private init() {}
    
    private let client: GitHubAPIClientProtocol = GitHubAPIClient.shared
    
    func fetchRepos(user: String) async -> Result<[GitHubRepoModel], GitHubError> {
        Logger.info("Fetching repositories for user: \(user)")
        let url = GitHubAPIEndpoint.repos(user: user).urlString
        let result = await client.request(urlString: url)
        
        switch result {
        case .success(let data):
            do {
                let repos = try JSONDecoder().decode([GitHubRepoModel].self, from: data)
                Logger.info("Fetched \(repos.count) repositories for user: \(user)")
                return .success(repos)
            } catch {
                Logger.error("Failed to decode repositories for user \(user): \(error)")
                return .failure(.decodingFailed(error))
            }
        case .failure(let error):
            Logger.warning("Repository fetch failed for user \(user): \(error)")
            return .failure(error)
        }
    }
    
    func fetchLastCommit(fullName: String) async -> Result<CommitModel?, GitHubError> {
        Logger.debug("Fetching latest commit for repository: \(fullName)")
        let url = GitHubAPIEndpoint.commits(fullName: fullName).urlString
        let result = await client.request(urlString: url)
        
        switch result {
        case .success(let data):
            do {
                let commits = try JSONDecoder().decode([CommitModel].self, from: data)
                
                // API returns a list ordered newest-first; UI only needs the latest item.
                let latestCommit = commits.first
                Logger.debug("Latest commit fetched for \(fullName): \(latestCommit?.sha ?? "none")")
                return .success(latestCommit)
            } catch {
                Logger.error("Failed to decode commits for \(fullName): \(error)")
                return .failure(.decodingFailed(error))
            }
        case .failure(let error):
            Logger.warning("Commit fetch failed for \(fullName): \(error)")
            return .failure(error)
        }
    }
}
