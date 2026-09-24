//
//  GitHubRepoModelTests.swift
//  GitHubRepoViewerTests
//
//  Created by Holdenjing on 2026/4/19.
//

import XCTest
@testable import GitHubRepoViewer

final class GitHubRepoModelTests: XCTestCase {
    func test_decodeRepo_withAllFields_mapsCodingKeysCorrectly() throws {
        let json = """
        {
          "id": 1,
          "name": "RepoViewer",
          "description": "A demo repo",
          "stargazers_count": 1200,
          "forks_count": 88,
          "watchers_count": 77,
          "language": "Swift",
          "full_name": "octocat/RepoViewer",
          "html_url": "https://github.com/octocat/RepoViewer"
        }
        """
        
        let repo = try JSONDecoder().decode(GitHubRepoModel.self, from: Data(json.utf8))
        
        XCTAssertEqual(repo.id, 1)
        XCTAssertEqual(repo.name, "RepoViewer")
        XCTAssertEqual(repo.description, "A demo repo")
        XCTAssertEqual(repo.starCount, 1200)
        XCTAssertEqual(repo.forksCount, 88)
        XCTAssertEqual(repo.watchersCount, 77)
        XCTAssertEqual(repo.language, "Swift")
        XCTAssertEqual(repo.fullName, "octocat/RepoViewer")
        XCTAssertEqual(repo.htmlUrl, "https://github.com/octocat/RepoViewer")
    }
    
    func test_decodeRepo_withNullOptionalFields_decodesNilValues() throws {
        let json = """
        {
          "id": 2,
          "name": "NoMetaRepo",
          "description": null,
          "stargazers_count": 0,
          "forks_count": 0,
          "watchers_count": 0,
          "language": null,
          "full_name": "octocat/NoMetaRepo",
          "html_url": "https://github.com/octocat/NoMetaRepo"
        }
        """
        
        let repo = try JSONDecoder().decode(GitHubRepoModel.self, from: Data(json.utf8))
        
        XCTAssertNil(repo.description)
        XCTAssertNil(repo.language)
        XCTAssertEqual(repo.name, "NoMetaRepo")
    }
    
    func test_decodeRepo_withMissingRequiredKey_throwsKeyNotFound() {
        let json = """
        {
          "id": 3,
          "name": "BrokenRepo",
          "description": "Missing star count",
          "forks_count": 1,
          "watchers_count": 1,
          "language": "Swift",
          "full_name": "octocat/BrokenRepo",
          "html_url": "https://github.com/octocat/BrokenRepo"
        }
        """
        
        XCTAssertThrowsError(try JSONDecoder().decode(GitHubRepoModel.self, from: Data(json.utf8))) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "stargazers_count")
        }
    }
    
    func test_decodeCommit_withSha_parsesValue() throws {
        let json = #"{"sha":"abc123"}"#
        
        let commit = try JSONDecoder().decode(CommitModel.self, from: Data(json.utf8))
        
        XCTAssertEqual(commit.sha, "abc123")
    }
    
    func test_decodeCommit_withNullSha_decodesNil() throws {
        let json = #"{"sha":null}"#
        
        let commit = try JSONDecoder().decode(CommitModel.self, from: Data(json.utf8))
        
        XCTAssertNil(commit.sha)
    }
}
