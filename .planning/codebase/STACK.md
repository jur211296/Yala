# Technology Stack

**Analysis Date:** 2026-01-13

## Languages

**Primary:**
- Swift 5.0 - All application code (`Neto.xcodeproj/project.pbxproj`)

**Secondary:**
- None (pure Swift project)

## Runtime

**Environment:**
- iOS 26.1+ (deployment target in `Neto.xcodeproj/project.pbxproj`)
- Xcode project (.xcodeproj)

**Package Manager:**
- Swift Package Manager (SPM)
- Dependencies in `Neto.xcodeproj/project.pbxproj` (XCRemoteSwiftPackageReference)

## Frameworks

**Core:**
- SwiftUI - Primary UI framework (`Neto/App/NetoApp.swift`, all Views)
- SwiftData - Persistence layer (`Neto/App/NetoApp.swift`)
- Charts - Data visualization (`Neto/App/Views/Statistics/`, `Neto/App/Views/Panel/`)

**Platform:**
- Foundation - Core utilities
- PhotosUI - Photo selection (`Neto/App/Views/Profile/PersonalDetailsView.swift`)
- UniformTypeIdentifiers - File type handling
- BackgroundTasks - Daily refresh (`Neto/Services/BackgroundJobs.swift`)

**Testing:**
- Testing framework (new Swift Testing with `@Test` macro)
- XCTest for UI tests

**Build/Dev:**
- Xcode (project-based, not workspace)
- No additional build tools

## Key Dependencies

**External (SPM):**
- CoreXLSX v0.14.2+ - Excel file import/export (`Neto.xcodeproj/project.pbxproj`)

**Infrastructure:**
- URLSession - Native HTTP client for API calls
- No third-party networking library

## Configuration

**Environment:**
- `Neto/Secrets.xcconfig` - API keys (gitignored)
- API key injected via `EXCHANGE_RATE_API_KEY` build setting
- `Neto/Resources/Info.plist` - App metadata, background modes

**Build:**
- `Neto.xcodeproj/project.pbxproj` - Build settings
- SWIFT_VERSION = 5.0
- CLANG_ENABLE_MODULES = YES
- ENABLE_PREVIEWS = YES

**Bundle Identifiers:**
- Main app: `com.jurgenschmidt.finaria.dev`
- Unit tests: `com.jurgenschmidt.NetoTests`
- UI tests: `com.jurgenschmidt.NetoUITests`

## Platform Requirements

**Development:**
- macOS with Xcode
- iOS Simulator for testing

**Production:**
- iOS 26.1+
- iPhone only (no iPad/Mac targets detected)

---

*Stack analysis: 2026-01-13*
*Update after major dependency changes*
