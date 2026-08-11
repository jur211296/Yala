//
//  WelcomeNewChooserView.swift
//  Yala
//
//  Sub-chooser de "Soy nuevo" (2º nivel del Welcome, A4 de D-A7 · §k.2): dónde
//  viven los datos personales — privacidad total (iCloud) o cuenta en la nube de
//  Yala. Calco estructural de `WelcomeExistingChooserView`.
//
//  **El §k.6 de arquitectura ya no gobierna nada de esta pantalla.** Se fue en tres
//  decisiones de producto del owner, todas anotadas aquí porque este docblock era quien lo
//  citaba para justificarse:
//
//  1. (2026-08-10, chip RC) NINGUNA de las dos opciones se recomienda — el badge
//     "Recomendado" de la privacy-first ya no existe, ni en la vista ni en la etiqueta de
//     accesibilidad.
//  2. (2026-08-11, chip W2 · punto 6 de MODO-NUBE-REVISION-FLUJOS-NOTAS) el ORDEN se
//     invierte: **la nube va primero y la privada después**. §k.6 pedía privacy-first como
//     opción primaria; el owner re-decide, coherente con 1 — si ninguna se recomienda, el
//     orden es presentación y no jerarquía.
//  3. (2026-08-11, chip W2 · punto 10) la renuncia inline (`welcome.new.cloudWarning`,
//     «renuncias a la privacidad total de la otra opción») SE RETIRA: sermoneaba. La idea NO
//     desaparece del flujo — el `cloudBody` recortado dice quién puede ver los datos, y el
//     consent posterior la lleva completa.
//
//  **Dónde vive el orden, y por qué aquí.** MEDIDO: lo producía el literal de
//  `WelcomeAccountChoiceLogic.visibleNewOptions` (`[.privateAccount]` + append de
//  `.cloudAccount`), que el chip W2 dejó EXPLÍCITAMENTE fuera de alcance por ser la lógica de
//  VISIBILIDAD. Así que el orden de PANTALLA se decide en `displayOrder(_:)`, aquí abajo, y
//  esta vista es su único dueño: la lógica dice QUÉ cards hay, la vista en qué orden se ven.
//  ⚠️ Corolario para el yo-futuro: reordenar el array de `visibleNewOptions` NO cambia nada
//  de lo que se ve — cámbialo aquí.
//
//  Solo se monta con MÁS de una opción visible: con una sola (producción con el
//  percent remoto en 0, backend no configurado, o uitest sin el opt-in) el
//  container hace bypass directo (`WelcomeAccountChoiceLogic.bypass`) y este
//  screen ni se construye — el recorrido "Soy nuevo" queda byte-idéntico al de hoy.
//

import SwiftUI

struct WelcomeNewChooserView: View {

    let options: [WelcomeAccountChoiceLogic.NewOption]
    var onSelect: (WelcomeAccountChoiceLogic.NewOption) -> Void
    var onBack: () -> Void

    /// Alto NATURAL del contenido de cada card, para igualarlas (punto 11). Se mide el
    /// contenido y NO la card ya enmarcada: el `minHeight` de abajo propone más alto, pero un
    /// stack de textos no se estira ante una propuesta mayor, así que lo reportado sigue siendo
    /// lo natural y no hay realimentación (crecer → medir más → crecer). Como además puede
    /// MENGUAR, un cambio de Dynamic Type reajusta hacia abajo en vez de quedarse pegado alto.
    @State private var contentHeights: [WelcomeAccountChoiceLogic.NewOption: CGFloat] = [:]

    var body: some View {
        WelcomeFlowScreen { logoTopSpacing in
            VStack(spacing: 0) {
                Spacer(minLength: logoTopSpacing)

                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .colorMultiply(.white)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.lg)

                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.Welcome.Chooser.optionNewTitle)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(L10n.Welcome.New.subtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                Spacer(minLength: DS.Spacing.lg)

                VStack(spacing: DS.Spacing.md) {
                    ForEach(Self.displayOrder(options), id: \.self) { option in
                        optionCard(option)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .welcomeBackButton(tint: .white, action: onBack)
    }

    /// Orden de PANTALLA: la nube primero (punto 6). Es una función pura y no un `sorted` inline
    /// para que se pueda aserjar sin montar la vista — el orden es la decisión, no un detalle de
    /// layout. Filtra por pertenencia en vez de ordenar la entrada: así una opción NUEVA que
    /// alguien añada al enum no se cuela en pantalla sin decidir dónde va.
    nonisolated static func displayOrder(
        _ options: [WelcomeAccountChoiceLogic.NewOption]
    ) -> [WelcomeAccountChoiceLogic.NewOption] {
        [.cloudAccount, .privateAccount].filter(options.contains)
    }

    /// **Cards parejas (punto 11), por LAYOUT y no por copy.** MEDIDO en el simulador con el copy
    /// ya recortado: la card privada seguía una fila más alta porque su título envuelve a dos
    /// líneas y el de la nube no. Recortar el título lo arreglaría en español y volvería a
    /// romperse en alemán o polaco — el alto depende del idioma, así que la igualación tiene que
    /// ser de layout. `nil` hasta que TODAS las cards se han medido: igualar con media medición
    /// daría un salto visible en el primer frame.
    private var evenCardHeight: CGFloat? {
        let visibles = Self.displayOrder(options)
        guard visibles.count > 1,
              visibles.allSatisfy({ contentHeights[$0] != nil }) else { return nil }
        return visibles.compactMap { contentHeights[$0] }.max()
    }

    private func title(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount: L10n.Welcome.New.privateTitle
        case .cloudAccount: L10n.Welcome.New.cloudTitle
        }
    }

    private func body(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount: L10n.Welcome.New.privateBody
        case .cloudAccount: L10n.Welcome.New.cloudBody
        }
    }

    private func iconName(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount: "lock.shield.fill"
        case .cloudAccount: "icloud.fill"
        }
    }

    private func iconTint(for option: WelcomeAccountChoiceLogic.NewOption) -> Color {
        switch option {
        case .privateAccount: .neonCyan
        case .cloudAccount: .hotPink
        }
    }

    private func accessibilityIdentifier(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        switch option {
        case .privateAccount: "welcome_new_private"
        case .cloudAccount: "welcome_new_cloud"
        }
    }

    /// Las dos cards leen IGUAL: título y cuerpo, nada más. Ya van dos veces que a esta etiqueta
    /// hay que quitarle algo que la pantalla dejó de decir —el badge "Recomendado" (RC) y ahora la
    /// renuncia inline (W2)—, y en ambos casos dejarlo aquí le habría contado a VoiceOver una
    /// pantalla distinta de la que ve todo el mundo. Si un día vuelve un distintivo a una card,
    /// vuelve también aquí; mientras no lo haya, esto no se ramifica por opción.
    private func accessibilityLabel(for option: WelcomeAccountChoiceLogic.NewOption) -> String {
        "\(title(for: option)). \(body(for: option))"
    }

    private func systemIconCircle(name: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.25))
                .frame(width: 48, height: 48)
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    /// Mismo shape visual que `WelcomeExistingChooserView.optionCard` (réplica consciente: no se
    /// refactoriza el hermano para no tocar un flujo vivo por un calco).
    private func optionCard(_ option: WelcomeAccountChoiceLogic.NewOption) -> some View {
        Button {
            DS.Haptic.selection()
            onSelect(option)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                systemIconCircle(name: iconName(for: option), tint: iconTint(for: option))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title(for: option))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text(body(for: option))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { alto in
                contentHeights[option] = alto
            }
            .frame(minHeight: evenCardHeight, alignment: .leading)
            .contentShape(Rectangle())
            .welcomeFlowCard(radius: DS.Radius.xl)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: option))
        .accessibilityIdentifier(accessibilityIdentifier(for: option))
    }
}
