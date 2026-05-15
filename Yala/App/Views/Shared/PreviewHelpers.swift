//
//  PreviewHelpers.swift
//  Yala
//
//  SwiftUI #Preview helpers — keep boilerplate out of preview blocks.
//

#if DEBUG
import SwiftUI

extension View {
    /// Inyecta una instancia fresca de `AppPreferences` para usar en `#Preview`.
    /// Útil tras la migración a `@Environment(AppPreferences.self)` en views.
    func previewAppPreferences() -> some View {
        environment(AppPreferences())
    }
}
#endif
