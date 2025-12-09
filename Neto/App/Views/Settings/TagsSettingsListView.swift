//
//  TagsSettingsListView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

struct TagsSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]

    @State private var isPresentingCreateTag = false
    @State private var tagToEdit: Tag?

    private var activeTags: [Tag] {
        tags.filter { $0.isActive }
    }

    private var inactiveTags: [Tag] {
        tags.filter { !$0.isActive }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    if tags.isEmpty {
                        emptyState
                    } else {
                        if !activeTags.isEmpty {
                            tagsSection(title: "Activas", tags: activeTags)
                        }

                        if !inactiveTags.isEmpty {
                            tagsSection(title: "Inactivas", tags: inactiveTags)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Etiquetas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingCreateTag = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingCreateTag) {
            TagFormView()
        }
        .sheet(item: $tagToEdit) { tag in
            TagFormView(tagToEdit: tag)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No tienes etiquetas")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Crea etiquetas para organizar tus transacciones de forma flexible.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 64)
    }

    @ViewBuilder
    private func tagsSection(title: String, tags: [Tag]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                    Button {
                        tagToEdit = tag
                    } label: {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)

                    if index < tags.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }

    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorForHex(tag.colorHex))
                .frame(width: 12, height: 12)

            Text(tag.name)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}
