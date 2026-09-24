# GitHubRepoViewer

Eine leichtgewichtige iOS-App zum Durchsuchen von GitHub-Repositories und den neuesten Commit-IDs für einen Zielbenutzer.

Die App ruft Repository-Listen von GitHub ab, zeigt sie in einer benutzerdefinierten Tabellenansicht im Kartenstil an und unterstützt das Öffnen von Repo-Links in Safari sowie das Kopieren von Commit-SHA-Werten.

## Inhaltsverzeichnis

- [Projektziele](#projektziele)
- [Kernfunktionen](#kernfunktionen)
- [Umsetzungsideen](#umsetzungsideen)
- [Architekturdesign](#architekturdesign)
- [Technologieauswahl](#technologieauswahl)
- [Projektstruktur](#projektstruktur)
- [Datenfluss](#datenfluss)
- [Fehlerbehandlungsstrategie](#fehlerbehandlungsstrategie)
- [Nebenläufigkeit & Performance](#nebenläufigkeit--performance)
- [UI-Design-Hinweise](#ui-design-hinweise)
- [Animationsdesign-Konzept](#animationsdesign-konzept)
- [Konfiguration](#konfiguration)
- [So wird es ausgeführt](#so-wird-es-ausgeführt)
- [Tests](#tests)
- [Mögliche zukünftige Verbesserungen](#mögliche-zukünftige-verbesserungen)

## Projektziele

- Eine saubere und verständliche iOS-Beispiel-App mit modernem Swift async/await erstellen.
- Netzwerkebenen-Abstraktion mit protokollbasierter Trennung von Service/Client demonstrieren.
- Eine benutzerfreundliche Listen-UI mit Lade-Skeleton-Zustand und Commit-Ladezustand bereitstellen.
- Den Code leicht testbar und erweiterbar halten.

## Kernfunktionen

- Öffentliche Repositories für einen konfigurierten GitHub-Benutzernamen abrufen.
- Repository-Metadaten anzeigen:
  - Name
  - Beschreibung
  - Stars / Forks / Sprache
- Neuesten Commit-SHA jedes Repositories abrufen und anzeigen.
- Auf Repository-Link tippen, um ihn in `SFSafariViewController` zu öffnen.
- Auf Commit-Zeilenaktion tippen, um Commit-SHA anzuzeigen und zu kopieren.
- Skeleton-ähnlichen Ladezustand anzeigen, während Repositories geladen werden.
- Pro-Zelle-Commit-Ladeindikator anzeigen, während Commit-Anfrage läuft.

## Umsetzungsideen

### 1) Geschichtete Verantwortlichkeiten

Die App teilt Verantwortlichkeiten auf in:

- `View`-Schicht: Zellen rendern und Benutzerinteraktionen behandeln.
- `Controller`-Schicht: Tabellenansicht-Rendering und asynchrone Aufgaben orchestrieren.
- `Service`-Schicht: API-Use-Cases auf Geschäftsebene (`fetchRepos`, `fetchLastCommit`).
- `Client`-Schicht: Low-Level-HTTP-Anfrageausführung und Antwortvalidierung.
- `Model`-Schicht: Modelle zum Dekodieren von API-Antworten.

Dies hält Netzwerkdetails aus der UI-Logik von View/Controller heraus.

### 2) Progressives Ladeerlebnis

Das Design trennt das Laden absichtlich in zwei Phasen:

- Phase A: Laden der Repository-Liste (globale Skeleton-Zeilen)
- Phase B: Laden der Commits pro Repository (Indikator auf Zellenebene)

Dies bietet dem Benutzer schnelleres wahrgenommenes Feedback.

### 3) Netzwerk mit Fokus auf Testbarkeit

`GitHubAPIClient` wird in der Service-Schicht über ein Protokoll (`GitHubAPIClientProtocol`) konsumiert, wodurch Mocking/Ersetzen in Unit-Tests ermöglicht wird.

Netzwerktests verwenden benutzerdefinierte `URLProtocol`-Interception, um echte Netzwerkabhängigkeit zu vermeiden.

## Architekturdesign

Die aktuelle Architektur ist nahe an MVC mit serviceorientiertem Networking.

- `ViewController` übernimmt UI-Komposition und Interaktionsereignisse.
- `RepoTableViewCell` kapselt Anzeige und zellenspezifische Interaktions-Callbacks über ein Protokoll.
- `GitHubRepositoryService` ist die Domänenfassade für Repository/Commit-Use-Cases.
- `GitHubAPIClient` konzentriert sich auf Anfrageausführung und Übersetzung von HTTP-Ergebnissen.

### Warum diese Architektur

- Einfach genug für kleine Apps.
- Klarer Erweiterungspfad:
  - Später ViewModel für MVVM-Migration hinzufügen.
  - Repository-Cache oder Persistenz unter der Service-Schicht hinzufügen.

## Technologieauswahl

- Sprache: Swift 5.x+ (moderne Concurrency-Syntax)
- UI: UIKit (`UITableView`, benutzerdefinierte `UITableViewCell`)
- Nebenläufigkeit: `async/await`, `Task`, `withTaskGroup`
- Networking: `URLSession`
- Browser-Präsentation: `SafariServices` (`SFSafariViewController`)
- Tests: `XCTest`, `URLProtocol`-Stubbing

## Projektstruktur

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

## Datenfluss

1. `ViewController` löst `fetchGitHubRepositories()` aus.
2. `GitHubRepositoryService.fetchRepos(user:)` setzt Endpoint zusammen und ruft Client auf.
3. `GitHubAPIClient.request(urlString:)` führt HTTP-Anfrage aus und validiert Statuscode.
4. Antwortdaten werden in `[GitHubRepoModel]` dekodiert.
5. UI lädt mit Repository-Liste neu.
6. Controller ruft parallel den neuesten Commit für jedes Repo über `fetchLastCommit(fullName:)` ab.
7. Sichtbare Zellen aktualisieren den Commit-Zustand individuell.

## Fehlerbehandlungsstrategie

`GitHubError` zentralisiert Fehler:

- `invalidURL`
- `invalidResponse(url:statusCode:data:)`
- `decodingFailed(Error)`
- `networkError(Error)`

Die UI protokolliert derzeit Fehler und rendert weiterhin Best-Effort-Daten.

## Nebenläufigkeit & Performance

- Verwendet asynchrone Tasks für nicht blockierende Netzwerkoperationen.
- Bündelt Commit-Abrufe mit `withTaskGroup`.
- `maxConcurrentRequests` steuert Parallelität für sicherere API-Nutzung.
- Tabelle verwendet geschätzte Zeilenhöhe + automatische Dimension.

## UI-Design-Hinweise

- Benutzerdefinierte Zelle im Kartenstil mit benutzerdefiniertem Pfad und Schatten.
- Skeleton-Ladeplatzhalter für initialen Listenabruf.
- Commit-Ladeindikator pro Zelle.
- Link- und Commit-Aktionen werden über ein Protokoll an den Controller delegiert.

## Animationsdesign-Konzept

Dieses Projekt verwendet eine zweistufige Ladeanimationsstrategie, um die wahrgenommene Performance zu verbessern und gleichzeitig flüssiges Scrollen zu erhalten.

### 1) Globale Skeleton-Phase (Laden der Repository-Liste)

- Bevor Repository-Daten zurückgegeben werden, zeigen Tabellenzeilen einen leichten Skeleton-Zustand.
- Das Skeleton verwendet einen subtilen Opazitäts-Puls (`CABasicAnimation`), um aktives Laden anzuzeigen, ohne den Benutzer abzulenken.
- Ziel: Leeren Bildschirm vermeiden und sofortiges visuelles Feedback erzeugen.

### 2) Commit-Ladephase pro Zelle (nach Erscheinen der Liste)

- Sobald Repositories gerendert sind, lädt jede Zelle asynchron ihren neuesten Commit.
- Ein kleiner Inline-Aktivitätsindikator wird nur für das Commit-Feld dieser spezifischen Zelle angezeigt.
- Ziel: Benutzer können Repository-Inhalte sofort durchsuchen, während Commit-Details progressiv erscheinen.

### Übergangsverhalten

- Skeleton stoppt, sobald Repository-Listendaten an die Zelle gebunden sind.
- Commit-Ladeindikator stoppt, wenn Commit-Abruf abgeschlossen ist (Erfolg oder Fehler), dann zeigt:
  - `Letzter Commit: <SHA>`, wenn verfügbar
  - `Kein Commit verfügbar`, wenn nicht verfügbar

### Performance-Überlegungen

- UI-Updates erfolgen im Hauptthread und sind auf sichtbare Zellen beschränkt.
- Zellwiederverwendung setzt Lade- und Animationszustand in `prepareForReuse()` zurück, um visuelle Artefakte zu vermeiden.
- Commit-Anfragen werden mit kontrollierter Nebenläufigkeit gebündelt, um API-Druck zu reduzieren und Scrollen reaktionsfähig zu halten.

## Konfiguration

### GitHub-Benutzer

Standard-GitHub-Benutzername wird konfiguriert in:

- `GitHubRepositoryService.defaultUserName`

### API-Token

Token ist derzeit definiert in:

- `GitHubAPIConfiguration.token`

Für Produktion empfohlen:

- Token aus dem Quellcode entfernen.
- Über `.xcconfig`, Umgebungsvariable oder sichere Keychain-Strategie injizieren.

## So wird es ausgeführt

1. `GitHubRepoViewer.xcodeproj` in Xcode öffnen.
2. Das Schema `GitHubRepoViewer` auswählen.
3. Einen iOS-Simulator auswählen.
4. Bauen und ausführen.

## Tests

In Xcode ausführen:

- Product -> Test

Oder Kommandozeile:

```bash
xcodebuild test \
  -project GitHubRepoViewer.xcodeproj \
  -scheme GitHubRepoViewer \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Aktuelle Tests umfassen:

- `GitHubAPIClientNetworkTests`
  - URL-Gültigkeitsbehandlung
  - 2xx-Erfolgsbehandlung
  - Nicht-2xx-Antwortzuordnung
  - Netzwerkfehlerzuordnung
- `GitHubRepoModelTests`
  - Dekodierungsschlüsselzuordnung
  - Optional/Null-Dekodierung
  - Fehlende erforderliche Schlüssel

## Mögliche zukünftige Verbesserungen

- ViewModel (MVVM) einführen, falls die View-Logik wächst.
- Response-Caching-Schicht hinzufügen.
- Retry/Backoff-Strategie für vorübergehende API-Fehler hinzufügen.
- Snapshot/UI-Tests für Lade-/Geladen-/Fehlerzustände hinzufügen.
- Konfiguration sicher externalisieren (insbesondere API-Token).
