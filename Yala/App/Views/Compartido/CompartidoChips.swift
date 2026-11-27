//
//  CompartidoChips.swift
//  Yala
//
//  Los chips «Grupos | Personas» bajo el título grande de Compartido (lote 1, 26-nov-2026), con el patrón de
//  Planificación (`PlanningView.navigationChipsBar`): `NavigationChipButton` con el nombre en los dos, dentro de
//  `navigationChipsInset`. Y la lista de Personas, con «Ver liquidadas (N)» al pie, con el pliegue de «Ver archivados».
//

import SwiftUI

/// El chip elegido en Compartido.
enum CompartidoChip: String, CaseIterable, Identifiable, Sendable {
    case groups
    case people

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groups: L10n.Compartido.chipGroups
        case .people: L10n.Compartido.chipPeople
        }
    }

    var icon: String {
        switch self {
        case .groups: "person.3.fill"
        case .people: "person.fill"
        }
    }
}

/// La fila de chips. Como en Planificación, los dos enseñan su nombre y el cambio llega sin animación.
struct CompartidoChipsBar: View {
    @Binding var selection: CompartidoChip

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(CompartidoChip.allCases) { chip in
                    NavigationChipButton(
                        title: chip.title, icon: chip.icon, isSelected: selection == chip,
                        showsTitleWhenUnselected: true
                    ) {
                        selection = chip
                    }
                    .accessibilityIdentifier("compartido_chip_\(chip == .groups ? "grupos" : "personas")")
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .fadesTowardVerticalBar()
        // Al pulsar, el cristal del chip se hincha por encima de su cápsula: sin recorte, como en Planificación.
        .scrollClipDisabled()
    }
}

/// La lista del chip Personas: las personas con algo pendiente y, al pie, las liquidadas plegadas.
struct CompartidoPeopleList: View {
    let people: CompartidoPersonasLogic.Result
    @Binding var showsSettled: Bool
    /// Abre el detalle de una persona (lote 2).
    var onOpen: ((CompartidoPersonasLogic.Person) -> Void)?

    var body: some View {
        LazyVStack(spacing: DS.Spacing.lg) {
            if people.active.isEmpty {
                emptyLine
            }
            ForEach(people.active) { person in
                CompartidoPersonCard(person: person, onOpen: onOpen.map { open in { open(person) } })
                    .accessibilityIdentifier("compartido_person_card")
            }
            if !people.settled.isEmpty {
                settledSection
            }
        }
    }

    /// Nadie con algo pendiente: lo dice con una línea, sin tarjeta de pasos (esa es la de la pestaña sin grupos).
    private var emptyLine: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Compartido.peopleEmptyTitle)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)
            Text(L10n.Compartido.peopleEmptyMessage)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("compartido_people_empty")
    }

    /// El mismo pliegue que «Ver archivados (N)» de Grupos.
    private var settledSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                showsSettled.toggle()
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: showsSettled ? "chevron.down" : "chevron.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                    Text(showsSettled
                         ? L10n.Compartido.hideSettled
                         : L10n.Compartido.showSettled(people.settled.count))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        // En seco, como el de archivados: fundido, los dos textos quedarían uno encima del otro.
                        .transaction { $0.animation = nil }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("compartido_settled_toggle")

            if showsSettled {
                ForEach(people.settled) { person in
                    CompartidoPersonCard(person: person, onOpen: onOpen.map { open in { open(person) } })
                        .opacity(0.6)
                        .accessibilityIdentifier("compartido_settled_card")
                }
            }
        }
    }
}
