//
//  GroupShareableSummarySheet.swift
//  Yala
//
//  El «cierre del viaje»: enseña el resumen del grupo tal y como va a salir, y lo manda por el
//  share sheet nativo. Operación de SOLO LECTURA — no escribe nada en el grupo.
//
//  Lo que se previsualiza es LA IMAGEN YA RENDERIZADA, no la vista que la origina. Cuesta lo mismo
//  y cierra un hueco que importa: lo que el usuario aprueba en pantalla es, byte a byte, lo que
//  acaba en el chat. De paso evita escalar a mano un lienzo de ancho fijo dentro de un scroll.
//
//  No confundir con «Invitar por enlace» (`GroupService.createShareLink`, CKShare): aquel comparte
//  el ACCESO al grupo; esto comparte una foto de cómo quedaron las cuentas. Son dos «compartir»
//  distintos y por eso ni el copy ni los nombres se parecen.
//

import SwiftUI

struct GroupShareableSummarySheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    /// Escala del device. Sin ella `ImageRenderer` rasteriza a 1×, y la imagen llega pixelada a
    /// cualquier pantalla Retina.
    @Environment(\.displayScale) private var displayScale

    // MARK: - Input

    let group: SplitGroup
    let viewModel: GroupDetailViewModel

    // MARK: - State

    @State private var rendered: UIImage?
    @State private var didFailToRender = false
    @State private var isSharing = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.xl)
                                    .stroke(.thCardBorder, lineWidth: 1)
                            )
                            .accessibilityLabel(L10n.Groups.ShareableSummary.title)
                            // Sin esto, VoiceOver anuncia el título del sheet dos veces y no da un
                            // solo dato: el usuario compartiría un artefacto que no puede verificar.
                            // El texto sale del modelo, que ya está formateado.
                            .accessibilityValue(accessibilitySummary)
                            .accessibilityIdentifier("group_summary_preview")
                    } else if didFailToRender {
                        // Con acción: el copy dice «inténtalo otra vez» y `.task` no vuelve a correr
                        // por su cuenta, así que sin botón la única salida sería cerrar y reabrir.
                        YalaEmptyState(
                            icon: "exclamationmark.triangle",
                            title: L10n.Groups.ShareableSummary.renderFailed,
                            actionTitle: L10n.Action.retry,
                            action: {
                                didFailToRender = false
                                renderCard()
                            },
                            actionAccessibilityIdentifier: "group_summary_retry_button"
                        )
                    } else {
                        ProgressView()
                            .padding(.vertical, DS.Spacing.xxl)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                // El botón solo existe cuando hay imagen: compartir «lo que se esté generando»
                // mandaría un adjunto vacío al chat.
                if rendered != nil {
                    YalaPrimaryButton(
                        L10n.Groups.ShareableSummary.action,
                        icon: "square.and.arrow.up"
                    ) {
                        isSharing = true
                    }
                    .accessibilityIdentifier("group_summary_share_button")
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
            // Después del `safeAreaInset` y no antes — molde de `GroupSplitSelectorView`, el otro
            // sheet `.subtle` con barra inferior. Al revés, la barra queda fuera del contenedor que
            // pinta el fondo y sólo se salva por cómo reexpande el `ignoresSafeArea` de dentro.
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.ShareableSummary.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            // `onDismiss` de respaldo Y `completion`: la regla 1 de presentaciones prohíbe que el
            // reset del flag dependa sólo de que UIKit desmonte la cadena. Molde de
            // `ImportIntroSheet`, que ya usa los dos.
            .sheet(isPresented: $isSharing, onDismiss: { isSharing = false }) {
                if let rendered {
                    ActivityView(
                        activityItems: [rendered],
                        completion: { _ in isSharing = false }
                    )
                }
            }
            .task { renderCard() }
        }
    }

    // MARK: - Render

    /// Altura máxima del bitmap, en píxeles. El techo de textura de las GPU de Apple está en 16 384
    /// px y `Image(uiImage:)` tiene que subir el resultado a una capa, así que quedarse en la mitad
    /// deja margen y mantiene el bitmap en tamaños sanos.
    private static let maxRenderedHeight: CGFloat = 8_000

    /// Rasteriza la tarjeta una sola vez, al abrir. Síncrono a propósito: `ImageRenderer` es
    /// `@MainActor` y su contenido es una `View` (no `Sendable`), así que no hay forma legítima de
    /// sacarlo del hilo principal. Por eso la defensa disponible no es hacerlo asíncrono, sino
    /// **acotar el tamaño**: el ancho es fijo, pero el alto crece con miembros × monedas y nadie lo
    /// limitaba. Un grupo de 40 personas en 4 divisas da ~13 000 pt de alto: a escala 3 son 38 940 px
    /// —más del doble del techo de textura— y un bitmap RGBA de ~336 MB, con el pico real más alto
    /// todavía cuando el share sheet lo codifica a PNG.
    private func renderCard() {
        let renderer = ImageRenderer(content: GroupShareableSummaryCard(model: makeRenderModel()))

        // `render` con el closure de dibujo sin invocar sirve para MEDIR el contenido sin rasterizar
        // nada: es lo que permite elegir la escala sabiendo ya el alto.
        var contentHeight: CGFloat = 0
        renderer.render { size, _ in contentHeight = size.height }

        renderer.scale = renderScale(forContentHeight: contentHeight)

        guard let image = renderer.uiImage, image.size.width > 0, image.size.height > 0 else {
            didFailToRender = true
            return
        }
        rendered = image
    }

    /// Escala de rasterizado: la del device, con dos topes.
    ///
    /// El primero es 2× en vez de 3×. El comentario original justificaba 3× por el ancho («2160 px,
    /// nítido en cualquier chat»), pero el ancho nunca fue el eje en riesgo y el argumento se vuelve
    /// en contra: las apps de mensajería recomprimen a ~1 600 px de lado largo, así que el tercio
    /// extra se tira igual y cuesta el 55 % del bitmap.
    ///
    /// El segundo es el alto: si a 2× la imagen pasaría de `maxRenderedHeight`, se baja la escala lo
    /// justo para caber. Se prefiere perder nitidez a perder filas — recortar el contenido de un
    /// resumen de dinero sería peor que verlo pequeño.
    private func renderScale(forContentHeight height: CGFloat) -> CGFloat {
        let base = min(displayScale, 2)
        guard height > 0 else { return base }
        return min(base, max(1, Self.maxRenderedHeight / height))
    }

    /// Pasa del snapshot numérico al de strings. El formateo ocurre AQUÍ, donde las preferencias
    /// están disponibles, porque la tarjeta se rasteriza fuera del árbol y allí no se pueden leer
    /// (ver cabecera de `GroupShareableSummaryCard`).
    private func makeRenderModel() -> GroupShareableSummaryRenderModel {
        let snapshot = GroupShareableSummaryLogic.build(
            group: group,
            members: viewModel.members,
            expenses: viewModel.expenses,
            shares: viewModel.shares,
            settlements: viewModel.settlements,
            unknownMemberName: L10n.Groups.ShareableSummary.unknownMember
        )

        return GroupShareableSummaryRenderModel(
            groupName: snapshot.groupName,
            iconName: snapshot.iconName,
            colorHex: snapshot.colorHex,
            dateText: Self.dateText(for: .now),
            blocks: snapshot.blocks.map { block in
                GroupShareableSummaryRenderModel.Block(
                    id: block.id,
                    currencyCode: block.currencyCode,
                    total: block.hasSpending ? money(block.totalSpent, block.currencyCode) : nil,
                    members: block.members.map { member in
                        GroupShareableSummaryRenderModel.MemberRow(
                            id: member.id,
                            name: member.displayName,
                            paid: money(member.paid, block.currencyCode),
                            owed: money(member.owed, block.currencyCode)
                        )
                    },
                    payments: block.payments.map { payment in
                        GroupShareableSummaryRenderModel.PaymentRow(
                            id: payment.id,
                            fromName: payment.fromName,
                            toName: payment.toName,
                            // «≈» cuando el importe viene de convertir otra divisa, igual que hace
                            // la pestaña Balances: es una conversión al cambio de hoy, no una cifra
                            // exacta, y la imagen se queda con ella para siempre.
                            amount: money(
                                payment.amount,
                                block.currencyCode,
                                isEstimate: block.paymentsAreConverted
                            )
                        )
                    },
                    showsPayments: block.showsPayments
                )
            }
        )
    }

    /// `forceFullPrecision` a propósito: quien tenga la app puesta en «sin decimales» vería aquí
    /// pagos redondeados que no cuadran con lo que hay que transferir de verdad. En una pantalla eso
    /// se resuelve mirando otra vez; en una imagen que ya está en el chat del grupo, no.
    private func money(_ value: Double, _ currencyCode: String, isEstimate: Bool = false) -> String {
        appPreferences.currency(
            value,
            currencyCode: currencyCode,
            forceFullPrecision: true,
            isEstimate: isEstimate
        )
    }

    /// Lo que VoiceOver lee de la imagen. La imagen es el entregable de esta pantalla: sin esto,
    /// quien la usa con lector de pantalla comparte algo que no puede comprobar. Se arma del mismo
    /// modelo que se pinta, así que no puede divergir de lo que sale en la foto.
    private var accessibilitySummary: String {
        let model = makeRenderModel()
        var parts: [String] = [model.groupName, model.dateText]
        for block in model.blocks {
            if let total = block.total {
                parts.append("\(L10n.Groups.ShareableSummary.totalSpent): \(total)")
            }
            for row in block.members {
                parts.append(
                    "\(row.name) — \(L10n.Groups.ShareableSummary.paidLabel) \(row.paid), "
                    + "\(L10n.Groups.ShareableSummary.owedLabel) \(row.owed)"
                )
            }
            guard block.showsPayments else { continue }
            if block.payments.isEmpty {
                parts.append(L10n.Groups.ShareableSummary.allSettled)
            } else {
                parts.append(L10n.Groups.ShareableSummary.settleUp)
                for row in block.payments {
                    parts.append("\(row.fromName) → \(row.toName): \(row.amount)")
                }
            }
        }
        return parts.joined(separator: ". ")
    }

    private static func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
