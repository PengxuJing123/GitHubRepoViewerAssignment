//
//  RepoTableViewCell.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/16.
//

import UIKit

final class RepoTableViewCell: UITableViewCell {
    static let reuseIdentifier = "RepoTableViewCell"
    
    private enum Metrics {
        static let cardInset: CGFloat = 12
        static let verticalInset: CGFloat = 8
        static let contentInset: CGFloat = 20
        static let sectionSpacing: CGFloat = 16
        static let topCornerRadius: CGFloat = 10
        static let bottomLeftCornerRadius: CGFloat = 10
        static let bottomRightCornerRadius: CGFloat = 30
        static let borderWidth: CGFloat = 2
        
        static let nameFontSize: CGFloat = 20
        static let descriptionFontSize: CGFloat = 17
        static let buttonFontSize: CGFloat = 17
        static let statsFontSize: CGFloat = 16
        static let statsStackSpacing: CGFloat = 4
        static let commitIndicatorSpacing: CGFloat = 8
        static let statsTopSpacing: CGFloat = 20
        static let shadowRadius: CGFloat = 8
        static let shadowOpacity: CGFloat = 0.22
        static let shadowOffsetHeight: CGFloat = 2
        
        // Skeleton pulse animation tuning.
        static let skeletonAnimationFromOpacity: CGFloat = 1.0
        static let skeletonAnimationToOpacity: CGFloat = 0.3
        static let skeletonAnimationDuration: CGFloat = 1.0
        static let skeletonAnimationKey = "skeletonPulse"
    }
    
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    weak var delegate: RepoTableViewCellProtocol?
    
    private var commitSHA: String?
    private var isShowingSkeleton = false
    private var githubURL: URL?
    private var lastUpdatedBounds: CGRect = .zero
    
    private let backgroundShapeLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.masksToBounds = false
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(
            ofSize: Metrics.nameFontSize,
            weight: .bold
        )
        label.textColor = .label
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Metrics.descriptionFontSize)
        label.textColor = .label
        // Allow multi-line wrapping for long descriptions.
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        
        // Preserve vertical readability when surrounding views compress.
        label.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
        return label
    }()
    
    private let githubRepoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .systemFont(ofSize: Metrics.buttonFontSize, weight: .medium)
        // Left-align title to match text layout.
        button.contentHorizontalAlignment = .leading
        // Keep button height stable when description expands.
        button.setContentHuggingPriority(
            .required,
            for: .vertical
        )
        
        return button
    }()
    
    private let commitButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .systemFont(ofSize: Metrics.buttonFontSize)
        button.contentHorizontalAlignment = .leading
        // Prefer wrapping commit text while leaving room for the spinner.
        button.setContentHuggingPriority(
            .defaultHigh,
            for: .horizontal
        )
        return button
    }()
    
    private let commitLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let starLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Metrics.statsFontSize)
        label.textColor = .label
        label.textAlignment = .left
        return label
    }()
    
    private let forkLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Metrics.statsFontSize)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    private let languageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Metrics.statsFontSize)
        label.textColor = .label
        label.textAlignment = .right
        return label
    }()
    
    private lazy var statsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [starLabel, forkLabel, languageLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        // Keep three stats spread evenly.
        stack.distribution = .equalSpacing
        stack.spacing = Metrics.statsStackSpacing
        return stack
    }()
    
    private let skeletonLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // Programmatic-only initialization.
    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )
        setupSubviews()
    }
    
    // Storyboard/XIB initialization is intentionally unsupported.
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.layoutIfNeeded()
        
        // Skip updates until valid bounds are available.
        guard containerView.bounds.width > 0, containerView.bounds.height > 0 else {
            return
        }
        
        // Rebuild shape only when size changes.
        guard containerView.bounds != lastUpdatedBounds else {
            return
        }
        lastUpdatedBounds = containerView.bounds
        updateCardShape(cardRect: containerView.bounds)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        Logger.verbose("RepoTableViewCell prepareForReuse")
        isShowingSkeleton = false
        nameLabel.text = nil
        descriptionLabel.text = nil
        
        githubRepoButton.setAttributedTitle(nil, for: .normal)
        githubRepoButton.isEnabled = false
        
        commitButton.setAttributedTitle(nil, for: .normal)
        commitButton.isEnabled = false
        
        starLabel.text = nil
        forkLabel.text = nil
        languageLabel.text = nil
        commitSHA = nil
        githubURL = nil
        
        stopAnimations()
    }
    
    func configure(repo: GitHubRepoModel) {
        Logger.verbose("Configuring cell for repo: \(repo.fullName)")
        if isShowingSkeleton {
            stopSkeletonPulse()
            isShowingSkeleton = false
            skeletonLoadingIndicator.stopAnimating()
        }
        nameLabel.text = repo.name
        descriptionLabel.text = repo.description ?? "No description"
        starLabel.text = "Stars: \(formattedCount(repo.starCount))"
        forkLabel.text = "Forks: \(formattedCount(repo.forksCount))"
        languageLabel.text = "Language: \(repo.language ?? "Unknown")"
        setGithubRepoButton(url: URL(string: repo.htmlUrl))
    }
    
    func showLoadingSkeleton() {
        Logger.verbose("Cell entered skeleton loading state")
        isShowingSkeleton = true
        
        nameLabel.text = " "
        descriptionLabel.text = " "
        starLabel.text = " "
        forkLabel.text = " "
        languageLabel.text = " "
        githubURL = nil
        commitSHA = nil
        
        setGithubRepoButton(url: nil, isLoading: true)
        setCommitButton(title: " ", isEnabled: false)
        
        startSkeletonPulse()
        skeletonLoadingIndicator.startAnimating()
    }
    
    func startLoadingCommit() {
        Logger.verbose("Commit loading started for cell")
        commitSHA = nil
        setCommitButton(title: "Loading commit...", isEnabled: false)
        commitLoadingIndicator.startAnimating()
    }
    
    func finishLoadingCommit(sha: String?) {
        Logger.debug("Commit loading finished for cell: \(sha ?? "nil")")
        commitLoadingIndicator.stopAnimating()
        commitSHA = sha
        
        if let sha = sha, !sha.isEmpty {
            setCommitButton(title: "Last commit: \(sha)", isEnabled: true)
        } else {
            setCommitButton(title: "No commit available", isEnabled: false)
        }
    }
    
    // MARK: - Setup
    private func setupSubviews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(githubRepoButton)
        containerView.addSubview(commitButton)
        containerView.addSubview(commitLoadingIndicator)
        containerView.addSubview(statsStackView)
        containerView.addSubview(skeletonLoadingIndicator)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        githubRepoButton.translatesAutoresizingMaskIntoConstraints = false
        commitButton.translatesAutoresizingMaskIntoConstraints = false
        commitLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        skeletonLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        githubRepoButton.addAction(
            UIAction { [weak self] _ in
                guard let self, let url = self.githubURL else { return }
                Logger.verbose("Repo link action triggered in cell")
                self.delegate?.repoTableViewCell(self, didTapHTMLLink: url)
            },
            for: .touchUpInside
        )
        
        commitButton.addAction(
            UIAction { [weak self] _ in
                guard let self, let sha = commitSHA else { return }
                Logger.verbose("Commit action triggered in cell")
                delegate?.repoTableViewCell(self, didTapCommit: sha)
            },
            for: .touchUpInside
        )
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Metrics.verticalInset
            ),
            containerView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Metrics.cardInset
            ),
            containerView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Metrics.cardInset
            ),
            containerView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Metrics.verticalInset
            ),
            
            nameLabel.topAnchor.constraint(
                equalTo: containerView.topAnchor,
                constant: Metrics.contentInset
            ),
            nameLabel.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: Metrics.contentInset
            ),
            nameLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor,
                constant: -Metrics.contentInset
            ),
            
            descriptionLabel.topAnchor.constraint(
                equalTo: nameLabel.bottomAnchor,
                constant: Metrics.sectionSpacing
            ),
            descriptionLabel.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: Metrics.contentInset
            ),
            descriptionLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor,
                constant: -Metrics.contentInset
            ),
            
            githubRepoButton.topAnchor.constraint(
                equalTo: descriptionLabel.bottomAnchor,
                constant: Metrics.sectionSpacing
            ),
            githubRepoButton.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: Metrics.contentInset
            ),
            githubRepoButton.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor,
                constant: -Metrics.contentInset
            ),
            
            commitButton.topAnchor.constraint(
                equalTo: githubRepoButton.bottomAnchor,
                constant: Metrics.sectionSpacing
            ),
            commitButton.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: Metrics.contentInset
            ),
            
            commitLoadingIndicator.centerYAnchor.constraint(
                equalTo: commitButton.centerYAnchor
            ),
            commitLoadingIndicator.leadingAnchor.constraint(
                equalTo: commitButton.trailingAnchor,
                constant: Metrics.commitIndicatorSpacing
            ),
            commitLoadingIndicator.trailingAnchor.constraint(
                lessThanOrEqualTo: containerView.trailingAnchor,
                constant: -Metrics.contentInset
            ),
            
            statsStackView.topAnchor.constraint(
                equalTo: commitButton.bottomAnchor,
                constant: Metrics.statsTopSpacing
            ),
            statsStackView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: Metrics.contentInset
            ),
            statsStackView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor,
                constant: -Metrics.contentInset
            ),
            
            skeletonLoadingIndicator.centerXAnchor.constraint(
                equalTo: containerView.centerXAnchor
            ),
            skeletonLoadingIndicator.centerYAnchor.constraint(
                equalTo: containerView.centerYAnchor
            ),
        ])
        
        // Hard cap: prevent stack from overflowing out of the card.
        let stackBottomMax = statsStackView.bottomAnchor.constraint(
            lessThanOrEqualTo: containerView.bottomAnchor,
            constant: -Metrics.contentInset
        )
        stackBottomMax.priority = .required
        stackBottomMax.isActive = true
        
        // Preferred spacing: keep bottom padding when space allows.
        let stackBottomPreferred = statsStackView.bottomAnchor.constraint(
            equalTo: containerView.bottomAnchor,
            constant: -Metrics.contentInset
        )
        stackBottomPreferred.priority = .defaultHigh
        stackBottomPreferred.isActive = true
    }
    
    // MARK: - Layout & Drawing
    private func updateCardShape(cardRect: CGRect) {
        // Avoid drawing with invalid geometry.
        guard cardRect.width > 0, cardRect.height > 0 else { return }
        
        let path = cardPath(in: cardRect)
        
        backgroundShapeLayer.path = path.cgPath
        backgroundShapeLayer.frame = cardRect
        backgroundShapeLayer.fillColor = UIColor.systemGray6.cgColor
        
        borderLayer.path = path.cgPath
        borderLayer.frame = cardRect
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.systemGray.cgColor
        borderLayer.lineWidth = Metrics.borderWidth
        
        // Add layers once; later updates only mutate path/frame.
        if backgroundShapeLayer.superlayer == nil {
            containerView.layer.insertSublayer(
                backgroundShapeLayer,
                at: 0
            )
        }
        if borderLayer.superlayer == nil {
            containerView.layer.addSublayer(borderLayer)
        }
        
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = Float(Metrics.shadowOpacity)
        containerView.layer.shadowRadius = Metrics.shadowRadius
        containerView.layer.shadowOffset = CGSize(
            width: 0,
            height: Metrics.shadowOffsetHeight
        )
        // Set shadowPath for better scrolling performance.
        containerView.layer.shadowPath = path.cgPath
    }
    
    // Builds a custom card path with asymmetric corner radii.
    private func cardPath(in rect: CGRect) -> UIBezierPath {
        // Calculate corner radii, clamped to half the view's smaller dimension
        // Prevents invalid radii that exceed half the view's width/height
        let topRightRadius = min(
            Metrics.topCornerRadius,
            min(rect.width, rect.height) / 2
        )
        let bottomLeftRadius = min(
            Metrics.bottomLeftCornerRadius,
            min(rect.width, rect.height) / 2
        )
        let bottomRightRadius = min(
            Metrics.bottomRightCornerRadius,
            min(rect.width, rect.height) / 2
        )
        
        // Create empty bezier path for custom card shape
        let path = UIBezierPath()
        // Start at top-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Draw top edge to start of top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - topRightRadius, y: rect.minY))
        // Draw top-right rounded corner (from -90° to 0°)
        path.addArc(
            withCenter: CGPoint(x: rect.maxX - topRightRadius, y: rect.minY + topRightRadius),
            radius: topRightRadius,
            startAngle: -.pi / 2,
            endAngle: 0,
            clockwise: true
        )
        
        // Draw right edge to start of bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRightRadius))
        // Draw bottom-right rounded corner (from 0° to 90°)
        path.addArc(
            withCenter: CGPoint(x: rect.maxX - bottomRightRadius, y: rect.maxY - bottomRightRadius),
            radius: bottomRightRadius,
            startAngle: 0,
            endAngle: .pi / 2,
            clockwise: true
        )
        
        // Draw bottom edge to start of bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + bottomLeftRadius, y: rect.maxY))
        // Draw bottom-left rounded corner (from 90° to 180°)
        path.addArc(
            withCenter: CGPoint(x: rect.minX + bottomLeftRadius, y: rect.maxY - bottomLeftRadius),
            radius: bottomLeftRadius,
            startAngle: .pi / 2,
            endAngle: .pi,
            clockwise: true
        )
        
        // Draw left edge back to the starting point (top-left)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        return path
    }
    
    // MARK: - Loading/Skeleton State
    private func startSkeletonPulse() {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = Metrics.skeletonAnimationFromOpacity
        pulse.toValue = Metrics.skeletonAnimationToOpacity
        pulse.duration = Metrics.skeletonAnimationDuration
        pulse.autoreverses = true
        pulse.repeatCount = .greatestFiniteMagnitude
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        containerView.layer.add(pulse, forKey: Metrics.skeletonAnimationKey)
    }
    
    private func stopSkeletonPulse() {
        containerView.layer.removeAnimation(forKey: Metrics.skeletonAnimationKey)
    }
    
    private func stopAnimations() {
        stopSkeletonPulse()
        commitLoadingIndicator.stopAnimating()
        skeletonLoadingIndicator.stopAnimating()
    }
    
    // MARK: - UI Update Helpers
    private func setGithubRepoButton(
        url: URL?,
        isLoading: Bool = false
    ) {
        githubRepoButton.setAttributedTitle(nil, for: .normal)
        let textColor: UIColor = .label
        
        if isLoading {
            githubRepoButton.setAttributedString(
                " ",
                color: textColor,
                underline: false
            )
            githubRepoButton.isEnabled = false
            return
        }
        
        guard let url = url, UIApplication.shared.canOpenURL(url) else {
            githubURL = nil
            githubRepoButton.setAttributedString(
                "Github link unavailable",
                color: textColor,
                underline: false
            )
            githubRepoButton.isEnabled = false
            return
        }
        
        githubURL = url
        githubRepoButton.setAttributedString(
            "View on GitHub",
            color: textColor,
            underline: true
        )
        githubRepoButton.isEnabled = true
    }
    
    private func setCommitButton(
        title: String?,
        isEnabled: Bool
    ) {
        commitButton.setAttributedTitle(nil, for: .normal)
        
        guard let title = title else {
            commitButton.isEnabled = false
            return
        }
        
        // Use semantic color for light/dark mode support.
        let textColor: UIColor = .label
        commitButton.setAttributedString(
            title,
            color: textColor,
            underline: isEnabled
        )
        commitButton.isEnabled = isEnabled
    }
    
    // MARK: - Helpers
    private func formattedCount(_ value: Int) -> String {
        RepoTableViewCell.numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

// MARK: - UIButton Helper
private extension UIButton {
    func setAttributedString(
        _ text: String,
        color: UIColor,
        underline: Bool
    ) {
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color
        ]
        if underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        setAttributedTitle(
            NSAttributedString(
                string: text,
                attributes: attributes
            ),
            for: .normal
        )
    }
}
