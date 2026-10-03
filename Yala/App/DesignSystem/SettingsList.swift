//
//  SettingsList.swift
//  Yala
//
//  Lista agrupada de ajustes, al estilo de los Ajustes de iOS: un bloque blanco por sección sobre el
//  fondo de la pantalla, separador fino entre filas, cabecera gris y pequeña, y la ayuda debajo del
//  bloque — no debajo de cada fila. Es una `List` del sistema (`.insetGrouped`), así que sirve tal cual
//  como columna de un lista-detalle.
//
//  Uso:
//
//      YalaSettingsList {
//          YalaSettingsSection(L10n.Settings.sectionCalendar) {
//              YalaSettingsValueRow(L10n.Settings.defaultPeriod, value: periodName) { showPicker = true }
//              YalaSettingsToggleRow(L10n.Settings.widgetHints, isOn: $prefs.showWidgetHints)
//          } footer: {
//              Text(L10n.Settings.defaultPeriodDescription)
//          }
//      }
//      .yalaScreenBackground(.subtle)
//
//  Tres decisiones (ticket `settings-redesign-as-grouped-lists-like-ios`):
//  - **El fondo de la pantalla NO es blanco y los bloques SÍ** (`theme.card`): es identidad de Yala.
//    La lista oculta su fondo (`scrollContentBackground(.hidden)`) y deja ver el de `yalaScreenBackground`.
//  - **Una fila no lleva ayuda propia.** La ayuda va en el `footer` de su sección, y solo cuando dice algo
//    que la fila no dice. Si una fila necesita su ayuda y sus vecinas no, va al final del bloque o en un
//    bloque propio sin cabecera (como «Escritura flotante» en iOS).
//  - **Ancho legible.** En una ventana ancha el contenido no pasa de `DS.Adaptive.readableWidth` y queda
//    centrado; en estrecha, el margen de siempre. Lo decide el ancho medido (`readableListMargin`).
//

import SwiftUI

// MARK: - Contenedor

struct YalaSettingsList<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var containerWidth: CGFloat = 0
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(
            .horizontal,
            DS.Adaptive.readableListMargin(containerWidth: containerWidth, sizeClass: sizeClass),
            for: .scrollContent
        )
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            containerWidth = width
        }
    }
}

// MARK: - Sección

/// Un bloque de filas. La cabecera es opcional: un bloque sin título continúa la sección de arriba
/// (el molde de iOS para la fila que lleva su propia ayuda).
struct YalaSettingsSection<Content: View, Footer: View>: View {
    @Environment(\.yalaTheme) private var theme
    private let title: String?
    private let content: Content
    private let footer: Footer

    init(
        _ title: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        Section {
            content
                .listRowBackground(theme.card)
        } header: {
            if let title {
                Text(title)
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
            }
        } footer: {
            footer
        }
    }
}

extension YalaSettingsSection where Footer == EmptyView {
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, content: content, footer: { EmptyView() })
    }
}

// MARK: - Filas

/// Fila que abre algo: título a la izquierda, valor actual en gris y chevron. Sin valor, solo el chevron.
struct YalaSettingsValueRow: View {
    private let title: String
    private let value: String?
    private let action: () -> Void

    init(_ title: String, value: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            YalaSettingsRowLabel(title: title, value: value)
        }
    }
}

/// Fila con interruptor. `accessory` va pegado al título (un `ProBadge`, por ejemplo).
struct YalaSettingsToggleRow<Accessory: View>: View {
    private let title: String
    @Binding private var isOn: Bool
    private let isDisabled: Bool
    private let accessory: Accessory

    init(
        _ title: String,
        isOn: Binding<Bool>,
        isDisabled: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self._isOn = isOn
        self.isDisabled = isDisabled
        self.accessory = accessory()
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(isDisabled ? .thSecondaryText : .thPrimaryText)
                accessory
            }
        }
        .disabled(isDisabled)
    }
}

extension YalaSettingsToggleRow where Accessory == EmptyView {
    init(_ title: String, isOn: Binding<Bool>, isDisabled: Bool = false) {
        self.init(title, isOn: isOn, isDisabled: isDisabled, accessory: { EmptyView() })
    }
}

/// La etiqueta común de una fila con valor: la usan `YalaSettingsValueRow` y los `Menu` que se pintan
/// como fila (con `chevron.up.chevron.down`).
struct YalaSettingsRowLabel: View {
    let title: String
    let value: String?
    let accessory: String

    init(title: String, value: String? = nil, accessory: String = "chevron.right") {
        self.title = title
        self.value = value
        self.accessory = accessory
    }

    var body: some View {
        HStack {
            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(.thPrimaryText)

            Spacer()

            // Colores fijos del sistema, no `.secondary`/`.tertiary`: dentro de un `Menu` o de un botón de
            // `List` esos estilos jerárquicos derivan del tinte y el valor salía en el color de acento.
            if let value {
                Text(value)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            Image(systemName: accessory)
                .font(DS.Typography.labelSmall.weight(.medium))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview("Ajustes agrupados") {
    @Previewable @State var on = true
    NavigationStack {
        YalaSettingsList {
            YalaSettingsSection("Calendario") {
                YalaSettingsValueRow("Período predeterminado", value: "Este mes") {}
                YalaSettingsValueRow("Primer día de la semana", value: "Lunes") {}
            } footer: {
                Text("Este período se aplicará por defecto cada vez que abras la app.")
            }
            YalaSettingsSection("Indicadores") {
                YalaSettingsToggleRow("Textos de ayuda", isOn: $on)
                YalaSettingsValueRow("Línea promedio", value: "Total") {}
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle("Personalización")
        .navigationBarTitleDisplayMode(.inline)
    }
}
