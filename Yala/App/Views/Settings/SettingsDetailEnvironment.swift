//
//  SettingsDetailEnvironment.swift
//  Yala
//
//  UX 2.2 · L16-20 (opción C, Jürgen 2026-10-18): en el iPad, con la lista de Ajustes al lado, el ajuste abierto no
//  repite un «‹»: la lista ya es la vuelta. Cada pantalla de Ajustes pinta su propio «‹» (`YalaToolbarButton`), así que
//  `navigationBarBackButtonHidden` no lo quita; lo esconde ella misma si lee este valor.
//

import SwiftUI

extension EnvironmentValues {
    /// `true` en el primer nivel del detalle de Ajustes cuando la lista está al lado (`ProfileView`, ventana ancha). Lo
    /// que ese ajuste empuje después vuelve a `false` y lleva su «‹». Fuera de Ajustes siempre es `false`.
    @Entry var settingsListIsAlongside: Bool = false
}
