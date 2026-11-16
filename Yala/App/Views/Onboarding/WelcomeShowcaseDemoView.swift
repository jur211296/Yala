//
//  WelcomeShowcaseDemoView.swift
//  Yala
//
//  Bienvenida 2.3 · Y23-01 · la demo de cada función de la vitrina, con los datos de ejemplo del prototipo v35
//  (`07-welcome.js`). Las piezas entran escalonadas; con Reducir movimiento solo se funden, sin escala ni barrido.
//  Los importes salen en la moneda de la región de la persona.
//

import SwiftUI

struct WelcomeShowcaseDemoView: View {
    let demo: WelcomeShowcaseLogic.Demo
    /// Sube con cada función nueva: vuelve a lanzar la entrada escalonada.
    let turn: Int
    let reduceMotion: Bool

    @State private var shown = false

    private let currency = CurrencyDefaults.detectCurrencyFromRegion()

    var body: some View {
        // La demo es decorado: VoiceOver lee el nombre y la línea de la función, no los datos de ejemplo.
        content
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(true)
            .onAppear(perform: reveal)
            .onChange(of: turn) { _, _ in reveal() }
    }

    @ViewBuilder
    private var content: some View {
        switch demo {
        case .receipt:
            VStack(spacing: DS.Spacing.md) {
                ReceiptViewfinder(animates: !reduceMotion)
                    .frame(width: 200, height: 104)
                    .pop(shown, delay: 0, reduceMotion: reduceMotion)
                row("fork.knife", .hotPink, L10n.Showcase.demoLunch, 18.5).pop(shown, delay: 1.2, reduceMotion: reduceMotion)
            }
        case .voice:
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    VoiceWave(animates: !reduceMotion)
                    Text(L10n.Showcase.demoVoiceSaid(money(12, decimals: false)))
                }
                .bubble(user: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .pop(shown, delay: 0.1, reduceMotion: reduceMotion)
                Text(L10n.Showcase.demoVoiceDone)
                    .bubble(user: false)
                    .pop(shown, delay: 0.9, reduceMotion: reduceMotion)
                row("car.fill", .neonCyan, L10n.Showcase.demoTaxi, 12).pop(shown, delay: 1.3, reduceMotion: reduceMotion)
            }
        case .organize:
            organize
        case .splitAny:
            VStack(spacing: DS.Spacing.md) {
                row("fork.knife", .hotPink, L10n.Showcase.demoDinner, 120, sub: L10n.Showcase.demoPaidSplit)
                    .pop(shown, delay: 0, reduceMotion: reduceMotion)
                HStack(spacing: DS.Spacing.md) {
                    avatar("A", L10n.Showcase.demoYou, .electricIndigo).pop(shown, delay: 0.6, reduceMotion: reduceMotion)
                    avatar("L", "Luis", .neonCyan).pop(shown, delay: 0.75, reduceMotion: reduceMotion)
                    avatar("M", "Marta", .hotPink).pop(shown, delay: 0.9, reduceMotion: reduceMotion)
                }
            }
        case .budget:
            budget.pop(shown, delay: 0, reduceMotion: reduceMotion)
        case .whoOwes:
            VStack(spacing: DS.Spacing.sm) {
                debtRow("L", .neonCyan, L10n.Showcase.demoOwesYou("Luis"), 40, positive: true)
                    .pop(shown, delay: 0, reduceMotion: reduceMotion)
                debtRow("M", .hotPink, L10n.Showcase.demoYouOwe("Marta"), 15, positive: false)
                    .pop(shown, delay: 0.2, reduceMotion: reduceMotion)
            }
        case .settle:
            VStack(spacing: DS.Spacing.md) {
                debtRow("L", .neonCyan, L10n.Showcase.demoPaidYou("Luis"), 40, positive: false)
                    .pop(shown, delay: 0, reduceMotion: reduceMotion)
                Text(L10n.Showcase.demoAllSettled)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(Color.groupOwedAmount)
                    .pop(shown, delay: 0.6, reduceMotion: reduceMotion)
            }
        }
    }

    private var organize: some View {
        let rows: [(String, Color, String, Double)] = [
            ("cart.fill", .hotPink, L10n.Showcase.demoMarket, 86.4),
            ("car.fill", .neonCyan, L10n.Showcase.demoTaxi, 12),
            ("bolt.fill", .electricIndigo, L10n.Showcase.demoPower, 64)
        ]
        let total = rows.reduce(0) { $0 + $1.3 }
        let food = Int((86.4 / total * 100).rounded())
        let transport = Int((12 / total * 100).rounded())
        let home = 100 - food - transport
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(Array(rows.enumerated()), id: \.offset) { offset, item in
                row(item.0, item.1, item.2, item.3, compact: true)
                    .pop(shown, delay: Double(offset) * 0.1, reduceMotion: reduceMotion)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule().fill(Color.hotPink).frame(width: geo.size.width * CGFloat(food) / 100)
                    Capsule().fill(Color.neonCyan).frame(width: geo.size.width * CGFloat(transport) / 100)
                    Capsule().fill(Color.electricIndigo)
                }
            }
            .frame(height: 8)
            .pop(shown, delay: 0.8, reduceMotion: reduceMotion)
            HStack(spacing: DS.Spacing.md) {
                legend(.hotPink, "\(L10n.Showcase.demoFood) \(food) %")
                legend(.neonCyan, "\(L10n.Showcase.demoTransport) \(transport) %")
                legend(.electricIndigo, "\(L10n.Showcase.demoHome) \(home) %")
            }
            .pop(shown, delay: 1.3, reduceMotion: reduceMotion)
        }
    }

    private var budget: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.Showcase.demoFood).font(DS.Typography.bodyBold).foregroundStyle(.white)
                Spacer()
                Text(L10n.Showcase.demoPerMonth(money(600, decimals: false)))
                    .font(DS.Typography.caption).foregroundStyle(.white.opacity(0.65))
            }
            GeometryReader { geo in
                Capsule().fill(.white.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.neonCyan).frame(width: geo.size.width * (shown ? 0.19 : 0))
                    }
            }
            .frame(height: 8)
            HStack {
                Text(L10n.Showcase.demoSpentSoFar(money(113.9)))
                    .font(DS.Typography.caption).foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text(L10n.Showcase.demoLeft).font(DS.Typography.caption).foregroundStyle(.white.opacity(0.85))
            }
            Text(money(486.1))
                .font(DS.Typography.title2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .demoCard()
    }

    // MARK: - Piezas

    private func row(_ icon: String, _ tint: Color, _ title: String, _ amount: Double,
                     sub: String? = nil, compact: Bool = false) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(compact ? DS.Typography.caption : DS.Typography.subheadline)
                .foregroundStyle(.white)
                .frame(width: compact ? 26 : 32, height: compact ? 26 : 32)
                .background(tint, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(compact ? DS.Typography.subheadline : DS.Typography.bodyBold).foregroundStyle(.white)
                if let sub {
                    Text(sub).font(DS.Typography.caption).foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(money(amount))
                .font(compact ? DS.Typography.subheadline : DS.Typography.bodyBold)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, compact ? DS.Spacing.xs + DS.Spacing.xxs : DS.Spacing.sm)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }

    private func debtRow(_ initial: String, _ tint: Color, _ title: String, _ amount: Double, positive: Bool) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(initial)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: Circle())
            Text(title).font(DS.Typography.subheadline).foregroundStyle(.white)
            Spacer(minLength: DS.Spacing.sm)
            Text(money(amount))
                .font(DS.Typography.bodyBold)
                .foregroundStyle(positive ? Color.groupOwedAmount : .white)
                .monospacedDigit()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }

    private func avatar(_ initial: String, _ name: String, _ tint: Color) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(initial)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint, in: Circle())
            Text(name).font(DS.Typography.caption).foregroundStyle(.white.opacity(0.75))
            Text(money(40)).font(DS.Typography.captionMonoBold).foregroundStyle(.white)
        }
    }

    private func legend(_ tint: Color, _ text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(text).font(DS.Typography.caption).foregroundStyle(.white.opacity(0.75))
        }
    }

    private func money(_ value: Double, decimals: Bool = true) -> String {
        YalaFormatterStatic.currency(value: value, currencyCode: currency.rawValue, forceFullPrecision: decimals)
    }

    private func reveal() {
        shown = false
        // Una vuelta después, para que la entrada empiece desde el estado oculto.
        Task { @MainActor in
            shown = true
        }
    }
}

// MARK: - Visor del ticket y onda de voz

private struct ReceiptViewfinder: View {
    let animates: Bool
    @State private var scan = false

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [10, 6]))
            VStack(alignment: .leading, spacing: DS.Spacing.xs + DS.Spacing.xxs) {
                ForEach([0.9, 0.6, 0.85, 0.45], id: \.self) { width in
                    Capsule().fill(.black.opacity(0.18)).frame(width: 96 * width, height: 5)
                }
            }
            .padding(DS.Spacing.sm)
            .frame(width: 112, height: 88, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
            .padding(.top, DS.Spacing.sm)
            if animates {
                Capsule()
                    .fill(Color.neonCyan)
                    .frame(width: 150, height: 3)
                    .shadow(color: Color.neonCyan, radius: 6)
                    .offset(y: scan ? 92 : 8)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { scan = true }
                    }
            }
        }
    }
}

private struct VoiceWave: View {
    let animates: Bool
    @State private var high = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { bar in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: high ? CGFloat([10, 16, 8, 14, 9][bar]) : 6)
                    .animation(animates ? .easeInOut(duration: 0.4).repeatForever().delay(Double(bar) * 0.08) : nil,
                               value: high)
            }
        }
        .frame(height: 16)
        .onAppear { if animates { high = true } }
    }
}

// MARK: - Modificadores

private extension View {
    /// Entrada escalonada: escala y fundido; con Reducir movimiento, solo el fundido.
    func pop(_ shown: Bool, delay: Double, reduceMotion: Bool) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.92)
            .animation(.easeOut(duration: 0.35).delay(shown ? delay : 0), value: shown)
    }

    func bubble(user: Bool) -> some View {
        self
            .font(DS.Typography.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(user ? Color.electricIndigo : Color.white.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    func demoCard() -> some View {
        self
            .padding(DS.Spacing.md)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }
}
