//
//  SkeletonPlaceholder.swift
//  Yala
//
//  Placeholder visual reutilizable para estados de carga (chips, rows, etc.).
//  Usado en ChatSheetView empty state y ChatTopicsSheet mientras se carga el LLM.
//

import SwiftUI

struct SkeletonPlaceholder: View {

    let height: CGFloat
    var cornerRadius: CGFloat = DS.Radius.md
    var opacity: Double = 0.6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.thCard)
            .frame(height: height) // A11Y-DT: skeleton placeholder height
            .opacity(opacity)
    }
}
