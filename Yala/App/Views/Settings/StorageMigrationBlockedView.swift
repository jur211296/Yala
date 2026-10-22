//
//  StorageMigrationBlockedView.swift
//  Yala
//
//  La hoja que dice por qué «Migrar a la nube» no siguió: la cuenta ya tiene finanzas personales, el dispositivo usa otra
//  cuenta para sus grupos, la cuenta volvió a iCloud (ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`),
//  o la sesión puede ser de la persona anterior (`fresh-start-keeps-a-groups-session-that-migrate-promotes`).
//
//  Hoja y no `.alert`, a propósito: «Usar otra cuenta» abre la elección de Apple/Google, que cuelga del mismo anchor, y la
//  cadena segura entre dos presentaciones pasa por el `onDismiss` de la primera (regla 4 de presentaciones). Un `.alert` no
//  tiene `onDismiss`.
//
//  Pura: no cierra sesión ni arranca nada. Los textos salen de `L10n.Storage.MigrateBlock`, y el caller
//  (`StorageSettingsView`) baja la hoja y decide en su `onDismiss`.
//

import SwiftUI

struct StorageMigrationBlockedView: View {
    let block: MigrationIdentityBlock
    /// «Usar otra cuenta». Solo se pinta con `block.offersAnotherAccount`.
    var onUseAnotherAccount: () -> Void
    /// «Entendido».
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer(minLength: DS.Spacing.xxl)

                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 52)) // A11Y-DT: icono decorativo hero, tamaño fijo intencional (patrón StorageSignInChooserView)
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .accessibilityHidden(true)

                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Storage.MigrateBlock.title(for: block.reason))
                            .font(DS.Typography.title2)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("storage_migrate_block_title")
                        Text(L10n.Storage.MigrateBlock.body(
                            for: block.reason,
                            offersAnotherAccount: block.offersAnotherAccount,
                            associatedEmail: block.associatedEmail))
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)
                            .accessibilityIdentifier("storage_migrate_block_body")
                    }

                    VStack(spacing: DS.Spacing.md) {
                        if block.showsAppleSameAccountNote {
                            Text(L10n.Storage.MigrateBlock.appleSameAccountNote)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("storage_migrate_block_apple_note")
                        }
                        if block.offersAnotherAccount {
                            YalaPrimaryButton(L10n.Storage.MigrateBlock.useAnotherAccount,
                                              icon: "person.crop.circle.badge.plus") {
                                onUseAnotherAccount()
                            }
                            .accessibilityIdentifier("storage_migrate_block_use_another")
                            YalaSecondaryButton(L10n.Common.understood) {
                                onClose()
                            }
                            .accessibilityIdentifier("storage_migrate_block_close")
                        } else {
                            YalaPrimaryButton(L10n.Common.understood) {
                                onClose()
                            }
                            .accessibilityIdentifier("storage_migrate_block_close")
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)

                    Spacer(minLength: DS.Spacing.xxl)
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationBarTitleDisplayMode(.inline)
        }
        // Sin `accessibilityIdentifier` en el contenedor: pisaría los de los botones (`.claude/rules/testing.md`). La hoja se
        // reconoce por `storage_migrate_block_title`.
    }
}
