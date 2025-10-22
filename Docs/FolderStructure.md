# Folder Structure

This document describes the organization of the Life@USTC codebase.

## Overview

The project follows a clean architecture with clear separation between:
- **Models**: Data structures and business logic
- **Views**: User interface components
- **General**: Shared utilities and reusable components
- **Schools**: School-specific implementations

## Directory Structure

### General/ - Shared Utilities and Components

Contains reusable code that can be used throughout the application:

```
General/
├── Constants.swift              # App-wide constants and configuration
├── Keychain.swift              # Keychain access utilities
├── Extensions/                 # Swift type extensions
│   ├── DateExtension.swift
│   ├── ExceptionExtension.swift
│   ├── GenericsExtension.swift
│   ├── StringExtension.swift
│   └── UUIDExtension.swift
├── ManagedData/               # Data management framework
│   ├── AsyncStatus/           # Async operation status tracking
│   ├── ManagedData.swift
│   ├── ManagedDataSource.swift
│   └── ManagedLocalData/      # Local storage management
├── Shared/                    # Shared client code
│   ├── Client.swift
│   └── LoginClient.swift
└── ViewModifiers/             # SwiftUI view modifiers and extensions
    ├── AsyncStatusMask.swift
    ├── FeatureLabelStyle.swift
    ├── RectangleProgressBar.swift
    ├── Strips.swift
    └── SwiftUIExtension.swift
```

**Key Points:**
- `Extensions/` contains pure Swift extensions (no UI dependencies)
- `ViewModifiers/` contains SwiftUI-specific view modifiers and UI utilities
- `ManagedData/` provides the async data management framework used throughout the app

### Models/ - Data Models

Contains data structures and their associated logic:

```
Models/
├── Feed/                      # RSS feed models
│   ├── Feed.swift
│   ├── FeedDelegate.swift
│   └── FeedSource.swift
├── InAppNotification/         # In-app notification models
│   └── InAppNotification.swift
├── PushNotification/          # Push notification models
│   └── TPNSClient.swift
└── School/                    # School-related data models
    ├── Bus/
    ├── Curriculum/
    ├── Exam/
    ├── Homework/
    └── Score/
```

**Key Points:**
- Models are organized by feature/domain
- Each model may have associated delegates for data management
- School-specific models are in `School/` subdirectories

### Views/ - User Interface Components

Contains all SwiftUI views and UI components:

```
Views/
├── ContentView.swift          # Main app container
├── ContentViewTab.swift       # Tab bar component
├── HomeView.swift             # Home screen
├── FeaturesView.swift         # Features list view
├── AllSourceView.swift        # All sources view
├── SettingsView.swift         # Settings screen
├── General/                   # Feature-specific views (reusable)
│   ├── Browser.swift
│   ├── Curriculum/
│   │   ├── Card/             # Today card views
│   │   ├── Details/          # Detail and list views
│   │   └── Week/             # Week view components
│   ├── Exam/
│   │   ├── Card/             # Preview cards
│   │   └── Details/          # Detail views
│   ├── Feature/              # Feature card components
│   ├── Feed/                 # Feed views
│   ├── Homework/             # Homework views
│   ├── PushNotification/     # Notification views
│   └── Score/                # Score views
└── Settings/                  # Settings page components
    ├── AboutPage.swift
    ├── AppPage.swift
    ├── ExamPage.swift
    ├── FeedPage.swift
    ├── HomeSettingPage.swift
    └── LegalPage.swift
```

**Key Points:**
- Top-level views are in the `Views/` root
- `General/` contains reusable feature views organized by domain
- `Settings/` contains all settings-related pages
- Views are further organized into `Card/`, `Details/`, etc. based on UI patterns

### Schools/ - School-Specific Implementations

Contains school-specific code following the plugin architecture:

```
Schools/
├── Protocols/                 # Base protocols and interfaces
│   ├── ExtensionViews.swift  # Feature and settings view protocols
│   └── SchoolExport.swift    # Main school export protocol
└── USTC/                     # USTC implementation
    ├── Clients/              # API clients
    │   ├── USTC+Blackboard.swift
    │   ├── USTC+CAS.swift
    │   ├── USTC+CASWebViewController.swift
    │   └── USTC+UgAAS.swift
    ├── Delegates/            # Data delegates
    │   ├── USTC+BBHomeworkDelegate.swift
    │   ├── USTC+BusDelegate.swift
    │   ├── USTC+CurriculumDelegate.swift
    │   ├── USTC+ExamDelegate.swift
    │   └── USTC+ScoreDelegate.swift
    ├── Models/               # USTC-specific models
    │   ├── USTC+CASViewModel.swift
    │   └── USTC+WebFeatures.swift
    ├── Views/                # USTC-specific views
    │   ├── USTC+AdditionalCourse.swift
    │   ├── USTC+BusView.swift
    │   ├── USTC+CASLoginView.swift
    │   └── USTCBaseModifier.swift
    └── USTC+Exports.swift    # Main USTC export
```

**Key Points:**
- `Protocols/` defines the interface that all schools must implement
- Each school (e.g., USTC) has its own subdirectory
- School implementations follow a consistent internal structure (Clients, Delegates, Models, Views)
- This makes it easy to add support for additional schools

### Widget/ - iOS Widgets

Contains widget extensions:

```
Widget/
├── Assets/
├── CurriculumPreviewWidget.swift
├── CurriculumWeekWidget.swift
├── ExamWidget.swift
└── WidgetBundle.swift
```

## Design Principles

1. **Separation of Concerns**: Each directory has a clear, single purpose
2. **Modularity**: Code is organized into reusable modules
3. **Consistency**: Similar patterns across different features
4. **Scalability**: Easy to add new features or schools
5. **Discoverability**: Intuitive structure makes it easy to find code

## File Naming Conventions

- **Models**: PascalCase (e.g., `Exam.swift`, `CurriculumDelegate.swift`)
- **Views**: PascalCase with suffix indicating type (e.g., `ExamDetailView.swift`, `ExamPreviewCard.swift`)
- **Extensions**: TypeName + "Extension" (e.g., `DateExtension.swift`)
- **School-specific**: School prefix (e.g., `USTC+Blackboard.swift`)

## Related Documentation

- [MVC.md](./MVC.md) - Explains the Model-View-Controller architecture and AsyncDataDelegate pattern
- [Rules.md](./Rules.md) - Development rules and guidelines
