# Technology Stack

**Analysis Date:** 2026-01-15

## Languages

**Primary:**
- Swift 5.0 - All application code (`Yala.xcodeproj/project.pbxproj`)

**Secondary:**
- None (pure Swift project)

## Runtime

**Environment:**
- iOS 26.1+ (deployment target in `Yala.xcodeproj/project.pbxproj`)
- Xcode project (.xcodeproj)

**Package Manager:**
- Swift Package Manager (SPM)
- Dependencies in `Yala.xcodeproj/project.pbxproj` (XCRemoteSwiftPackageReference)

## Frameworks

**Core:**
- SwiftUI - Primary UI framework (`Yala/App/YalaApp.swift`, all Views)
- SwiftData - Persistence layer (`Yala/App/YalaApp.swift`)
- Charts - Data visualization (`Yala/App/Views/Statistics/`, `Yala/App/Views/Panel/`)

**Platform:**
- Foundation - Core utilities
- PhotosUI - Photo selection (`Yala/App/Views/Profile/PersonalDetailsView.swift`)
- UniformTypeIdentifiers - File type handling
- BackgroundTasks - Daily refresh (`Yala/Services/BackgroundJobs.swift`)

**Testing:**
- Testing framework (new Swift Testing with `@Test` macro)
- XCTest for UI tests

**Build/Dev:**
- Xcode (project-based, not workspace)
- No additional build tools

## Key Dependencies

**External (SPM):**
- CoreXLSX v0.14.2+ - Excel file import/export (`Yala.xcodeproj/project.pbxproj`)

**Infrastructure:**
- URLSession - Native HTTP client for API calls
- No third-party networking library

## Configuration

**Environment:**
- `Yala/Secrets.xcconfig` - API keys (gitignored)
- API key injected via `EXCHANGE_RATE_API_KEY` build setting
- `Yala/Resources/Info.plist` - App metadata, background modes

**Build:**
- `Yala.xcodeproj/project.pbxproj` - Build settings
- SWIFT_VERSION = 5.0
- CLANG_ENABLE_MODULES = YES
- ENABLE_PREVIEWS = YES

**Bundle Identifiers:**
- Main app: `com.jurgenschmidt.yala.dev`
- Unit tests: `com.jurgenschmidt.YalaTests`
- UI tests: `com.jurgenschmidt.YalaUITests`

## Platform Requirements

**Development:**
- macOS with Xcode
- iOS Simulator for testing

**Production:**
- iOS 26.1+
- iPhone only (no iPad/Mac targets detected)

---

*Stack analysis: 2026-01-15*
*Update after major dependency changes*
