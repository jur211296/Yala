//
//  CardTemplateCatalog.swift
//  Yala
//
//  Las plantillas de tarjeta del editor de diseño (2026-11-16). Todas se dibujan con SwiftUI a partir de estos colores:
//  ni una imagen. La referencia de Jürgen (pantalla «Accounts» de otra app) es la morada con cuadrícula («Aurora») y la
//  verde con ondas («Bosque»).
//
//  Una plantilla trae sus colores y, además, una receta para teñirse con el color que elija la persona: así «Oro» con
//  un azul propio sale como un metal azulado, y «Lavanda» con un verde, como un pastel verde.
//

import Foundation

// MARK: - Grupo de la galería

nonisolated enum CardTemplateCategory: String, CaseIterable, Sendable {
    case gradients
    case metallic
    case minimal
    case dark
    case pastel
    case patterned
}

// MARK: - Receta de teñido

/// Cómo convierte una plantilla un color base en su degradado.
nonisolated enum CardTintRecipe: Sendable {
    /// Degradado intenso: más claro arriba, más hondo abajo.
    case vivid
    /// Metal: claros y oscuros alternos, para que el brillo tenga dónde lucirse.
    case metallic
    /// Pastel: el color muy aclarado.
    case pastel
    /// Oscura: el color muy oscurecido, casi negro.
    case deep
    /// Minimalista: un solo tono, apenas un matiz.
    case flat

    func stops(from base: CardRGB) -> [CardRGB] {
        switch self {
        case .vivid: return [base.lightened(0.18), base, base.darkened(0.35)]
        case .metallic: return [base.lightened(0.30), base.darkened(0.10), base.lightened(0.15), base.darkened(0.25)]
        case .pastel: return [base.lightened(0.75), base.lightened(0.60)]
        case .deep: return [base.darkened(0.55), base.darkened(0.78)]
        case .flat: return [base, base.darkened(0.06)]
        }
    }
}

// MARK: - Plantilla

nonisolated struct CardTemplate: Identifiable, Sendable {
    let id: String
    let category: CardTemplateCategory
    /// Sus colores, de arriba a la izquierda a abajo a la derecha. En «Tu color» no se usan: manda el de la cuenta.
    let stops: [CardRGB]
    let recipe: CardTintRecipe
    let pattern: CardPattern
    let finish: CardFinish
    /// «Tu color»: el degradado sale del color de la cuenta y el patrón, de su tipo.
    let usesAccountColor: Bool
    let silverChip: Bool

    init(
        _ id: String, _ category: CardTemplateCategory, _ hexes: [String], recipe: CardTintRecipe,
        pattern: CardPattern, finish: CardFinish = .flat, usesAccountColor: Bool = false, silverChip: Bool = false
    ) {
        self.id = id
        self.category = category
        self.stops = hexes.compactMap(CardRGB.init(hex:))
        self.recipe = recipe
        self.pattern = pattern
        self.finish = finish
        self.usesAccountColor = usesAccountColor
        self.silverChip = silverChip
    }
}

// MARK: - Catálogo

nonisolated enum CardTemplateCatalog {

    /// «Tu color»: la plantilla por defecto, con el color de la cuenta.
    static let accountColorID = "account"

    static let all: [CardTemplate] = [
        // Degradados
        CardTemplate(accountColorID, .gradients, ["#6366F1", "#3730A3"], recipe: .vivid, pattern: .grid,
                     finish: .glow, usesAccountColor: true),
        CardTemplate("aurora", .gradients, ["#3B1F8F", "#5B2BC4", "#8B5CF6"], recipe: .vivid, pattern: .grid,
                     finish: .glow),
        CardTemplate("forest", .gradients, ["#1E3A2B", "#2F6B47", "#4E9A6A"], recipe: .vivid, pattern: .waves),
        CardTemplate("ocean", .gradients, ["#0C3B66", "#0369A1", "#0891B2"], recipe: .vivid, pattern: .waves,
                     finish: .glow),
        CardTemplate("sunset", .gradients, ["#9A3412", "#C2410C", "#BE185D"], recipe: .vivid, pattern: .lines),
        CardTemplate("raspberry", .gradients, ["#6B0F3A", "#A3134F", "#D6255E"], recipe: .vivid, pattern: .dots),
        // Metálicas
        CardTemplate("gold", .metallic, ["#E9C770", "#B8862B", "#F2D78A", "#A8781F"], recipe: .metallic,
                     pattern: .none, finish: .metallic),
        CardTemplate("silver", .metallic, ["#EEF0F3", "#A9AFB8", "#DCE0E5", "#8E959F"], recipe: .metallic,
                     pattern: .none, finish: .metallic, silverChip: true),
        CardTemplate("graphite", .metallic, ["#4B5563", "#1F2937", "#374151", "#111827"], recipe: .metallic,
                     pattern: .none, finish: .metallic, silverChip: true),
        CardTemplate("roseGold", .metallic, ["#F2C4C0", "#C98A86", "#EBB5B0", "#B87470"], recipe: .metallic,
                     pattern: .none, finish: .metallic),
        CardTemplate("bronze", .metallic, ["#9C6A3A", "#5E3714", "#8A5A2B", "#4A2A0F"], recipe: .metallic,
                     pattern: .none, finish: .metallic),
        // Minimalistas
        CardTemplate("snow", .minimal, ["#FFFFFF", "#EEF1F6"], recipe: .flat, pattern: .none, silverChip: true),
        CardTemplate("sand", .minimal, ["#EFE6D5", "#E2D5BE"], recipe: .flat, pattern: .none),
        CardTemplate("mist", .minimal, ["#DADFE6", "#C9CFD8"], recipe: .flat, pattern: .none, silverChip: true),
        CardTemplate("ink", .minimal, ["#151517", "#0A0A0B"], recipe: .flat, pattern: .none),
        // Oscuras
        CardTemplate("midnight", .dark, ["#1E2A5A", "#0B1026"], recipe: .deep, pattern: .dots, finish: .glow),
        CardTemplate("obsidian", .dark, ["#23232E", "#0A0A0F"], recipe: .deep, pattern: .topographic),
        CardTemplate("charcoal", .dark, ["#2C2C2E", "#161618"], recipe: .deep, pattern: .lines, silverChip: true),
        CardTemplate("borealis", .dark, ["#0B3D3A", "#04211F", "#1B4F5E"], recipe: .deep, pattern: .waves,
                     finish: .glow),
        // Pastel
        CardTemplate("lavender", .pastel, ["#EDE4FF", "#CDBDFB"], recipe: .pastel, pattern: .dots),
        CardTemplate("mint", .pastel, ["#D5FAEE", "#A7EBD6"], recipe: .pastel, pattern: .waves),
        CardTemplate("peach", .pastel, ["#FFE6D8", "#FBC3A6"], recipe: .pastel, pattern: .lines),
        CardTemplate("sky", .pastel, ["#E0EDFF", "#B9D4FB"], recipe: .pastel, pattern: .grid),
        // Con patrón
        CardTemplate("neon", .patterned, ["#1A0B33", "#2E0A45", "#0B1E3D"], recipe: .deep, pattern: .grid,
                     finish: .glow),
        CardTemplate("terrain", .patterned, ["#4A4334", "#2F2A20"], recipe: .deep, pattern: .topographic),
        CardTemplate("mosaic", .patterned, ["#1E3A8A", "#312E81"], recipe: .vivid, pattern: .diamonds),
        CardTemplate("polkadot", .patterned, ["#FDE68A", "#FBBF24"], recipe: .pastel, pattern: .dots),
    ]

    static func templates(in category: CardTemplateCategory) -> [CardTemplate] {
        all.filter { $0.category == category }
    }

    /// La plantilla con ese id; una desconocida (de otra versión, o borrada) da «Tu color».
    static func template(id: String) -> CardTemplate {
        all.first { $0.id == id } ?? accountColor
    }

    static var accountColor: CardTemplate {
        // `all` siempre empieza por «Tu color» (lo fija un test).
        all[0]
    }

    // MARK: Colores e íconos del editor

    /// Los colores que ofrece el editor, además de «El de la plantilla», «El de tu cuenta» y «Otro color». Los siete del
    /// formulario de cuenta primero, para que la tarjeta pueda casar con el color que ya eligió.
    static let swatches: [String] = [
        "#FF0080", "#D62246", "#FF7F11", "#4CB963", "#6366F1", "#1B065E", "#0F172A",
        "#0EA5E9", "#10B981", "#F59E0B", "#8B5CF6", "#EC4899", "#64748B", "#B45309",
    ]

    /// Los íconos que ofrece el editor, además de «El de tu cuenta».
    static let icons: [String] = [
        "creditcard.fill", "building.columns.fill", "banknote.fill", "wallet.bifold.fill", "dollarsign.circle.fill",
        "airplane", "cart.fill", "house.fill", "car.fill", "gift.fill", "heart.fill", "star.fill",
        "briefcase.fill", "graduationcap.fill", "bag.fill", "fork.knife", "gamecontroller.fill", "leaf.fill",
        "pawprint.fill", "globe.americas.fill", "bolt.fill", "sparkles", "cup.and.saucer.fill", "lock.fill",
    ]
}
