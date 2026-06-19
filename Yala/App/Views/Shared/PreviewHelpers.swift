//
//  PreviewHelpers.swift
//  Yala
//
//  SwiftUI #Preview helpers — keep boilerplate out of preview blocks.
//

import SwiftUI

extension View {
    /// Inyecta una instancia fresca de `AppPreferences` para usar en `#Preview`.
    /// Útil tras la migración a `@Environment(AppPreferences.self)` en views.
    /// No gated por #if DEBUG — el macro `#Preview` se expande en Release y
    /// necesita resolver el símbolo en compile time.
    func previewAppPreferences() -> some View {
        environment(AppPreferences())
    }
}
