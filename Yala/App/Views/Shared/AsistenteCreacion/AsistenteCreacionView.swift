//
//  AsistenteCreacionView.swift
//  Yala
//
//  El contenedor de los asistentes de creación: una pregunta por pantalla para crear algo que se hace pocas veces y
//  trae jerga (presupuesto primero; después pago planificado, grupo, cuenta y favorito). Referencia de UI:
//  `docs/design/referencias/2026-09-15-flujo-por-pasos-cancelar-suscripcion.jpg` (progreso arriba, una pregunta grande,
//  un solo botón abajo).
//
//  Qué pinta (y por eso un asistente nuevo no lo vuelve a escribir):
//   · La barra de la hoja: la X nativa a la izquierda y «Usar formulario» a la derecha, siempre a la vista.
//   · Lo que se crea («Nuevo presupuesto») y «Paso 2 de 6» sobre el progreso en tramos; debajo, la pregunta (`title2`
//     en negrita) y su frase.
//   · Abajo, una sola fila: Atrás (círculo con flecha, desde la segunda pregunta) y el botón principal ancho
//     («Siguiente»; en la última, el verbo de crear). Nunca un botón debajo del otro, a ningún tamaño de letra.
//   · La X y el gesto de bajar la hoja, con algo respondido, preguntan antes de descartar (`Descartar` / `Seguir`).
//
//  Cómo se usa en un asistente nuevo (molde: `Presupuesto/AsistentePresupuestoView.swift`):
//   1. Un `enum` de pasos y una función pura que da los que tocan con lo respondido (las preguntas que dependen de otra
//      entran y salen de la lista). La lógica, sin vista, en un `nonisolated enum` con tests.
//   2. Lo respondido vive en un `@Observable` que crea QUIEN PRESENTA la hoja y que se tira en su `onDismiss`, con un
//      `AsistenteCreacionNavegador` dentro (regla de `swiftui-ds.md`: el contenido de una hoja puede rehacerse y
//      perder su `@State`). Cada pregunta llega con el valor sugerido ya elegido: «Siguiente» siempre sirve.
//   3. La vista del asistente monta este contenedor y pone en `contenido` la respuesta de cada pregunta, con las piezas
//      de `AsistenteCreacionPiezas.swift` (opción marcable, tarjeta, fila del resumen).
//   4. «Usar formulario» cambia el contenido de LA MISMA hoja al formulario de siempre con lo respondido pasado
//      (nunca cierra una hoja para abrir otra), y el formulario abierto así pregunta también antes de descartar.
//   5. El resumen es la última pregunta: cada respuesta se toca para cambiarla (`navegador.cambiar(_:desde:)`) y el
//      botón principal crea. Editar algo que ya existe sigue abriendo el formulario.
//   Textos del contenedor: `asistente.*` en `AsistentePresupuesto.strings` (los 16 idiomas); los del asistente, en su
//   propia tabla o con prefijo propio. Ids de XCUITest fijos: `asistente_close`, `asistente_use_form`, `asistente_back`,
//   `asistente_next`, `asistente_progress`, `asistente_question`, `asistente_discard_confirm`, `asistente_discard_keep`.
//

import SwiftUI

struct AsistenteCreacionView<Contenido: View>: View {
    /// El título de la barra: lo que se está creando («Nuevo presupuesto»).
    let titulo: String
    let pregunta: String
    let detalle: String?
    /// La pregunta actual, desde 0, y cuántas hay con lo respondido.
    let indice: Int
    let total: Int
    /// Cambia con cada pregunta: la nueva se funde y el scroll vuelve arriba.
    let identidad: String
    let tituloPrincipal: String
    let puedeSeguir: Bool
    let puedeRetroceder: Bool
    /// Hay algo respondido: la X y el gesto de bajar preguntan antes de cerrar.
    let tieneRespuestas: Bool
    /// El título del aviso de descartar («¿Descartar este presupuesto?»).
    let tituloDescartar: String
    var ocupado: Bool = false
    let alSeguir: () -> Void
    let alRetroceder: () -> Void
    let alUsarFormulario: () -> Void
    let alCerrar: () -> Void
    @ViewBuilder let contenido: () -> Contenido

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @State private var preguntaDescartar = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        AsistenteProgreso(titulo: titulo, indice: indice, total: total)
                            .id("asistente_top")
                        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                            encabezado
                            contenido()
                        }
                        .id(identidad)
                        // La nueva se funde y la anterior se va en el acto: fundidas las dos, se leían una encima de la
                        // otra (`swiftui-ds.md`, «Un Text que cambia de valor con animación se funde con el anterior»).
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xl)
                    .readableColumn()
                    .animation(reduceMotion ? nil : DS.Animation.appear, value: identidad)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: identidad) { _, _ in proxy.scrollTo("asistente_top", anchor: .top) }
            }
            .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) { botones }
            .yalaScreenBackground(.subtle)
            // El título va encima del progreso, no en la barra: con «Usar formulario» al lado se cortaba
            // («Nuevo presupue…»).
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close, action: cerrar)
                        .accessibilityIdentifier("asistente_close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarTextButton(AsistenteCreacionTexto.usarFormulario, action: alUsarFormulario)
                        .accessibilityHint(AsistenteCreacionTexto.usarFormularioPista)
                        .accessibilityIdentifier("asistente_use_form")
                }
            }
        }
        .onSheetDismissAttempt(isActive: tieneRespuestas) { preguntaDescartar = true }
        // «Seguir» es la salida segura y va como `.cancel` (siempre al final en una alerta).
        .alert(tituloDescartar, isPresented: $preguntaDescartar) {
            Button(AsistenteCreacionTexto.descartar, role: .destructive, action: alCerrar)
                .accessibilityIdentifier("asistente_discard_confirm")
            Button(AsistenteCreacionTexto.seguir, role: .cancel) {}
                .accessibilityIdentifier("asistente_discard_keep")
        } message: {
            Text(AsistenteCreacionTexto.descartarMensaje)
        }
    }

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(pregunta)
                .font(DS.Typography.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("asistente_question")
            if let detalle, !detalle.isEmpty {
                Text(detalle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Atrás y el botón principal en la MISMA fila: Atrás es un círculo, así que cabe también a AX5.
    private var botones: some View {
        HStack(spacing: DS.Spacing.sm) {
            if puedeRetroceder {
                Button(action: alRetroceder) {
                    Image(systemName: "chevron.left")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .frame(width: 52, height: 52)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(L10n.Action.back)
                .accessibilityIdentifier("asistente_back")
            }
            YalaPrimaryButton(
                tituloPrincipal,
                isDisabled: !puedeSeguir,
                isLoading: ocupado,
                keepsDisabledToneInBar: true,
                action: alSeguir
            )
            .accessibilityIdentifier("asistente_next")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
        .readableColumn()
    }

    private func cerrar() {
        if tieneRespuestas {
            preguntaDescartar = true
        } else {
            alCerrar()
        }
    }
}

// MARK: - Progreso

/// Lo que se crea y «Paso 2 de 6» en una línea, y debajo los tramos (hechos en el acento).
struct AsistenteProgreso: View {
    let titulo: String
    let indice: Int
    let total: Int

    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // A tamaños de accesibilidad, «Paso 2 de 6» baja bajo el título: al lado partía «Nuevo presu-puesto».
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    tituloTexto
                    pasoTexto
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    tituloTexto
                    Spacer(minLength: DS.Spacing.sm)
                    pasoTexto.fixedSize()
                }
            }
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(0..<max(total, 1), id: \.self) { tramo in
                    Capsule()
                        .fill(tramo <= indice ? theme.accent : Color.primary.opacity(0.15))
                        .frame(height: 4)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titulo), \(AsistenteCreacionTexto.pasoDe(indice + 1, total))")
        .accessibilityIdentifier("asistente_progress")
    }

    private var tituloTexto: some View {
        Text(titulo)
            .font(DS.Typography.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var pasoTexto: some View {
        Text(AsistenteCreacionTexto.pasoDe(indice + 1, total))
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

// MARK: - Textos del contenedor

/// Los textos del contenedor y de los asistentes, de la tabla `AsistentePresupuesto` con el idioma de la app (variante →
/// padre → main → la clave), como `ReusarRegistroText`.
enum AsistenteCreacionTexto {
    static let tabla = "AsistentePresupuesto"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        var value = resolution.bundle.localizedString(forKey: key, value: sentinel, table: tabla)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: key, value: sentinel, table: tabla)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: key, value: sentinel, table: tabla)
        }
        return value == sentinel ? key : value
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: LanguageManager.resolved.locale, arguments: args)
    }

    static var usarFormulario: String { string("asistente.useForm") }
    static var usarFormularioPista: String { string("asistente.useFormHint") }
    static func pasoDe(_ paso: Int, _ total: Int) -> String { format("asistente.stepOf", paso, total) }
    static var descartarMensaje: String { string("asistente.discard.message") }
    static var descartar: String { string("asistente.discard.confirm") }
    static var seguir: String { string("asistente.discard.keep") }
    static var cambiarPista: String { string("asistente.changeHint") }
}
