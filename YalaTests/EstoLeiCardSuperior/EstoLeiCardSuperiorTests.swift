//
//  EstoLeiCardSuperiorTests.swift
//  YalaTests
//
//  «Esto leí» (encargo del 2026-11-23): la primera tarjeta arranca con aire bajo la cabecera, su contorno se ve sobre el
//  glass de la hoja y la media altura no deja fuera la tarjeta, la nota de la Bandeja ni «Guardar».
//

import Foundation
import SwiftUI
import Testing
@testable import Yala

private func source(_ relative: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    // Sin comentarios: documentar la regla no puede ponerla en verde ni en rojo.
    return text.split(separator: "\n", omittingEmptySubsequences: false)
        .map { line -> Substring in
            guard let range = line.range(of: "//") else { return line }
            return line[..<range.lowerBound]
        }
        .joined(separator: "\n")
}

@Suite("Esto leí · aire y borde de la primera tarjeta")
struct EstoLeiCardSuperiorTests {
    // MARK: - Aire

    @Test func elAireSobreLaPrimeraTarjeta_esElDeLosLados() {
        #expect(EstoLeiCardLayout.airAboveFirstCard == DS.Spacing.lg)
        #expect(EstoLeiCardLayout.airAboveFirstCard > DS.Spacing.xs, "Con 4 pt el borde se pegaba a la X y a la miniatura.")
    }

    @Test func laHojaDeFoto_usaEseAireSobreLoLeido() throws {
        let code = try source("Yala/App/Views/Image/ImageSelectionView.swift")
        #expect(code.contains(".padding(.top, EstoLeiCardLayout.airAboveFirstCard)"))
    }

    // MARK: - Contorno

    @Test func laTarjeta_llevaSuContorno() throws {
        let code = try source("Yala/App/Views/Voice/VoiceDraftReviewCard.swift")
        #expect(code.contains(".strokeBorder(EstoLeiCardLayout.edge, lineWidth: EstoLeiCardLayout.edgeWidth)"))
        #expect(EstoLeiCardLayout.edgeWidth >= 1)
    }

    @Test(arguments: [UIUserInterfaceStyle.dark, .light])
    func elContorno_seMarcaMasQueElDelTema(_ style: UIUserInterfaceStyle) {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let edge = UIColor(EstoLeiCardLayout.edge).resolvedColor(with: traits)
        var alpha: CGFloat = 0
        edge.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        // El `cardBorder` del tema es 0,08 en los dos modos: sobre el glass no se distinguía.
        #expect(alpha > 0.1, "Contorno demasiado tenue en \(style == .dark ? "oscuro" : "claro"): \(alpha)")
    }

    @Test func conAumentarContraste_elContornoSube() {
        let normal = UITraitCollection { $0.userInterfaceStyle = .dark; $0.accessibilityContrast = .normal }
        let high = UITraitCollection { $0.userInterfaceStyle = .dark; $0.accessibilityContrast = .high }
        var a1: CGFloat = 0, a2: CGFloat = 0
        UIColor(EstoLeiCardLayout.edge).resolvedColor(with: normal).getRed(nil, green: nil, blue: nil, alpha: &a1)
        UIColor(EstoLeiCardLayout.edge).resolvedColor(with: high).getRed(nil, green: nil, blue: nil, alpha: &a2)
        #expect(a2 > a1)
    }

    // MARK: - Media altura

    @Test func laHojaPersonal_ofreceSuMediaAltura_yGrande() {
        let detents = ImageEntrySheetHeightLogic.detents(
            showsSeveralToReview: false, dynamicTypeSize: .large, partial: ImageEntrySheetHeightLogic.estoLeiPartial)
        #expect(detents == [ImageEntrySheetHeightLogic.estoLeiPartial, .large])
        #expect(
            ImageEntrySheetHeightLogic.background(
                detents: detents, selectedDetent: ImageEntrySheetHeightLogic.estoLeiPartial, usesLargeSheets: false)
                == .transparent,
            "A media altura sigue enseñando el glass del sistema.")
        #expect(
            ImageEntrySheetHeightLogic.background(detents: detents, selectedDetent: .large, usesLargeSheets: false)
                == .subtle)
    }

    @Test func conVarios_oConTextoDeAccesibilidad_sigueSoloGrande() {
        let partial = ImageEntrySheetHeightLogic.estoLeiPartial
        #expect(ImageEntrySheetHeightLogic.detents(showsSeveralToReview: true, dynamicTypeSize: .large, partial: partial) == [.large])
        #expect(ImageEntrySheetHeightLogic.detents(showsSeveralToReview: false, dynamicTypeSize: .accessibility1, partial: partial) == [.large])
    }

    @Test func laFotoDeGrupos_sigueConLaMedium() throws {
        #expect(ImageEntrySheetHeightLogic.detents(showsSeveralToReview: false, dynamicTypeSize: .large) == [.medium, .large])
        let code = try source("Yala/App/Views/Image/ImageSelectionView.swift")
        #expect(code.contains("partial: ImageEntrySheetHeightLogic.estoLeiPartial"))
        #expect(code.contains("selectedDetent: PresentationDetent = ImageEntrySheetHeightLogic.estoLeiPartial"),
                "El detent elegido al abrir tiene que ser uno de los ofrecidos.")
    }

    /// En el iPhone SE el alto máximo de la hoja ronda los 600 pt: la `.medium` (~340) dejaba fuera la nota y los chips.
    @Test func enUnIPhonePequeno_creceHastaQueCabeLoLeido() {
        let max: CGFloat = 600
        let height = ImageEntrySheetHeightLogic.estoLeiPartialHeight(
            maxHeight: max, systemMedium: max * ImageEntrySheetHeightLogic.systemMediumFraction, dynamicTypeSize: .large)
        #expect(height == ImageEntrySheetHeightLogic.estoLeiContentHeight(dynamicTypeSize: .large))
        #expect(height > max * ImageEntrySheetHeightLogic.systemMediumFraction)
    }

    /// En un iPhone grande la `.medium` ya basta: la hoja no se hace más baja que antes.
    @Test func enUnIPhoneGrande_esLaMediumDeSiempre() {
        let max: CGFloat = 900
        let medium = max * ImageEntrySheetHeightLogic.systemMediumFraction
        let height = ImageEntrySheetHeightLogic.estoLeiPartialHeight(maxHeight: max, systemMedium: medium, dynamicTypeSize: .large)
        #expect(height == medium)
    }

    @Test func nuncaPasaDeLaHojaEntera() {
        let height = ImageEntrySheetHeightLogic.estoLeiPartialHeight(maxHeight: 400, systemMedium: 224, dynamicTypeSize: .xxxLarge)
        #expect(height == 400)
    }

    @Test func conLetraMasGrande_pideMasAlto() {
        let sizes: [DynamicTypeSize] = [.large, .xLarge, .xxLarge, .xxxLarge]
        let heights = sizes.map { ImageEntrySheetHeightLogic.estoLeiContentHeight(dynamicTypeSize: $0) }
        #expect(heights == heights.sorted() && Set(heights).count == heights.count)
    }
}
