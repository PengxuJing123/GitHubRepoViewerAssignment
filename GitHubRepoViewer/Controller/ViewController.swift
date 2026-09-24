//
//  ViewController.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/16.
//

import UIKit
import SafariServices

final class ViewController: UIViewController {
    // Maximum number of concurrent commit requests to avoid GitHub API rate-limiting.
    private static let maxConcurrentRequests = 1
    private var repos: [GitHubRepoModel] = []
    // Maps repo id -> latest commit SHA. Empty string means "loaded but unavailable."
    private var commitDict: [Int: String] = [:]
    private var isLoadingRepos = true
    // 3 skeleton rows for optimal screen fit & better user experience.
    private let skeletonRowsCount = 3
    private let cellEstimatedHeight: CGFloat = 330
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.info("ViewController loaded")
        configureViewController()
        fetchGitHubRepositories()
    }
    
    private func configureViewController() {
        title = "GitHub Repo View"
        view.backgroundColor = .systemGroupedBackground
        configureTableView()
    }
    
    private func configureTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.register(
            RepoTableViewCell.self,
            forCellReuseIdentifier: RepoTableViewCell.reuseIdentifier
        )
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = cellEstimatedHeight
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func fetchGitHubRepositories() {
        Logger.info("Starting repository fetch for user: \(GitHubRepositoryService.defaultUserName)")
        isLoadingRepos = true
        repos.removeAll()
        commitDict.removeAll()
        tableView.reloadData()
        
        Task { [weak self] in
            guard let self else { return }
            
            let result = await GitHubRepositoryService.shared.fetchRepos(user: GitHubRepositoryService.defaultUserName)
            
            switch result {
            case .success(let repos):
                Logger.info("Repository fetch completed. Count: \(repos.count)")
                await MainActor.run {
                    self.repos = repos
                    self.isLoadingRepos = false
                    self.tableView.reloadData()
                }
                self.fetchLatestCommitsForRepos()
                
            case .failure(let error):
                await MainActor.run {
                    self.repos = []
                    self.isLoadingRepos = false
                    self.tableView.reloadData()
                }
                Logger.error("Repo load error: \(error)")
            }
        }
    }
    
    private func fetchLatestCommitsForRepos() {
        let maxConcurrent = Self.maxConcurrentRequests
        Logger.debug("Starting commit fetch for \(repos.count) repositories. Max concurrency: \(maxConcurrent)")
        
        Task { [weak self] in
            guard let self else { return }
            
            // Process repositories in batches to control concurrency.
            for start in stride(
                from: 0,
                to: repos.count,
                by: maxConcurrent
            ) {
                let end = min(start + maxConcurrent, repos.count)
                let batch = Array(repos[start..<end])
                
                await withTaskGroup(of: (Int, Result<CommitModel?, GitHubError>).self) { group in
                    for repo in batch {
                        group.addTask {
                            let result = await GitHubRepositoryService.shared.fetchLastCommit(fullName: repo.fullName)
                            return (repo.id, result)
                        }
                    }
                    
                    for await (repoID, result) in group {
                        await MainActor.run { [weak self] in
                            guard let self else { return }
                            var sha: String?
                            if case .success(let commit) = result {
                                sha = commit?.sha
                            }
                            // Update data source regardless of success or failure.
                            self.commitDict[repoID] = sha ?? ""
                            
                            if case .failure(let error) = result {
                                Logger.error("Commit load error: \(error)")
                            }
                            
                            // Find the index of the repository by ID, return if not found.
                            guard let index = self.repos.firstIndex(where: { $0.id == repoID }) else { return }
                            let indexPath = IndexPath(row: index, section: 0)
                            
                            // Only update cells that are currently visible on screen.
                            // Cells off-screen return nil.
                            guard let cell = self.tableView.cellForRow(at: indexPath) as? RepoTableViewCell else {
                                return
                            }
                            // Stop loading indicator for both success and failure cases.
                            cell.finishLoadingCommit(sha: sha)
                        }
                    }
                }
            }
            Logger.debug("Commit fetch pipeline finished")
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        // Show skeleton rows when loading, otherwise show actual repository count.
        isLoadingRepos ? skeletonRowsCount : repos.count
    }
    
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RepoTableViewCell.reuseIdentifier,
            for: indexPath
        )
        guard let customCell = cell as? RepoTableViewCell else {
            return UITableViewCell()
        }
        
        customCell.delegate = self
        
        if isLoadingRepos {
            customCell.showLoadingSkeleton()
            return customCell
        }
        
        let repo = repos[indexPath.row]
        let sha = commitDict[repo.id]
        // Configure basic repository information.
        customCell.configure(repo: repo)
        if let sha = sha {
            // Loading finished - display the result.
            // Empty string means commit loading completed with empty result.
            customCell.finishLoadingCommit(sha: sha)
        } else {
            // Not loaded yet - show loading animation.
            customCell.startLoadingCommit()
        }
        return customCell
    }
}

extension ViewController: RepoTableViewCellProtocol {
    // Handle repository link tap and open in Safari view controller.
    func repoTableViewCell(
        _ cell: RepoTableViewCell,
        didTapHTMLLink url: URL
    ) {
        Logger.info("Opening GitHub link: \(url.absoluteString)")
        let safariController = SFSafariViewController(url: url)
        present(safariController, animated: true)
    }
    
    // Handle commit ID tap and show copy dialog.
    func repoTableViewCell(
        _ cell: RepoTableViewCell,
        didTapCommit fullSHA: String
    ) {
        Logger.debug("Commit SHA tapped: \(fullSHA)")
        let alert = UIAlertController(
            title: "Commit ID",
            message: fullSHA,
            preferredStyle: .alert
        )
        
        alert.addAction(
            UIAlertAction(
                title: "Copy",
                style: .default
            ) { _ in
                Logger.info("Commit SHA copied to pasteboard")
                UIPasteboard.general.string = fullSHA
            }
        )
        
        alert.addAction(
            UIAlertAction(
                title: "Close",
                style: .default
            )
        )
        
        present(alert, animated: true)
    }
}
