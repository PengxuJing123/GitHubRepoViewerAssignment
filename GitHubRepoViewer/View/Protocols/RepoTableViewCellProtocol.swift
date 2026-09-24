//
//  RepoTableViewCellProtocol.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/18.
//
import Foundation

/// Delegate contract for actions triggered from a repository cell.
protocol RepoTableViewCellProtocol: AnyObject {
    /// Called when the user taps the GitHub link in a cell.
    /// - Parameters:
    ///   - cell: The cell that triggered the action.
    ///   - url: The repository HTML URL to open.
    func repoTableViewCell(
        _ cell: RepoTableViewCell,
        didTapHTMLLink url: URL
    )
    
    /// Called when the user taps the latest commit value in a cell.
    /// - Parameters:
    ///   - cell: The cell that triggered the action.
    ///   - fullSHA: The full commit SHA string.
    func repoTableViewCell(
        _ cell: RepoTableViewCell,
        didTapCommit fullSHA: String
    )
}
