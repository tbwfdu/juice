# Juice - macOS UEM Application Manager

## Project Overview

**Juice** is a native macOS application designed to bridge the gap between local application repositories (specifically Homebrew Casks) and a Unified Endpoint Management (UEM) system (Workspace ONE UEM).

Its primary goal is to help administrators identify applications in their UEM environment that are out of date compared to the latest versions available in the community (Homebrew), facilitating easier application lifecycle management.

## Key Features

*   **Catalog Sync:** Loads a local catalog of applications (derived from Homebrew Casks) and fetches the current application list from a configured UEM environment.
*   **Update Detection:** Automatically compares UEM apps against the local catalog to identify newer versions.
*   **Fuzzy Matching:** Uses Levenshtein distance and alias mapping to intelligently correlate application names between the two disparate sources.
*   **Modern UI:** Built with **SwiftUI**, featuring a custom translucent "glass" window design, sidebar navigation, and gradient themes.
*   **Import/Export:** Capabilities to import recipes and application metadata.

## Architecture & Technology

*   **Language:** Swift 5+
*   **Frameworks:** SwiftUI (UI), AppKit (Window management), Combine (Observables).
*   **Concurrency:** Heavy utilization of Swift Concurrency (`async`/`await`, `Actor`s) for thread-safe state management and network operations.

### Core Components

*   **`Juice.swift`:** The application entry point. It also contains the `Runtime` actor which currently holds hardcoded environment configuration (UEM URLs, API credentials).
*   **`ContentView.swift`:** The root UI view, managing the `NavigationSplitView` and global window effects.
*   **`UEMService` (Actor):** A singleton-like actor responsible for all communication with the Workspace ONE UEM API (fetching apps, getting org groups).
*   **`LocalCatalog`:** Manages the dataset of known "Cask" applications (source of truth for latest versions).
*   **`AppNameComparer`:** A utility for normalizing and fuzzy-matching application names to link UEM records with Cask records.

## Data Models

*   **`CaskApplication`:** Represents an application from the Homebrew Cask repository.
*   **`UemApplication`:** Represents an application deployed in the UEM environment.
*   **`Recipe`:** Represents metadata likely related to AutoPkg recipes for packaging.

## Setup & Development

### Prerequisites
*   macOS with Xcode 15+ (inferred).
*   A Workspace ONE UEM tenant (for full functionality).

### Configuration
Currently, configuration appears to be embedded directly in `Juice/Juice.swift` within the `Runtime` actor. This includes:
*   `uemUrl`
*   `clientId` / `clientSecret`
*   `orgGroupId`

*Note: For production use, these secrets should be moved to a secure configuration file or environment variables.*

### Build & Run
1.  Open `Juice.xcodeproj` in Xcode.
2.  Ensure the target `Juice` is selected.
3.  Run (Cmd+R).

## Directory Structure

*   `Juice/`: Main source directory.
    *   `Components/`: Reusable UI elements (cards, badges, buttons).
    *   `Models/`: Data structures (`JuiceModels.swift`, plus focused supporting model files).
    *   `Services/`: Business logic and API handling (`UEMService.swift`, `AuthService.swift`).
    *   `Views/`: SwiftUI views for different app screens (`LandingView`, `SearchView`, etc.).
    *   `Resources/`: JSON data files (`cask_apps.json`, `recipes.json`) acting as the local database.
*   `LiteDBExport/`: Contains raw JSON exports, likely used to seed the `Resources` directory.
