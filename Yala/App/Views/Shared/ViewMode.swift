//
//  ViewMode.swift
//  Yala
//

import Foundation

/// Modo de presentación de una vista editable.
/// `.interactive` (default): el user actúa normalmente con gestos habilitados.
/// `.demo`: auto-play scripted, gestos disabled, side effects (save, mic, picker) gateados.
enum ViewMode: Equatable {
    case interactive
    case demo

    var isDemo: Bool { self == .demo }
}
