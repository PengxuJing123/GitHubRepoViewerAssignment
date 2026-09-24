# GitHubRepoViewer

A lightweight iOS app for browsing GitHub repositories and latest commit IDs for a target user.

The app fetches repository lists from GitHub, displays them in a custom card-style table view, and supports opening repo links in Safari plus copying commit SHA values.

## Table of Contents

- [Project Goals](#project-goals)
- [Core Features](#core-features)
- [Implementation Ideas](#implementation-ideas)
- [Architecture Design](#architecture-design)
- [Technology Selection](#technology-selection)
- [Project Structure](#project-structure)
- [Data Flow](#data-flow)
- [Error Handling Strategy](#error-handling-strategy)
- [Concurrency & Performance](#concurrency--performance)
- [UI Design Notes](#ui-design-notes)
- [Animation Design Concept](#animation-design-concept)
- [Configuration](#configuration)
- [How to Run](#how-to-run)
- [Testing](#testing)
- [Possible Future Improvements](#possible-future-improvements)

## Project Goals

- Build a clean and understandable iOS sample using modern Swift async/await.
- Demonstrate network-layer abstraction with protocol-based service/client separation.
- Provide a user-friendly list UI with loading skeleton state and commit loading state.
- Keep the code easy to test and extend.

## Core Features

- Fetch public repositories for a configured GitHub username.
- Show repository metadata:
  - Name
  - Description
  - Stars / Forks / Language
- Fetch and show each repository's latest commit SHA.
- Tap repository link to open in `SFSafariViewController`.
- Tap commit row action to view and copy commit SHA.
- Show skeleton-like loading state while repositories are loading.
- Show per-cell commit loading indicator while commit request is in progress.

## Implementation Ideas

### 1) Layered responsibilities

The app splits responsibilities into:

- `View` layer: rendering cells and handling user interactions.
- `Controller` layer: orchestrating table view rendering and async tasks.
- `Service` layer: business-level API use cases (`fetchRepos`, `fetchLastCommit`).
- `Client` layer: low-level HTTP request execution and response validation.
- `Model` layer: API response decoding models.

This keeps network details out of the view/controller UI logic.

### 2) Progressive loading experience

The design intentionally separates loading into two phases:

- Phase A: repository list loading (global skeleton rows)
- Phase B: per-repository commit loading (cell-level indicator)

This provides faster perceived feedback to users.

### 3) Testability-first networking

`GitHubAPIClient` is consumed through a protocol (`GitHubAPIClientProtocol`) in the service layer, enabling mocking/replacement in unit tests.

Network tests use custom `URLProtocol` interception to avoid real network dependency.

## Architecture Design

Current architecture is close to MVC with service-oriented networking.

- `ViewController` handles UI composition and interaction events.
- `RepoTableViewCell` encapsulates display and cell-level interaction callbacks via protocol.
- `GitHubRepositoryService` is the domain facade for repository/commit use cases.
- `GitHubAPIClient` focuses on request execution and HTTP result translation.

### Why this architecture

- Simple enough for small apps.
- Clear extension path:
  - Add ViewModel later for MVVM migration.
  - Add repository cache or persistence under service layer.

## Technology Selection

- Language: Swift 5.x+ (modern concurrency syntax)
- UI: UIKit (`UITableView`, custom `UITableViewCell`)
- Concurrency: `async/await`, `Task`, `withTaskGroup`
- Networking: `URLSession`
- Browser presentation: `SafariServices` (`SFSafariViewController`)
- Testing: `XCTest`, `URLProtocol` stubbing

## Project Structure

```text
GitHubRepoViewer/
├── GitHubRepoViewer/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── Model/
│   │   └── GitHubModel.swift
│   ├── Controller/
│   │   └── ViewController.swift
│   ├── View/
│   │   ├── Cells/
│   │   │   └── RepoTableViewCell.swift
│   │   └── Protocols/
│   │       └── RepoTableViewCellProtocol.swift
│   ├── Network/
│   │   ├── Client/
│   │   │   ├── GitHubAPIClient.swift
│   │   │   ├── GitHubAPIClientProtocol.swift
│   │   │   └── GitHubAPIConfiguration.swift
│   │   ├── Service/
│   │   │   ├── GitHubRepositoryProtocol.swift
│   │   │   └── GitHubRepositoryService.swift
│   │   └── Error/
│   │       └── GitHubError.swift
│   └── Utils/
│       └── Logger/
│           └── Logger.swift
├── GitHubRepoViewerTests/
│   ├── GitHubAPIClientNetworkTests.swift
│   └── GitHubRepoModelTests.swift
└── GitHubRepoViewerUITests/
```

## Data Flow

1. `ViewController` triggers `fetchGitHubRepositories()`.
2. `GitHubRepositoryService.fetchRepos(user:)` composes endpoint and calls client.
3. `GitHubAPIClient.request(urlString:)` executes HTTP request and validates status code.
4. Response data is decoded into `[GitHubRepoModel]`.
5. UI reloads with repository list.
6. Controller concurrently fetches latest commit for each repo via `fetchLastCommit(fullName:)`.
7. Visible cells update commit state individually.

## Error Handling Strategy

`GitHubError` centralizes failures:

- `invalidURL`
- `invalidResponse(url:statusCode:data:)`
- `decodingFailed(Error)`
- `networkError(Error)`

UI currently logs errors and continues rendering best-effort data.

## Concurrency & Performance

- Uses async tasks for non-blocking network operations.
- Batches commit fetches with `withTaskGroup`.
- `maxConcurrentRequests` controls parallelism for safer API usage.
- Table uses estimated row height + automatic dimension.

## UI Design Notes

- Card-style custom cell with custom path and shadow.
- Skeleton loading placeholder for initial list fetch.
- Commit loading indicator per cell.
- Link and commit actions are delegated to controller via protocol.

## Animation Design Concept

This project uses a two-stage loading animation strategy to improve perceived performance while keeping scrolling smooth.

### 1) Global skeleton phase (repository list loading)

- Before repository data is returned, table rows show a lightweight skeleton state.
- The skeleton uses a subtle opacity pulse (`CABasicAnimation`) to indicate active loading without distracting the user.
- Goal: avoid blank-screen waiting and establish immediate visual feedback.

### 2) Per-cell commit loading phase (after list appears)

- Once repositories are rendered, each cell loads its latest commit asynchronously.
- A small inline activity indicator is shown only for the commit field of that specific cell.
- Goal: allow users to browse repository content immediately while commit details progressively appear.

### Transition behavior

- Skeleton stops as soon as repository list data is bound to the cell.
- Commit loading indicator stops when commit fetch finishes (success or failure), then shows:
  - `Last commit: <SHA>` when available
  - `No commit available` when unavailable

### Performance considerations

- UI updates happen on the main thread and are scoped to visible cells.
- Cell reuse resets loading and animation state in `prepareForReuse()` to avoid visual artifacts.
- Commit requests are batched with controlled concurrency to reduce API pressure and keep scrolling responsive.

## Configuration

### GitHub User

Default GitHub username is configured in:

- `GitHubRepositoryService.defaultUserName`

### API Token

Token is currently defined in:

- `GitHubAPIConfiguration.token`

Recommended for production:

- Move token out of source code.
- Inject via `.xcconfig`, environment variable, or secure keychain strategy.

## How to Run

1. Open `GitHubRepoViewer.xcodeproj` in Xcode.
2. Select the `GitHubRepoViewer` scheme.
3. Choose an iOS simulator.
4. Build and run.

## Testing

Run from Xcode:

- Product -> Test

Or command line:

```bash
xcodebuild test \
  -project GitHubRepoViewer.xcodeproj \
  -scheme GitHubRepoViewer \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Current tests include:

- `GitHubAPIClientNetworkTests`
  - URL validity handling
  - 2xx success handling
  - non-2xx response mapping
  - network error mapping
- `GitHubRepoModelTests`
  - decoding key mapping
  - optional/null decoding
  - missing required keys

## Possible Future Improvements

- Introduce ViewModel (MVVM) if view logic grows.
- Add response caching layer.
- Add retry/backoff strategy for transient API failures.
- Add snapshot/UI tests for loading/loaded/error states.
- Externalize configuration securely (especially API token).

