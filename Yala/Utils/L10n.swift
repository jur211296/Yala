//
//  L10n.swift
//  Yala
//
//  Localization helper for type-safe string access.
//

import Foundation

// MARK: - Language Manager

extension Notification.Name {
    /// Fired when the user's language override changes (locally or via iCloud KV sync).
    /// Observers should invalidate cached strings/locale and force re-render.
    static let languageDidChange = Notification.Name("LanguageDidChange")
}

/// Single point of truth para bundle Y locale juntos. Evita divergencia entre
/// formatters (que leen `AppLocale.current`) y strings (que leen `LanguageManager.bundle`).
struct LocaleResolution {
    let bundle: Bundle
    let parentBundle: Bundle?
    let locale: Locale
}

/// Manages in-app language override for users whose device language is not supported.
/// Consume `SupportedLocale` como single source of truth — añadir un idioma se hace
/// agregando case en `SupportedLocale.swift`, no aquí.
///
/// **Storage:** App Group suite (compartido con widgets) + iCloud KV (sync cross-device).
/// Migración one-shot desde `UserDefaults.standard` ejecutada en `bootstrapMigrationIfNeeded`.
enum LanguageManager {
    static let overrideKey = "appLanguageOverride"
    private static let migrationSentinelKey = "appLanguageOverrideMigratedV1"

    /// App Group suite — compartido con widgets, share extension y procesos hermanos.
    /// Si por alguna razón el suite no está disponible, fallback a `UserDefaults.standard`.
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) ?? .standard
    }

    /// Supported locales as the typed enum. Use `.code/.nativeName/.flag` properties.
    static var supportedLanguages: [SupportedLocale] { SupportedLocale.selectableCases }

    /// Whether the device's preferred language is one of our supported locales.
    static var deviceLanguageIsSupported: Bool {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return SupportedLocale.from(preferred) != nil
    }

    /// User's language override (nil = use system language).
    /// Setter persiste en App Group + iCloud KV y emite `.languageDidChange`.
    /// No-op si `newValue == oldValue` (evita iKV.synchronize() bloqueante + notif spam).
    static var overrideLanguage: String? {
        get { sharedDefaults.string(forKey: overrideKey) }
        set {
            guard newValue != sharedDefaults.string(forKey: overrideKey) else { return }
            sharedDefaults.set(newValue, forKey: overrideKey)
            let iKV = NSUbiquitousKeyValueStore.default
            if let value = newValue {
                iKV.set(value, forKey: overrideKey)
            } else {
                iKV.removeObject(forKey: overrideKey)
            }
            iKV.synchronize()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    /// Best guess for pre-selecting a language when the device language is not supported.
    /// Falls back to English if no match found.
    static var closestSupportedLanguage: String {
        SupportedLocale.bestMatch(
            forPreferredLanguages: Locale.preferredLanguages,
            region: Locale.current.region?.identifier
        ).code
    }

    /// Bundle for loading localized strings (override or main)
    static var bundle: Bundle {
        resolved.bundle
    }

    /// Resolución completa de bundle + parentBundle + locale para el override actual.
    /// `parentBundle` se usa en `ls()` para fallback variante→padre cuando una key
    /// no existe en la variante (iOS NO hace este fallback automáticamente al cargar
    /// `Bundle(path:)` directamente).
    static var resolved: LocaleResolution {
        if let override = overrideLanguage,
           let overrideLocale = SupportedLocale(rawValue: override),
           let overrideBundle = bundleFor(overrideLocale) {
            let parentBundle = overrideLocale.parent.flatMap { bundleFor($0) }
            return LocaleResolution(
                bundle: overrideBundle,
                parentBundle: parentBundle,
                locale: Locale(identifier: override)
            )
        }
        let systemLocale: Locale = {
            if let preferred = Locale.preferredLanguages.first,
               SupportedLocale.from(preferred) != nil {
                return Locale(identifier: preferred)
            }
            return Locale(identifier: "en_US")
        }()
        return LocaleResolution(bundle: .main, parentBundle: nil, locale: systemLocale)
    }

    private static func bundleFor(_ locale: SupportedLocale) -> Bundle? {
        guard let path = Bundle.main.path(forResource: locale.bundleResourceName, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        return bundle
    }

    // MARK: - Migration (one-shot)

    /// Aliases legacy a remappear a su variante canónica cuando ya existen.
    /// Tipo enum-to-enum (no raw strings) para que un rename del case detecte el drift.
    private static let aliasRemap: [SupportedLocale: SupportedLocale] = [
        .pt: .ptBR,
        .es: .es419
    ]

    /// Migra el override desde `UserDefaults.standard` al App Group suite y remappea
    /// aliases legacy (`pt` → `pt-BR`, `es` → `es-419`) a su variante canónica.
    /// Llamar al inicio del app launch, después de `PreferenceSyncService.bootstrap()`.
    /// Idempotente vía `migrationSentinelKey`.
    static func bootstrapMigrationIfNeeded() {
        let suite = sharedDefaults

        // Step 1: standard → App Group (corre solo la primera vez).
        if !suite.bool(forKey: migrationSentinelKey) {
            let legacy = UserDefaults.standard.string(forKey: overrideKey)
            if let legacy {
                suite.set(legacy, forKey: overrideKey)
                UserDefaults.standard.removeObject(forKey: overrideKey)
            }
            suite.set(true, forKey: migrationSentinelKey)

            #if DEBUG
            print("LanguageManager: Migrated legacy override '\(legacy ?? "nil")' from standard → App Group")
            #endif
        }

        // Step 2: alias remap. Idempotente — si el valor ya es canónico, no hace nada.
        if let current = suite.string(forKey: overrideKey),
           let alias = SupportedLocale(rawValue: current),
           let canonical = aliasRemap[alias] {
            suite.set(canonical.code, forKey: overrideKey)
            NSUbiquitousKeyValueStore.default.set(canonical.code, forKey: overrideKey)
            NSUbiquitousKeyValueStore.default.synchronize()

            #if DEBUG
            print("LanguageManager: Remapped legacy alias '\(current)' → '\(canonical.code)'")
            #endif
        }
    }
}

/// Localized string lookup con fallback chain manual: variante → padre → main → key.
/// iOS NO hace este fallback automáticamente cuando se carga `Bundle(path:)` para
/// una variante regional, así que componemos cada nivel manualmente.
private func ls(_ key: String, comment: String = "") -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"

    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: comment)
    if variantValue != sentinel { return variantValue }

    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: comment)
        if parentValue != sentinel { return parentValue }
    }

    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: comment)
    if mainValue != sentinel { return mainValue }

    return key
}

// MARK: - Multi-locale lookup

extension L10n {
    /// Conjunto de TODOS los valores de `key` a través de los locales soportados.
    ///
    /// Barre cada `.lproj` directamente (no la cadena `ls()` del idioma actual), así que
    /// captura el nombre persistido aunque la app haya cambiado de idioma desde que se sembró
    /// una entidad. Cubre además los padres de variantes regionales porque esos también
    /// están en `SupportedLocale.allCases`. Usado para resolver entidades de sistema (que se
    /// persisten con su nombre localizado) por identidad de rol en vez de por idioma actual.
    static func allLocalizedValues(forKey key: String) -> Set<String> {
        let sentinel = "__YALA_MISSING__"
        var values: Set<String> = []
        for locale in SupportedLocale.allCases {
            guard let path = Bundle.main.path(forResource: locale.bundleResourceName, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { continue }
            let value = bundle.localizedString(forKey: key, value: sentinel, table: nil)
            if value != sentinel { values.insert(value) }
        }
        return values
    }
}

// MARK: - Localized Strings

/// Namespace for localized strings.
/// Usage: L10n.Panel.accounts or L10n.Trend.balance
enum L10n {

    // MARK: - Panel

    enum Panel {
        static var accounts: String {
            ls("panel.accounts", comment: "Accounts section title")
        }
        static var widgets: String {
            ls("panel.widgets", comment: "Widgets section title")
        }
        static var sectionHealth: String {
            ls("panel.section.health", comment: "Panel 2.0 Salud financiera section title")
        }
        static var sectionTendencias: String {
            ls("panel.section.tendencias", comment: "Panel 2.0 Tendencias section title")
        }
        static var sectionDistribucion: String {
            ls("panel.section.distribucion", comment: "Panel 2.0 Distribución section title")
        }
        static var sectionPlanificacion: String {
            ls("panel.section.planificacion", comment: "Panel 2.0 Planificación section title")
        }
        static var sectionLatestRecords: String {
            ls("panel.section.latestRecords", comment: "Panel 2.0 Últimos registros section title")
        }
        static var sectionTools: String {
            ls("panel.section.tools", comment: "Panel 2.0 Herramientas section title")
        }

        // MARK: - P20-11 Section footer CTAs

        static var seeMoreInTrends: String {
            ls("panel.seeMoreInTrends", comment: "P20-11 CTA at the bottom of the Tendencias section — navigates to Statistics")
        }
        static var seeMoreInDistribution: String {
            ls("panel.seeMoreInDistribution", comment: "P20-11 CTA at the bottom of the Distribución section — navigates to Statistics")
        }
        static var seeAllRecords: String {
            ls("panel.seeAllRecords", comment: "P20-11 CTA at the bottom of the Últimos registros section — navigates to Records")
        }
        static var seeBudgets: String {
            ls("panel.seeBudgets", comment: "P20-11 per-widget CTA below Budgets in Planificación — navigates to Budgets")
        }
        static var seeScheduledPayments: String {
            ls("panel.seeScheduledPayments", comment: "P20-11 per-widget CTA below Scheduled Payments in Planificación")
        }
        static var seeMoreHintTrends: String {
            ls("panel.seeMoreHint.trends", comment: "P20-11 VoiceOver hint for Tendencias CTA")
        }
        static var seeMoreHintDistribution: String {
            ls("panel.seeMoreHint.distribution", comment: "P20-11 VoiceOver hint for Distribución CTA")
        }
        static var seeMoreHintRecords: String {
            ls("panel.seeMoreHint.records", comment: "P20-11 VoiceOver hint for Últimos registros CTA")
        }
        static var seeMoreHintBudgets: String {
            ls("panel.seeMoreHint.budgets", comment: "P20-11 VoiceOver hint for Budgets CTA")
        }
        static var seeMoreHintScheduled: String {
            ls("panel.seeMoreHint.scheduled", comment: "P20-11 VoiceOver hint for Scheduled Payments CTA")
        }

        // MARK: - P20-11 Widget size picker

        enum WidgetSize {
            static var small: String {
                ls("panel.widgetSize.small", comment: "Widget size picker — small label")
            }
            static var medium: String {
                ls("panel.widgetSize.medium", comment: "P20-11 M/L size picker — medium label")
            }
            static var large: String {
                ls("panel.widgetSize.large", comment: "P20-11 M/L size picker — large label")
            }
        }

        // MARK: - Panel Polish #2 — Widget Info Sheets (sheet pedagógica)

        enum WidgetInfo {
            static var addToPanel: String {
                ls("panel.widgetInfo.addToPanel", comment: "Panel Polish #2 — CTA en sheet pedagógica para restaurar widget oculto")
            }

            enum CashFlow {
                static var title: String {
                    ls("panel.widgetInfo.cashFlow.title", comment: "Panel Polish #2 — Title sheet pedagógico CashFlow")
                }
                static var chip1: String {
                    ls("panel.widgetInfo.cashFlow.chip1", comment: "Panel Polish #2 — Chip 1 CashFlow")
                }
                static var chip2: String {
                    ls("panel.widgetInfo.cashFlow.chip2", comment: "Panel Polish #2 — Chip 2 CashFlow")
                }
                static var chip3: String {
                    ls("panel.widgetInfo.cashFlow.chip3", comment: "Panel Polish #2 — Chip 3 CashFlow")
                }
                static var chip4: String {
                    ls("panel.widgetInfo.cashFlow.chip4", comment: "Panel Polish #2 — Chip 4 CashFlow (Interactiva — solo en large)")
                }
                // Q&A — small (sin interacción)
                static var smallWhatQ: String {
                    ls("panel.widgetInfo.cashFlow.smallWhatQ", comment: "Panel Polish #2 — CashFlow S: pregunta '¿Qué estás viendo?'")
                }
                static var smallWhatA: String {
                    ls("panel.widgetInfo.cashFlow.smallWhatA", comment: "Panel Polish #2 — CashFlow S: respuesta a '¿Qué estás viendo?'")
                }
                // Q&A — medium (sin interacción, mismo contenido más espacioso)
                static var mediumWhatQ: String {
                    ls("panel.widgetInfo.cashFlow.mediumWhatQ", comment: "Panel Polish #2 — CashFlow M: pregunta '¿Qué estás viendo?'")
                }
                static var mediumWhatA: String {
                    ls("panel.widgetInfo.cashFlow.mediumWhatA", comment: "Panel Polish #2 — CashFlow M: respuesta a '¿Qué estás viendo?'")
                }
                // Q&A — large (chart con scrubbing)
                static var largeWhatQ: String {
                    ls("panel.widgetInfo.cashFlow.largeWhatQ", comment: "Panel Polish #2 — CashFlow L: pregunta '¿Qué estás viendo?'")
                }
                static var largeWhatA: String {
                    ls("panel.widgetInfo.cashFlow.largeWhatA", comment: "Panel Polish #2 — CashFlow L: respuesta a '¿Qué estás viendo?'")
                }
                static var largeHowQ: String {
                    ls("panel.widgetInfo.cashFlow.largeHowQ", comment: "Panel Polish #2 — CashFlow L: pregunta '¿Cómo interactúo con la gráfica?'")
                }
                static var largeHowA: String {
                    ls("panel.widgetInfo.cashFlow.largeHowA", comment: "Panel Polish #2 — CashFlow L: respuesta a '¿Cómo interactúo con la gráfica?'")
                }
                // Q&A — común a las 3 sizes
                static var balanceQ: String {
                    ls("panel.widgetInfo.cashFlow.balanceQ", comment: "Panel Polish #2 — CashFlow: pregunta '¿Qué es el balance?' (común a S/M/L)")
                }
                static var balanceA: String {
                    ls("panel.widgetInfo.cashFlow.balanceA", comment: "Panel Polish #2 — CashFlow: respuesta a '¿Qué es el balance?'")
                }
            }

            enum Trend {
                static var title: String {
                    ls("panel.widgetInfo.trend.title", comment: "Panel Polish #2 — Title sheet pedagógico Trend")
                }
                static var chip1: String {
                    ls("panel.widgetInfo.trend.chip1", comment: "Panel Polish #2 — Chip 1 Trend")
                }
                static var chip2: String {
                    ls("panel.widgetInfo.trend.chip2", comment: "Panel Polish #2 — Chip 2 Trend")
                }
                // Q&A — small (sin interacción)
                static var smallWhatQ: String {
                    ls("panel.widgetInfo.trend.smallWhatQ", comment: "Panel Polish #2 — Trend S: pregunta '¿Qué estás viendo?'")
                }
                static var smallWhatA: String {
                    ls("panel.widgetInfo.trend.smallWhatA", comment: "Panel Polish #2 — Trend S: respuesta a '¿Qué estás viendo?'")
                }
                // Q&A — large (chart con scrubbing + selector métrica)
                static var largeWhatQ: String {
                    ls("panel.widgetInfo.trend.largeWhatQ", comment: "Panel Polish #2 — Trend L: pregunta '¿Qué estás viendo?'")
                }
                static var largeWhatA: String {
                    ls("panel.widgetInfo.trend.largeWhatA", comment: "Panel Polish #2 — Trend L: respuesta a '¿Qué estás viendo?'")
                }
                static var largeHowQ: String {
                    ls("panel.widgetInfo.trend.largeHowQ", comment: "Panel Polish #2 — Trend L: pregunta '¿Cómo interactúo con la gráfica?'")
                }
                static var largeHowA: String {
                    ls("panel.widgetInfo.trend.largeHowA", comment: "Panel Polish #2 — Trend L: respuesta a '¿Cómo interactúo con la gráfica?'")
                }
                // Q&A — FX coherence (live balance multi-currency fix)
                static var fxMatchQ: String {
                    ls("panel.widgetInfo.trend.fxMatchQ", comment: "Live Balance — Trend M/L: pregunta sobre por qué el último punto puede no coincidir con el saldo total")
                }
                static var fxMatchA: String {
                    ls("panel.widgetInfo.trend.fxMatchA", comment: "Live Balance — Trend M/L: respuesta sobre fluctuación cambiaria")
                }
            }

            // MARK: - Bloque 1 (Pies + Need)

            enum CategoriesPie {
                static var title: String { ls("panel.widgetInfo.categoriesPie.title", comment: "Panel Polish #2 — Title sheet pedagógico CategoriesPie") }
                static var chip1: String { ls("panel.widgetInfo.categoriesPie.chip1", comment: "Panel Polish #2 — Chip 1 CategoriesPie (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.categoriesPie.chip2", comment: "Panel Polish #2 — Chip 2 CategoriesPie (período)") }
                static var chip3: String { ls("panel.widgetInfo.categoriesPie.chip3", comment: "Panel Polish #2 — Chip 3 CategoriesPie (Interactiva)") }
                static var smallWhatQ: String { ls("panel.widgetInfo.categoriesPie.smallWhatQ", comment: "Panel Polish #2 — CategoriesPie S: pregunta '¿Qué estás viendo?'") }
                static var smallWhatA: String { ls("panel.widgetInfo.categoriesPie.smallWhatA", comment: "Panel Polish #2 — CategoriesPie S: respuesta") }
                static var smallHowQ: String { ls("panel.widgetInfo.categoriesPie.smallHowQ", comment: "Panel Polish #2 — CategoriesPie S: pregunta '¿Cómo interactúo?'") }
                static var smallHowA: String { ls("panel.widgetInfo.categoriesPie.smallHowA", comment: "Panel Polish #2 — CategoriesPie S: respuesta a 'cómo interactúo'") }
                static var largeWhatQ: String { ls("panel.widgetInfo.categoriesPie.largeWhatQ", comment: "Panel Polish #2 — CategoriesPie L: pregunta '¿Qué estás viendo?'") }
                static var largeWhatA: String { ls("panel.widgetInfo.categoriesPie.largeWhatA", comment: "Panel Polish #2 — CategoriesPie L: respuesta") }
                static var largeHowQ: String { ls("panel.widgetInfo.categoriesPie.largeHowQ", comment: "Panel Polish #2 — CategoriesPie L: pregunta '¿Cómo interactúo con la gráfica?'") }
                static var largeHowA: String { ls("panel.widgetInfo.categoriesPie.largeHowA", comment: "Panel Polish #2 — CategoriesPie L: respuesta a 'cómo interactúo'") }
            }

            enum SubcategoriesPie {
                static var title: String { ls("panel.widgetInfo.subcategoriesPie.title", comment: "Panel Polish #2 — Title sheet pedagógico SubcategoriesPie") }
                static var chip1: String { ls("panel.widgetInfo.subcategoriesPie.chip1", comment: "Panel Polish #2 — Chip 1 SubcategoriesPie (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.subcategoriesPie.chip2", comment: "Panel Polish #2 — Chip 2 SubcategoriesPie (período)") }
                static var chip3: String { ls("panel.widgetInfo.subcategoriesPie.chip3", comment: "Panel Polish #2 — Chip 3 SubcategoriesPie (Interactiva)") }
                static var smallWhatQ: String { ls("panel.widgetInfo.subcategoriesPie.smallWhatQ", comment: "Panel Polish #2 — SubcategoriesPie S: pregunta") }
                static var smallWhatA: String { ls("panel.widgetInfo.subcategoriesPie.smallWhatA", comment: "Panel Polish #2 — SubcategoriesPie S: respuesta") }
                static var smallHowQ: String { ls("panel.widgetInfo.subcategoriesPie.smallHowQ", comment: "Panel Polish #2 — SubcategoriesPie S: pregunta") }
                static var smallHowA: String { ls("panel.widgetInfo.subcategoriesPie.smallHowA", comment: "Panel Polish #2 — SubcategoriesPie S: respuesta") }
                static var largeWhatQ: String { ls("panel.widgetInfo.subcategoriesPie.largeWhatQ", comment: "Panel Polish #2 — SubcategoriesPie L: pregunta") }
                static var largeWhatA: String { ls("panel.widgetInfo.subcategoriesPie.largeWhatA", comment: "Panel Polish #2 — SubcategoriesPie L: respuesta") }
                static var largeHowQ: String { ls("panel.widgetInfo.subcategoriesPie.largeHowQ", comment: "Panel Polish #2 — SubcategoriesPie L: pregunta '¿Cómo interactúo con la gráfica?'") }
                static var largeHowA: String { ls("panel.widgetInfo.subcategoriesPie.largeHowA", comment: "Panel Polish #2 — SubcategoriesPie L: respuesta") }
            }

            enum TagsPie {
                static var title: String { ls("panel.widgetInfo.tagsPie.title", comment: "Panel Polish #2 — Title sheet pedagógico TagsPie") }
                static var chip1: String { ls("panel.widgetInfo.tagsPie.chip1", comment: "Panel Polish #2 — Chip 1 TagsPie (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.tagsPie.chip2", comment: "Panel Polish #2 — Chip 2 TagsPie (período)") }
                static var chip3: String { ls("panel.widgetInfo.tagsPie.chip3", comment: "Panel Polish #2 — Chip 3 TagsPie (Interactiva)") }
                static var smallWhatQ: String { ls("panel.widgetInfo.tagsPie.smallWhatQ", comment: "Panel Polish #2 — TagsPie S: pregunta") }
                static var smallWhatA: String { ls("panel.widgetInfo.tagsPie.smallWhatA", comment: "Panel Polish #2 — TagsPie S: respuesta") }
                static var smallHowQ: String { ls("panel.widgetInfo.tagsPie.smallHowQ", comment: "Panel Polish #2 — TagsPie S: pregunta") }
                static var smallHowA: String { ls("panel.widgetInfo.tagsPie.smallHowA", comment: "Panel Polish #2 — TagsPie S: respuesta") }
                static var largeWhatQ: String { ls("panel.widgetInfo.tagsPie.largeWhatQ", comment: "Panel Polish #2 — TagsPie L: pregunta") }
                static var largeWhatA: String { ls("panel.widgetInfo.tagsPie.largeWhatA", comment: "Panel Polish #2 — TagsPie L: respuesta") }
                static var largeHowQ: String { ls("panel.widgetInfo.tagsPie.largeHowQ", comment: "Panel Polish #2 — TagsPie L: pregunta") }
                static var largeHowA: String { ls("panel.widgetInfo.tagsPie.largeHowA", comment: "Panel Polish #2 — TagsPie L: respuesta") }
            }

            // MARK: - Bloque 2 (Tops)

            enum TopCategories {
                static var title: String { ls("panel.widgetInfo.topCategories.title", comment: "Panel Polish #2 — Title sheet pedagógico TopCategories") }
                static var chip1: String { ls("panel.widgetInfo.topCategories.chip1", comment: "Panel Polish #2 — Chip 1 TopCategories (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.topCategories.chip2", comment: "Panel Polish #2 — Chip 2 TopCategories (período)") }
                static var chip3: String { ls("panel.widgetInfo.topCategories.chip3", comment: "Panel Polish #2 — Chip 3 TopCategories (Interactiva)") }
                static var smallWhatQ: String { ls("panel.widgetInfo.topCategories.smallWhatQ", comment: "Panel Polish #2 — TopCategories S: pregunta") }
                static var smallWhatA: String { ls("panel.widgetInfo.topCategories.smallWhatA", comment: "Panel Polish #2 — TopCategories S: respuesta") }
                static var regularWhatQ: String { ls("panel.widgetInfo.topCategories.regularWhatQ", comment: "Panel Polish #2 — TopCategories M/L: pregunta (compartida)") }
                static var regularWhatA: String { ls("panel.widgetInfo.topCategories.regularWhatA", comment: "Panel Polish #2 — TopCategories M/L: respuesta (compartida)") }
                static var howQ: String { ls("panel.widgetInfo.topCategories.howQ", comment: "Panel Polish #2 — TopCategories: pregunta '¿Cómo interactúo?' (compartida S/M/L)") }
                static var howA: String { ls("panel.widgetInfo.topCategories.howA", comment: "Panel Polish #2 — TopCategories: respuesta a 'cómo interactúo' (compartida S/M/L)") }
            }

            enum TopSubcategories {
                static var title: String { ls("panel.widgetInfo.topSubcategories.title", comment: "Panel Polish #2 — Title sheet pedagógico TopSubcategories") }
                static var chip1: String { ls("panel.widgetInfo.topSubcategories.chip1", comment: "Panel Polish #2 — Chip 1 TopSubcategories (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.topSubcategories.chip2", comment: "Panel Polish #2 — Chip 2 TopSubcategories (período)") }
                static var chip3: String { ls("panel.widgetInfo.topSubcategories.chip3", comment: "Panel Polish #2 — Chip 3 TopSubcategories (Interactiva)") }
                static var smallWhatQ: String { ls("panel.widgetInfo.topSubcategories.smallWhatQ", comment: "Panel Polish #2 — TopSubcategories S: pregunta") }
                static var smallWhatA: String { ls("panel.widgetInfo.topSubcategories.smallWhatA", comment: "Panel Polish #2 — TopSubcategories S: respuesta") }
                static var regularWhatQ: String { ls("panel.widgetInfo.topSubcategories.regularWhatQ", comment: "Panel Polish #2 — TopSubcategories M/L: pregunta (compartida)") }
                static var regularWhatA: String { ls("panel.widgetInfo.topSubcategories.regularWhatA", comment: "Panel Polish #2 — TopSubcategories M/L: respuesta (compartida)") }
                static var howQ: String { ls("panel.widgetInfo.topSubcategories.howQ", comment: "Panel Polish #2 — TopSubcategories: pregunta '¿Cómo interactúo?' (compartida S/M/L)") }
                static var smallHowA: String { ls("panel.widgetInfo.topSubcategories.smallHowA", comment: "Panel Polish #2 — TopSubcategories S: respuesta a 'cómo interactúo' (sin selector)") }
                static var regularHowA: String { ls("panel.widgetInfo.topSubcategories.regularHowA", comment: "Panel Polish #2 — TopSubcategories M/L: respuesta a 'cómo interactúo' (con selector)") }
            }

            // MARK: - Bloque 3 (Listas)

            enum RecentRecords {
                static var title: String { ls("panel.widgetInfo.recentRecords.title", comment: "Panel Polish #2 — Title sheet pedagógico RecentRecords") }
                static var chip1: String { ls("panel.widgetInfo.recentRecords.chip1", comment: "Panel Polish #2 — Chip 1 RecentRecords (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.recentRecords.chip2", comment: "Panel Polish #2 — Chip 2 RecentRecords (período)") }
                static var whatQ: String { ls("panel.widgetInfo.recentRecords.whatQ", comment: "Panel Polish #2 — RecentRecords: pregunta") }
                static var whatA: String { ls("panel.widgetInfo.recentRecords.whatA", comment: "Panel Polish #2 — RecentRecords: respuesta") }
            }

            enum ScheduledPayments {
                static var title: String { ls("panel.widgetInfo.scheduledPayments.title", comment: "Panel Polish #2 — Title sheet pedagógico ScheduledPayments") }
                static var chip1: String { ls("panel.widgetInfo.scheduledPayments.chip1", comment: "Panel Polish #2 — Chip 1 ScheduledPayments (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.scheduledPayments.chip2", comment: "Panel Polish #2 — Chip 2 ScheduledPayments (mes en curso)") }
                static var chip3: String { ls("panel.widgetInfo.scheduledPayments.chip3", comment: "Panel Polish #2 — Chip 3 ScheduledPayments (Interactiva)") }
                static var whatQ: String { ls("panel.widgetInfo.scheduledPayments.whatQ", comment: "Panel Polish #2 — ScheduledPayments: pregunta '¿Qué estás viendo?' (compartida S/M)") }
                static var smallWhatA: String { ls("panel.widgetInfo.scheduledPayments.smallWhatA", comment: "Panel Polish #2 — ScheduledPayments S: respuesta") }
                static var mediumWhatA: String { ls("panel.widgetInfo.scheduledPayments.mediumWhatA", comment: "Panel Polish #2 — ScheduledPayments M: respuesta") }
                static var howQ: String { ls("panel.widgetInfo.scheduledPayments.howQ", comment: "Panel Polish #2 — ScheduledPayments: pregunta '¿Cómo interactúo?' (compartida S/M)") }
                static var smallHowA: String { ls("panel.widgetInfo.scheduledPayments.smallHowA", comment: "Panel Polish #2 — ScheduledPayments S: respuesta a 'cómo interactúo'") }
                static var mediumHowA: String { ls("panel.widgetInfo.scheduledPayments.mediumHowA", comment: "Panel Polish #2 — ScheduledPayments M: respuesta a 'cómo interactúo'") }
            }

            enum Budgets {
                static var title: String { ls("panel.widgetInfo.budgets.title", comment: "Panel Polish #2 — Title sheet pedagógico Budgets") }
                static var chip1: String { ls("panel.widgetInfo.budgets.chip1", comment: "Panel Polish #2 — Chip 1 Budgets (Favoritos)") }
                static var chip2: String { ls("panel.widgetInfo.budgets.chip2", comment: "Panel Polish #2 — Chip 2 Budgets (período)") }
                static var chip3: String { ls("panel.widgetInfo.budgets.chip3", comment: "Panel Polish #2 — Chip 3 Budgets (Interactiva)") }
                static var smallWhatQ: String { ls("panel.widgetInfo.budgets.smallWhatQ", comment: "Panel Polish #2 — Budgets S: pregunta") }
                static var smallWhatA: String { ls("panel.widgetInfo.budgets.smallWhatA", comment: "Panel Polish #2 — Budgets S: respuesta") }
                static var regularWhatQ: String { ls("panel.widgetInfo.budgets.regularWhatQ", comment: "Panel Polish #2 — Budgets M/L: pregunta (compartida)") }
                static var regularWhatA: String { ls("panel.widgetInfo.budgets.regularWhatA", comment: "Panel Polish #2 — Budgets M/L: respuesta (compartida)") }
                static var howQ: String { ls("panel.widgetInfo.budgets.howQ", comment: "Panel Polish #2 — Budgets: pregunta '¿Cómo interactúo?' (compartida S/M/L)") }
                static var howA: String { ls("panel.widgetInfo.budgets.howA", comment: "Panel Polish #2 — Budgets: respuesta a 'cómo interactúo' (compartida S/M/L)") }
            }

            // MARK: - Bloque 4 (Misc)

            enum ExchangeRate {
                static var title: String { ls("panel.widgetInfo.exchangeRate.title", comment: "Panel Polish #2 — Title sheet pedagógico ExchangeRate") }
                static var chip1: String { ls("panel.widgetInfo.exchangeRate.chip1", comment: "Panel Polish #2 — Chip 1 ExchangeRate (multi-divisa)") }
                static var chip2: String { ls("panel.widgetInfo.exchangeRate.chip2", comment: "Panel Polish #2 — Chip 2 ExchangeRate (tasas actuales)") }
                static var chip3: String { ls("panel.widgetInfo.exchangeRate.chip3", comment: "Panel Polish #2 — Chip 3 ExchangeRate (Interactiva)") }
                static var whatQ: String { ls("panel.widgetInfo.exchangeRate.whatQ", comment: "Panel Polish #2 — ExchangeRate: pregunta") }
                static var whatA: String { ls("panel.widgetInfo.exchangeRate.whatA", comment: "Panel Polish #2 — ExchangeRate: respuesta") }
                static var howQ: String { ls("panel.widgetInfo.exchangeRate.howQ", comment: "Panel Polish #2 — ExchangeRate: pregunta '¿Cómo interactúo con la gráfica?'") }
                static var howA: String { ls("panel.widgetInfo.exchangeRate.howA", comment: "Panel Polish #2 — ExchangeRate: respuesta a 'cómo interactúo'") }
                // Q&A — balance impact (live balance multi-currency fix)
                static var balanceImpactQ: String { ls("panel.widgetInfo.exchangeRate.balanceImpactQ", comment: "Live Balance — ExchangeRate: pregunta sobre cómo el TC afecta al balance") }
                static var balanceImpactA: String { ls("panel.widgetInfo.exchangeRate.balanceImpactA", comment: "Live Balance — ExchangeRate: respuesta sobre cómo el TC afecta al balance") }
            }

            enum WeekdayBar {
                static var title: String { ls("panel.widgetInfo.weekdayBar.title", comment: "Panel Polish #2 — Title sheet pedagógico WeekdayBar") }
                static var chip1: String { ls("panel.widgetInfo.weekdayBar.chip1", comment: "Panel Polish #2 — Chip 1 WeekdayBar (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.weekdayBar.chip2", comment: "Panel Polish #2 — Chip 2 WeekdayBar (período)") }
                static var whatQ: String { ls("panel.widgetInfo.weekdayBar.whatQ", comment: "Panel Polish #2 — WeekdayBar: pregunta '¿Qué estás viendo?' (compartida S/L)") }
                static var smallWhatA: String { ls("panel.widgetInfo.weekdayBar.smallWhatA", comment: "Panel Polish #2 — WeekdayBar S: respuesta") }
                static var largeWhatA: String { ls("panel.widgetInfo.weekdayBar.largeWhatA", comment: "Panel Polish #2 — WeekdayBar L: respuesta") }
            }

            enum ExpensesByNeed {
                static var title: String { ls("panel.widgetInfo.expensesByNeed.title", comment: "Panel Polish #2 — Title sheet pedagógico ExpensesByNeed") }
                static var chip1: String { ls("panel.widgetInfo.expensesByNeed.chip1", comment: "Panel Polish #2 — Chip 1 ExpensesByNeed (entidad)") }
                static var chip2: String { ls("panel.widgetInfo.expensesByNeed.chip2", comment: "Panel Polish #2 — Chip 2 ExpensesByNeed (período)") }
                static var chip3: String { ls("panel.widgetInfo.expensesByNeed.chip3", comment: "Panel Polish #2 — Chip 3 ExpensesByNeed (Interactiva)") }
                static var smallWhatQ: String { ls("panel.widgetInfo.expensesByNeed.smallWhatQ", comment: "Panel Polish #2 — ExpensesByNeed S: pregunta") }
                static var smallWhatA: String { ls("panel.widgetInfo.expensesByNeed.smallWhatA", comment: "Panel Polish #2 — ExpensesByNeed S: respuesta") }
                static var smallHowQ: String { ls("panel.widgetInfo.expensesByNeed.smallHowQ", comment: "Panel Polish #2 — ExpensesByNeed S: pregunta") }
                static var smallHowA: String { ls("panel.widgetInfo.expensesByNeed.smallHowA", comment: "Panel Polish #2 — ExpensesByNeed S: respuesta") }
                static var mediumWhatQ: String { ls("panel.widgetInfo.expensesByNeed.mediumWhatQ", comment: "Panel Polish #2 — ExpensesByNeed M: pregunta") }
                static var mediumWhatA: String { ls("panel.widgetInfo.expensesByNeed.mediumWhatA", comment: "Panel Polish #2 — ExpensesByNeed M: respuesta") }
                static var mediumHowQ: String { ls("panel.widgetInfo.expensesByNeed.mediumHowQ", comment: "Panel Polish #2 — ExpensesByNeed M: pregunta") }
                static var mediumHowA: String { ls("panel.widgetInfo.expensesByNeed.mediumHowA", comment: "Panel Polish #2 — ExpensesByNeed M: respuesta") }
                static var largeWhatQ: String { ls("panel.widgetInfo.expensesByNeed.largeWhatQ", comment: "Panel Polish #2 — ExpensesByNeed L: pregunta") }
                static var largeWhatA: String { ls("panel.widgetInfo.expensesByNeed.largeWhatA", comment: "Panel Polish #2 — ExpensesByNeed L: respuesta") }
                static var largeHowQ: String { ls("panel.widgetInfo.expensesByNeed.largeHowQ", comment: "Panel Polish #2 — ExpensesByNeed L: pregunta '¿Cómo interactúo con la gráfica?'") }
                static var largeHowA: String { ls("panel.widgetInfo.expensesByNeed.largeHowA", comment: "Panel Polish #2 — ExpensesByNeed L: respuesta") }
            }

            enum PeriodComparison {
                static var title: String { ls("panel.widgetInfo.periodComparison.title", comment: "Stats Trends — Title sheet pedagógico Comparativa de período") }
                static var chip1: String { ls("panel.widgetInfo.periodComparison.chip1", comment: "Stats Trends — Chip 1 Comparativa (Comparación)") }
                static var chip2: String { ls("panel.widgetInfo.periodComparison.chip2", comment: "Stats Trends — Chip 2 Comparativa (Por período)") }
                static var whatQ: String { ls("panel.widgetInfo.periodComparison.whatQ", comment: "Stats Trends — Comparativa: pregunta '¿Qué estás viendo?'") }
                static var whatA: String { ls("panel.widgetInfo.periodComparison.whatA", comment: "Stats Trends — Comparativa: respuesta") }
                static var howQ: String { ls("panel.widgetInfo.periodComparison.howQ", comment: "Stats Trends — Comparativa: pregunta '¿Con qué comparo?'") }
                static var howA: String { ls("panel.widgetInfo.periodComparison.howA", comment: "Stats Trends — Comparativa: respuesta") }
            }

            enum Sankey {
                static var title: String { ls("panel.widgetInfo.sankey.title", comment: "Stats Categories — Title sheet pedagógico Sankey (Flujo del dinero)") }
                static var chip1: String { ls("panel.widgetInfo.sankey.chip1", comment: "Stats Categories — Chip 1 Sankey (Flujo)") }
                static var chip2: String { ls("panel.widgetInfo.sankey.chip2", comment: "Stats Categories — Chip 2 Sankey (Por necesidad)") }
                static var chip3: String { ls("panel.widgetInfo.sankey.chip3", comment: "Stats Categories — Chip 3 Sankey (Interactiva)") }
                static var whatQ: String { ls("panel.widgetInfo.sankey.whatQ", comment: "Stats Categories — Sankey: pregunta '¿Qué estás viendo?'") }
                static var whatA: String { ls("panel.widgetInfo.sankey.whatA", comment: "Stats Categories — Sankey: respuesta") }
                static var howQ: String { ls("panel.widgetInfo.sankey.howQ", comment: "Stats Categories — Sankey: pregunta '¿Cómo interactúo?'") }
                static var howA: String { ls("panel.widgetInfo.sankey.howA", comment: "Stats Categories — Sankey: respuesta") }
            }
        }

        // MARK: - Panorama group (Cuentas + Salud financiera)

        static var panoramaTitle: String {
            ls("panel.panorama.title", comment: "Collapsible group title that wraps Accounts + Financial Health")
        }
        static var panoramaExpand: String {
            ls("panel.panorama.expand", comment: "VoiceOver action — expand Tu panorama")
        }
        static var panoramaCollapse: String {
            ls("panel.panorama.collapse", comment: "VoiceOver action — collapse Tu panorama")
        }
        static var panoramaCollapsedValue: String {
            ls("panel.panorama.collapsedValue", comment: "Accessibility value when Tu panorama is collapsed")
        }
        static var panoramaExpandedValue: String {
            ls("panel.panorama.expandedValue", comment: "Accessibility value when Tu panorama is expanded")
        }
        /// Resumen mostrado bajo el título de Tus finanzas cuando la sección
        /// está colapsada. Pluraliza por número de cuentas activas.
        static func panoramaCollapsedSummary(_ totalBalance: String, accounts: Int) -> String {
            String.localizedStringWithFormat(
                ls("panel.panorama.collapsedSummary", comment: "Subtitle under panorama title when collapsed: balance + active account count"),
                totalBalance,
                accounts
            )
        }

        static var weekdaySubtitle: String {
            ls("panel.weekdaySubtitle", comment: "Panel weekday widget subtitle — follows selected period")
        }

        enum WeekdayBar {
            /// Title shown in `.small` variant of the weekday bar widget.
            static var smallTitle: String {
                ls("panel.weekdayBar.smallTitle", comment: "Weekday bar widget title shown in the .small size — 'Day of the week'")
            }
            /// Title shown in `.large` / full-width variant of the weekday bar widget.
            static var largeTitle: String {
                ls("panel.weekdayBar.largeTitle", comment: "Weekday bar widget full-width title — 'Average spend by weekday'")
            }
            /// Inline suffix after the weekly KPI amount (e.g. "PEN 1,234 /semana").
            static var perWeekSuffix: String {
                ls("panel.weekdayBar.perWeekSuffix", comment: "Inline suffix after the weekly average amount in .small")
            }
        }

        enum FilterBar {
            /// Section title shown above the active-filter chips when at least
            /// one filter is applied. Hidden entirely when there are no chips.
            static var sectionTitle: String {
                ls("panel.filterBar.sectionTitle", comment: "Section title for the Panel's active-filter chips strip — 'Applied filters'")
            }
        }

        enum PeriodComparison {
            static func vs(_ month: String) -> String {
                String(format: ls("panel.periodComparison.vs %@", comment: "Delta chip 'vs [month]' when current and previous share year"), month)
            }
            static func vsWithYear(_ month: String, _ year: String) -> String {
                String(format: ls("panel.periodComparison.vsWithYear %@ %@", comment: "Delta chip 'vs [month] [yy]' when previous is from a different year"), month, year)
            }
            static var requiresPeriod: String {
                ls("panel.periodComparison.requiresPeriod", comment: "Empty state shown when period is all-time — no bounded previous interval")
            }
        }

        enum SectionsConfig {
            static var title: String { ls("panel.sectionsConfig.title", comment: "Panel sections config sheet title") }
            static var footer: String { ls("panel.sectionsConfig.footer", comment: "Footer hint in Panel sections config") }
            static var emptySection: String { ls("panel.sectionsConfig.emptySection", comment: "Subtitle shown when every widget in a section is individually hidden") }
            static func restoreWidgets(_ name: String) -> String {
                String(format: ls("panel.sectionsConfig.restoreWidgets %@", comment: "Button/accessibility label to restore all widgets of a section"), name)
            }
        }

        enum SectionPrefs {
            static var title: String {
                ls("panel.sectionPrefs.title", comment: "Per-section preferences sheet title (P20-03)")
            }
        }

        /// Salud financiera (P20-06 — Financial Score).
        enum Health {
            // Section title inside the card header.
            static var cardTitle: String {
                ls("panel.health.cardTitle", comment: "Salud financiera card header title")
            }

            // Em-dash placeholder used whenever a sub-score is N/A.
            static var emptyBadge: String {
                ls("panel.health.emptyBadge", comment: "Em-dash placeholder for a mini-ring with no data")
            }

            // Sub-score labels shown under each mini ring.
            static var subScoreBudget: String {
                ls("panel.health.subScore.budget", comment: "Budget sub-score label")
            }
            static var subScoreActivity: String {
                ls("panel.health.subScore.activity", comment: "Activity sub-score label")
            }
            static var subScoreBills: String {
                ls("panel.health.subScore.bills", comment: "Bills sub-score label")
            }

            // MARK: Detail sheet — Total (ring principal).
            static var totalSheetTitle: String {
                ls("panel.health.total.sheet.title", comment: "Total score detail sheet title")
            }
            static var totalSheetExplanation: String {
                ls("panel.health.total.sheet.explanation", comment: "Total score explanation — how the composite is built")
            }
            static var totalHeadlineHigh: String {
                ls("panel.health.total.headline.high", comment: "Encouraging headline for total score ≥ 90")
            }
            static var totalHeadlineMid: String {
                ls("panel.health.total.headline.mid", comment: "Encouraging headline for total score 70-89")
            }
            static var totalHeadlineLow: String {
                ls("panel.health.total.headline.low", comment: "Encouraging headline for total score < 70")
            }
            static var totalHeadlineEmpty: String {
                ls("panel.health.total.headline.empty", comment: "Warm headline when there's no data yet")
            }

            // MARK: Detail sheet — Budget.
            static var budgetSheetTitle: String {
                ls("panel.health.budget.sheet.title", comment: "Budget detail sheet title")
            }
            static var budgetSheetExplanation: String {
                ls("panel.health.budget.sheet.explanation", comment: "Budget explanation — how it is calculated")
            }
            static var budgetHeadlineHigh: String {
                ls("panel.health.budget.headline.high", comment: "Encouraging headline for budget sub-score ≥ 90")
            }
            static var budgetHeadlineMid: String {
                ls("panel.health.budget.headline.mid", comment: "Encouraging headline for budget sub-score 70-89")
            }
            static var budgetHeadlineLow: String {
                ls("panel.health.budget.headline.low", comment: "Encouraging headline for budget sub-score < 70")
            }
            static var budgetHeadlineEmpty: String {
                ls("panel.health.budget.headline.empty", comment: "Warm headline when the user has no budgets yet")
            }
            static var budgetCTAView: String {
                ls("panel.health.budget.cta.view", comment: "CTA label: Go to budgets tab")
            }
            static var budgetCTACreate: String {
                ls("panel.health.budget.cta.create", comment: "CTA label: Create first budget")
            }

            // MARK: Detail sheet — Activity.
            static var activitySheetTitle: String {
                ls("panel.health.activity.sheet.title", comment: "Activity detail sheet title")
            }
            static var activitySheetExplanation: String {
                ls("panel.health.activity.sheet.explanation", comment: "Activity explanation — how it is calculated")
            }
            static var activityHeadlineHigh: String {
                ls("panel.health.activity.headline.high", comment: "Encouraging headline for activity sub-score ≥ 90")
            }
            static var activityHeadlineMid: String {
                ls("panel.health.activity.headline.mid", comment: "Encouraging headline for activity sub-score 70-89")
            }
            static var activityHeadlineLow: String {
                ls("panel.health.activity.headline.low", comment: "Encouraging headline for activity sub-score < 70")
            }
            static var activityHeadlineEmpty: String {
                ls("panel.health.activity.headline.empty", comment: "Warm headline when the user has no transactions yet")
            }
            static var activityCTAView: String {
                ls("panel.health.activity.cta.view", comment: "CTA label: Go to records")
            }
            static var activityCTACreate: String {
                ls("panel.health.activity.cta.create", comment: "CTA label: Register first transaction")
            }

            // MARK: Detail sheet — Bills.
            static var billsSheetTitle: String {
                ls("panel.health.bills.sheet.title", comment: "Bills detail sheet title")
            }
            static var billsSheetExplanation: String {
                ls("panel.health.bills.sheet.explanation", comment: "Bills explanation — how it is calculated")
            }
            static var billsHeadlineHigh: String {
                ls("panel.health.bills.headline.high", comment: "Encouraging headline for bills sub-score ≥ 90")
            }
            static var billsHeadlineMid: String {
                ls("panel.health.bills.headline.mid", comment: "Encouraging headline for bills sub-score 70-89")
            }
            static var billsHeadlineLow: String {
                ls("panel.health.bills.headline.low", comment: "Encouraging headline for bills sub-score < 70")
            }
            static var billsHeadlineEmpty: String {
                ls("panel.health.bills.headline.empty", comment: "Warm headline when the user has no scheduled payments yet")
            }
            static var billsCTAView: String {
                ls("panel.health.bills.cta.view", comment: "CTA label: Go to scheduled payments")
            }
            static var billsCTACreate: String {
                ls("panel.health.bills.cta.create", comment: "CTA label: Create first scheduled payment")
            }

            /// VoiceOver summary for the whole Salud Financiera card.
            /// Placeholders receive strings so they can carry em-dashes or numbers.
            static func voiceoverSummary(
                total: String, budget: String, activity: String, bills: String
            ) -> String {
                String(
                    format: ls("panel.health.voiceover.summary", comment: "VoiceOver summary for the Salud Financiera card"),
                    total, budget, activity, bills
                )
            }

            /// VoiceOver snippet for a single sub-score bar ("94 out of 100").
            static func scoreVoiceover(score: Int) -> String {
                String(
                    format: ls("panel.health.voiceover.score", comment: "VoiceOver — sub-score value + out of 100"),
                    score
                )
            }

            /// VoiceOver fallback read when a sub-score is nil (no data yet).
            static var noData: String {
                ls("panel.health.voiceover.noData", comment: "VoiceOver fallback when a sub-score has no data")
            }
        }

        /// Hero del Panel (PP2-01). El `aiSubtitle` LLM es el KPI protagonista
        /// cuando está disponible (Pro + consent); si no, el fallback rule-based
        /// con cifras concretas sube al protagonista. El chip conserva el sufijo
        /// de mes sólo durante la primera semana.
        enum Hero {
            // MARK: Chip (greeting line)
            static func chipMonthStart(userName: String, month: String) -> String {
                String(format: ls("panel.hero.chip.monthStart %@ %@", comment: "Hero chip — first week, greets user + empezamos <mes>"), userName, month)
            }
            static func chipDefault(userName: String) -> String {
                String(format: ls("panel.hero.chip.default %@", comment: "Hero chip — default greeting, greets user"), userName)
            }

            // MARK: Rule-based KPI fallback (aiSubtitle nil — Free / sin consent / offline / cache miss).
            // Los montos llegan con `**` para render bold via `AttributedString(markdown:)`.
            static func kpiMonthStart(income: String, daysRemaining: Int) -> String {
                String(format: ls("panel.hero.kpi.monthStart %@ %d", comment: "Hero KPI fallback — month just started, markdown bold"), income, daysRemaining)
            }
            static func kpiOnTrack(income: String, spent: String, available: String, daysRemaining: Int) -> String {
                String(format: ls("panel.hero.kpi.onTrack %@ %@ %@ %d", comment: "Hero KPI fallback — on track, markdown bold"), income, spent, available, daysRemaining)
            }
            static func kpiNeutral(income: String, spent: String, available: String, daysRemaining: Int) -> String {
                String(format: ls("panel.hero.kpi.neutral %@ %@ %@ %d", comment: "Hero KPI fallback — neutral, markdown bold"), income, spent, available, daysRemaining)
            }
            static func kpiTight(spent: String, available: String, daysRemaining: Int) -> String {
                String(format: ls("panel.hero.kpi.tight %@ %@ %d", comment: "Hero KPI fallback — budget tight, markdown bold"), spent, available, daysRemaining)
            }
            static func kpiOverBudget(spent: String, income: String) -> String {
                String(format: ls("panel.hero.kpi.overBudget %@ %@", comment: "Hero KPI fallback — over budget, markdown bold"), spent, income)
            }

            // MARK: AI Hero
            /// CTA inline visible cuando no hay aiSubtitle disponible y el user
            /// aún puede "desbloquearlo" (Free → upgrade; Pro sin consent →
            /// activar el toggle de Insights IA en Perfil).
            static var upsellCTA: String {
                ls("panel.hero.upsellCTA", comment: "Hero inline CTA — appears for Free and for Pro users without AI consent")
            }
            /// Label inline arriba del monto disponible — desambigua qué
            /// representa el monto. Se compone con el `displayName` del
            /// período actual ("Disponible · Este mes", "Available · This year").
            static var availableLabel: String {
                ls("panel.hero.availableLabel", comment: "Hero — available amount label, composed with period display name")
            }
        }
        static var totalBalance: String {
            ls("panel.totalBalance", comment: "Total balance label")
        }
        static func greeting(_ name: String) -> String {
            String(format: ls("panel.greeting", comment: ""), name)
        }
        static func title(_ name: String) -> String {
            String(format: ls("panel.title", comment: ""), name)
        }
        static var fabVoice: String {
            ls("panel.fabVoice", comment: "")
        }
        static var fabImage: String {
            ls("panel.fabImage", comment: "")
        }
        static var fabManual: String {
            ls("panel.fabManual", comment: "")
        }
        static var fabGroup: String {
            ls("panel.fabGroup", comment: "")
        }
        static var spent: String {
            ls("panel.spent", comment: "Spent label for expenses-only mode account cards")
        }
        static var aiInsightsTitle: String {
            ls("panel.aiInsightsTitle", comment: "AI insights toggle title")
        }
        static var aiInsightsDescription: String {
            ls("panel.aiInsightsDescription", comment: "AI insights toggle description")
        }
        static var dismissInsight: String {
            ls("panel.dismissInsight", comment: "Dismiss contextual insight accessibility label")
        }
        static var aiConsentRequired: String {
            ls("panel.aiConsentRequired", comment: "Hint when AI consent not accepted")
        }
        static var preparingInsight: String {
            ls("panel.preparingInsight", comment: "Loading state before LLM call")
        }
        static var insightMenuRegenerate: String {
            ls("panel.insightMenuRegenerate", comment: "Regenerate insight menu option")
        }
        static var insightMenuDifferentAngle: String {
            ls("panel.insightMenuDifferentAngle", comment: "Different angle menu option")
        }
        static var insightMenuHideHour: String {
            ls("panel.insightMenuHideHour", comment: "Hide for one hour menu option")
        }
        static var insightMenuHideToday: String {
            ls("panel.insightMenuHideToday", comment: "Hide for today menu option")
        }

        // MARK: - Live Anchor Education ("Tu saldo hoy" sheet)

        enum LiveAnchorEducation {
            static var title: String {
                ls("panel.liveAnchorEducation.title", comment: "Sheet title: educative sheet about today's balance at current FX rate")
            }
            static func heroFormat(_ amount: String) -> String {
                String(format: ls("panel.liveAnchorEducation.heroFormat", comment: "Hero of the sheet, e.g. 'Hoy tienes S/ 28,594'"), amount)
            }
            static func bodyLineOneFormat(_ currency: String) -> String {
                String(format: ls("panel.liveAnchorEducation.bodyLineOneFormat", comment: "Explanation line 1, %@ is preferred currency code or symbol"), currency)
            }
            static func bodyLineTwoFormat(_ historical: String) -> String {
                String(format: ls("panel.liveAnchorEducation.bodyLineTwoFormat", comment: "Explanation line 2, %@ is historical balance formatted"), historical)
            }
            static var bodyLineThree: String {
                ls("panel.liveAnchorEducation.bodyLineThree", comment: "Explanation line 3: why the difference exists")
            }
            static var todayQuestion: String {
                ls("panel.liveAnchorEducation.todayQuestion", comment: "Section title above the hero amount: 'How much you have today'")
            }
            static var whyQuestion: String {
                ls("panel.liveAnchorEducation.whyQuestion", comment: "Section title above the explanation paragraph: 'Why this amount?'")
            }
            static var breakdownToggle: String {
                ls("panel.liveAnchorEducation.breakdownToggle", comment: "Section header above the per-currency rows: 'By currency'")
            }
            static func breakdownRowConvertedFormat(_ converted: String) -> String {
                String(format: ls("panel.liveAnchorEducation.breakdownRowConvertedFormat", comment: "Per-row conversion suffix, e.g. '≈ S/ 1,140 hoy'"), converted)
            }
            static var coachTitle: String {
                ls("panel.liveAnchorEducation.coachTitle", comment: "Coach mark title shown first time on multi-currency users")
            }
            static var coachMessage: String {
                ls("panel.liveAnchorEducation.coachMessage", comment: "Coach mark body shown first time on multi-currency users")
            }
            static var dotA11yLabel: String {
                ls("panel.liveAnchorEducation.dotA11yLabel", comment: "VoiceOver label for the today dot in the trend chart")
            }
        }
    }

    // MARK: - Balance Status

    enum BalanceStatus {
        static var good: String { ls("balance.status.good", comment: "") }
        static var critical: String { ls("balance.status.critical", comment: "") }
        static var normal: String { ls("balance.status.normal", comment: "") }
    }

    // MARK: - Budget

    enum Budget {
        static var noInactive: String { ls("budget.noInactive", comment: "") }
    }

    // MARK: - Trend

    enum Trend {
        static var title: String {
            ls("trend.title", comment: "Trends section title")
        }
        static var balanceTitle: String {
            ls("trend.balance.title", comment: "Balance trend title")
        }
        static var incomeTitle: String {
            ls("trend.income.title", comment: "Income trend title")
        }
        static var expenseTitle: String {
            ls("trend.expense.title", comment: "Expense trend title")
        }
        static var filterBlockedMessage: String {
            ls(
                "trend.filterBlockedMessage",
                comment: "Message shown when user tries to select balance/income with category filters active"
            )
        }
        static var filterBlockedTitle: String {
            ls("trend.filterBlockedTitle", comment: "")
        }
    }

    // MARK: - Trend Types

    enum TrendType {
        static var balance: String {
            ls("trendType.balance", comment: "Balance type")
        }
        static var income: String { ls("trendType.income", comment: "Income type") }
        static var expense: String {
            ls("trendType.expense", comment: "Expense type")
        }
    }

    // MARK: - Cash Flow

    enum CashFlow {
        static var title: String { ls("cashFlow.title", comment: "Cash flow title") }
        static var income: String { ls("cashFlow.income", comment: "Income label") }
        static var expense: String {
            ls("cashFlow.expense", comment: "Expense label")
        }
        static var net: String { ls("cashFlow.net", comment: "Net label") }
        static var netFlow: String {
            ls("cashFlow.netFlow", comment: "Net flow label")
        }
    }

    // MARK: - Cash Flow Plan

    enum CashFlowPlan {
        // Setup
        static var title: String { ls("cashFlowPlan.title", comment: "") }
        static var description: String { ls("cashFlowPlan.description", comment: "") }
        static var createButton: String { ls("cashFlowPlan.createButton", comment: "") }
        static var startingBalance: String { ls("cashFlowPlan.startingBalance", comment: "") }
        static var startingBalanceHelper: String { ls("cashFlowPlan.startingBalanceHelper", comment: "") }
        static var incomeSection: String { ls("cashFlowPlan.incomeSection", comment: "") }
        static var expenseSection: String { ls("cashFlowPlan.expenseSection", comment: "") }
        static var recommendedBadge: String { ls("cashFlowPlan.recommendedBadge", comment: "") }
        static var otherExpensesLabel: String { ls("cashFlowPlan.otherExpenses", comment: "") }
        static var otherExpensesDesc: String { ls("cashFlowPlan.otherExpensesDesc", comment: "") }
        static var otherIncomeLabel: String { ls("cashFlowPlan.otherIncome", comment: "") }
        static var emptyState: String { ls("cashFlowPlan.emptyState", comment: "") }
        static var emptyStateMessage: String { ls("cashFlowPlan.emptyStateMessage", comment: "") }
        static var monthsActive: String { ls("cashFlowPlan.monthsActive", comment: "") }
        static func suggestedSource(_ months: Int) -> String {
            String(format: ls("cashFlowPlan.suggestedSource", comment: ""), months)
        }
        static var bannerTitle: String { ls("cashFlowPlan.bannerTitle", comment: "") }
        static var bannerBody: String { ls("cashFlowPlan.bannerBody", comment: "") }
        static var selectAll: String { ls("cashFlowPlan.selectAll", comment: "") }
        static var total: String { ls("cashFlowPlan.total", comment: "") }
        static var aiChipLabel: String { ls("cashFlowPlan.aiChipLabel", comment: "AI chip toggle — IA/AI/KI per locale") }
        static var lineNameLabel: String { ls("cashFlowPlan.lineNameLabel", comment: "") }
        static var lineNameHint: String { ls("cashFlowPlan.lineNameHint", comment: "") }

        // Hints
        static var availableHintTitle: String { ls("cashFlowPlan.availableHintTitle", comment: "") }
        static var availableHintMessage: String { ls("cashFlowPlan.availableHintMessage", comment: "") }
        static var accumulatedHintTitle: String { ls("cashFlowPlan.accumulatedHintTitle", comment: "") }
        static var accumulatedHintMessage: String { ls("cashFlowPlan.accumulatedHintMessage", comment: "") }

        // Edit starting balance
        static var editStartingBalance: String { ls("cashFlowPlan.editStartingBalance", comment: "") }
        static var editStartingBalanceSave: String { ls("cashFlowPlan.editStartingBalanceSave", comment: "") }
        static var startingBalanceDateLabel: String { ls("cashFlowPlan.startingBalanceDateLabel", comment: "") }
        static var startingBalanceDateHelper: String { ls("cashFlowPlan.startingBalanceDateHelper", comment: "") }

        // Horizon config
        static var configureHorizon: String { ls("cashFlowPlan.configureHorizon", comment: "") }
        static var monthsAhead: String { ls("cashFlowPlan.monthsAhead", comment: "") }
        static var monthsBack: String { ls("cashFlowPlan.monthsBack", comment: "") }
        static var showAccumulatedBalance: String { ls("cashFlowPlan.showAccumulatedBalance", comment: "") }

        // Month summary
        static func monthSummaryOnTrack(_ percent: Int) -> String {
            String(format: ls("cashFlowPlan.monthSummaryOnTrack", comment: ""), percent)
        }
        static func monthSummaryOver(_ percent: Int) -> String {
            String(format: ls("cashFlowPlan.monthSummaryOver", comment: ""), percent)
        }
        static func monthSummaryUnder(_ percent: Int) -> String {
            String(format: ls("cashFlowPlan.monthSummaryUnder", comment: ""), percent)
        }

        // Table / Detail
        static var available: String { ls("cashFlowPlan.available", comment: "") }
        static var accumulated: String { ls("cashFlowPlan.accumulated", comment: "") }
        static var accumulatedShort: String { ls("cashFlowPlan.accumulatedShort", comment: "") }
        static var addLine: String { ls("cashFlowPlan.addLine", comment: "") }
        static var thisMonth: String { ls("cashFlowPlan.thisMonth", comment: "") }
        static var pastMonth: String { ls("cashFlowPlan.pastMonth", comment: "") }
        static var futureMonth: String { ls("cashFlowPlan.futureMonth", comment: "") }
        static func executionPercent(_ percent: Int) -> String {
            String(format: ls("cashFlowPlan.executionPercent", comment: ""), percent)
        }

        // Config
        static var estimationMethod: String { ls("cashFlowPlan.estimationMethod", comment: "") }
        static var calculationMethodTitle: String { ls("cashFlowPlan.calculationMethodTitle", comment: "") }
        static var average3m: String { ls("cashFlowPlan.average3m", comment: "") }
        static var average6m: String { ls("cashFlowPlan.average6m", comment: "") }
        static var average12m: String { ls("cashFlowPlan.average12m", comment: "") }
        static var lastMonth: String { ls("cashFlowPlan.lastMonth", comment: "") }
        static var manual: String { ls("cashFlowPlan.manual", comment: "") }
        static var scheduled: String { ls("cashFlowPlan.scheduled", comment: "") }
        static var trend: String { ls("cashFlowPlan.trend", comment: "") }
        static var custom: String { ls("cashFlowPlan.custom", comment: "") }
        static var contextLabel: String { ls("cashFlowPlan.context", comment: "") }

        // Method descriptions
        static var average3mDesc: String { ls("cashFlowPlan.average3mDesc", comment: "") }
        static var average6mDesc: String { ls("cashFlowPlan.average6mDesc", comment: "") }
        static var average12mDesc: String { ls("cashFlowPlan.average12mDesc", comment: "") }
        static var lastMonthDesc: String { ls("cashFlowPlan.lastMonthDesc", comment: "") }
        static var manualDesc: String { ls("cashFlowPlan.manualDesc", comment: "") }
        static var scheduledDesc: String { ls("cashFlowPlan.scheduledDesc", comment: "") }
        static var trendDesc: String { ls("cashFlowPlan.trendDesc", comment: "") }
        static var customDesc: String { ls("cashFlowPlan.customDesc", comment: "") }
        static var trendLabel: String { ls("cashFlowPlan.trendLabel", comment: "") }
        static var rangeLabel: String { ls("cashFlowPlan.rangeLabel", comment: "") }

        // Popover
        static var plan: String { ls("cashFlowPlan.plan", comment: "") }
        static var real: String { ls("cashFlowPlan.real", comment: "") }
        static var realIncome: String { ls("cashFlowPlan.realIncome", comment: "") }
        static var difference: String { ls("cashFlowPlan.difference", comment: "") }
        static var adjustAmount: String { ls("cashFlowPlan.adjustAmount", comment: "") }

        // Others
        static var othersTitle: String { ls("cashFlowPlan.othersTitle", comment: "") }
        static var othersDesc: String { ls("cashFlowPlan.othersDesc", comment: "") }
        static var othersHint: String { ls("cashFlowPlan.othersHint", comment: "") }
        static var othersIncomeTitle: String { ls("cashFlowPlan.othersIncomeTitle", comment: "") }
        static var othersIncomeDesc: String { ls("cashFlowPlan.othersIncomeDesc", comment: "") }
        static var othersIncomeHint: String { ls("cashFlowPlan.othersIncomeHint", comment: "") }
        static var promoteCategory: String { ls("cashFlowPlan.promoteCategory", comment: "") }

        // Actions
        static var resetPlan: String { ls("cashFlowPlan.resetPlan", comment: "") }
        static var resetConfirmation: String { ls("cashFlowPlan.resetConfirmation", comment: "") }
        static var deleteLineConfirmation: String { ls("cashFlowPlan.deleteLineConfirmation", comment: "") }
        static func suggestPayment(_ name: String) -> String {
            String(format: ls("cashFlowPlan.suggestPayment", comment: ""), name)
        }

        // Charts
        static var chartsTitle: String { ls("cashFlowPlan.chartsTitle", comment: "") }
        static var chartsSectionTitle: String { ls("cashFlowPlan.chartsSectionTitle", comment: "") }
        static var accumulatedBalance: String { ls("cashFlowPlan.accumulatedBalance", comment: "") }
        static var incomeVsExpense: String { ls("cashFlowPlan.incomeVsExpense", comment: "") }
        static var composition: String { ls("cashFlowPlan.composition", comment: "") }
        static var realVsPlan: String { ls("cashFlowPlan.realVsPlan", comment: "") }
        static var trendByLine: String { ls("cashFlowPlan.trendByLine", comment: "") }

        // Cell Detail (Inc 4)
        static var cellDetailOf: String { ls("cashFlowPlan.cellDetailOf", comment: "") }
        static func cellDetailRemaining(_ amount: String) -> String {
            String(format: ls("cashFlowPlan.cellDetailRemaining", comment: ""), amount)
        }
        static var cellDetailRecentTransactions: String { ls("cashFlowPlan.cellDetailRecentTransactions", comment: "") }
        static var cellDetailSpent: String { ls("cashFlowPlan.cellDetailSpent", comment: "") }
        static var cellDetailEarned: String { ls("cashFlowPlan.cellDetailEarned", comment: "") }
        static var cellDetailMore: String { ls("cashFlowPlan.cellDetailMore", comment: "") }
        static var cellDetailLess: String { ls("cashFlowPlan.cellDetailLess", comment: "") }
        static var cellDetailOverrideActive: String { ls("cashFlowPlan.cellDetailOverrideActive", comment: "") }
        static var cellDetailNote: String { ls("cashFlowPlan.cellDetailNote", comment: "") }
        static var cellDetailSaveAdjustment: String { ls("cashFlowPlan.cellDetailSaveAdjustment", comment: "") }
        static var overrideScopeTitle: String { ls("cashFlowPlan.overrideScopeTitle", comment: "") }
        static var overrideScopeMessage: String { ls("cashFlowPlan.overrideScopeMessage", comment: "") }
        static var overrideScopeThisMonth: String { ls("cashFlowPlan.overrideScopeThisMonth", comment: "") }
        static var overrideScopeThisAndFuture: String { ls("cashFlowPlan.overrideScopeThisAndFuture", comment: "") }
        static var cellDetailDailyProgress: String { ls("cashFlowPlan.cellDetailDailyProgress", comment: "") }

        // Config improvements (Inc 5)
        static var contextHistory: String { ls("cashFlowPlan.contextHistory", comment: "") }
        static func monthsWithActivity(_ count: Int) -> String {
            String(format: ls("cashFlowPlan.monthsWithActivity", comment: ""), count)
        }
        static var addOverride: String { ls("cashFlowPlan.addOverride", comment: "") }
        static var overrideMonth: String { ls("cashFlowPlan.overrideMonth", comment: "") }
        static var overrideAmount: String { ls("cashFlowPlan.overrideAmount", comment: "") }
        static var configLine: String { ls("cashFlowPlan.configLine", comment: "") }

        // Add Line redesign (Inc 6)
        static var addFromExpenses: String { ls("cashFlowPlan.addFromExpenses", comment: "") }
        static var addFromExpensesDesc: String { ls("cashFlowPlan.addFromExpensesDesc", comment: "") }
        static var addFromScheduled: String { ls("cashFlowPlan.addFromScheduled", comment: "") }
        static var addFromScheduledDesc: String { ls("cashFlowPlan.addFromScheduledDesc", comment: "") }
        static var addCustomLine: String { ls("cashFlowPlan.addCustomLine", comment: "") }
        static var addCustomLineDesc: String { ls("cashFlowPlan.addCustomLineDesc", comment: "") }
        static var monthlyAverage: String { ls("cashFlowPlan.monthlyAverage", comment: "") }
        static var frequency: String { ls("cashFlowPlan.frequency", comment: "") }
        static var noScheduledPayments: String { ls("cashFlowPlan.noScheduledPayments", comment: "") }
        static var noCategories: String { ls("cashFlowPlan.noCategories", comment: "") }

        // Charts redesign (Inc 7)
        static var chartProjection: String { ls("cashFlowPlan.chartProjection", comment: "") }
        static var chartDeviation: String { ls("cashFlowPlan.chartDeviation", comment: "") }
        static var chartDeviationSubtitle: String { ls("cashFlowPlan.chartDeviationSubtitle", comment: "") }
        static var chartSavings: String { ls("cashFlowPlan.chartSavings", comment: "") }
        static var chartProjectionSubtitle: String { ls("cashFlowPlan.chartProjectionSubtitle", comment: "") }
        static var chartDeviationOver: String { ls("cashFlowPlan.chartDeviationOver", comment: "") }
        static var chartDeviationUnder: String { ls("cashFlowPlan.chartDeviationUnder", comment: "") }
        static var chartDangerZone: String { ls("cashFlowPlan.chartDangerZone", comment: "") }
        static var chartRollingAvg: String { ls("cashFlowPlan.chartRollingAvg", comment: "") }
        static var chartNeedMoreData: String { ls("cashFlowPlan.chartNeedMoreData", comment: "") }
        static var analyzingProjection: String { ls("cashFlowPlan.analyzingProjection", comment: "") }
        static var enableAIObservations: String { ls("cashFlowPlan.enableAIObservations", comment: "") }
        static func commentNegative(_ month: String) -> String {
            String(format: ls("cashFlowPlan.commentNegative", comment: ""), month)
        }
        static func commentTight(_ margin: String) -> String {
            String(format: ls("cashFlowPlan.commentTight", comment: ""), margin)
        }
        static func commentHealthy(_ balance: String) -> String {
            String(format: ls("cashFlowPlan.commentHealthy", comment: ""), balance)
        }
        static func commentDefault(_ count: Int) -> String {
            String(format: ls("cashFlowPlan.commentDefault", comment: ""), count)
        }
        static var chartAllWithinPlan: String { ls("cashFlowPlan.chartAllWithinPlan", comment: "") }
        static func deviationCommentSingle(_ name: String, _ amount: String) -> String {
            String(format: ls("cashFlowPlan.deviationCommentSingle", comment: ""), name, amount)
        }
        static func deviationCommentMultiple(_ name: String, _ amount: String, _ total: String) -> String {
            String(format: ls("cashFlowPlan.deviationCommentMultiple", comment: ""), name, amount, total)
        }
        static var chartSavingsSubtitle: String { ls("cashFlowPlan.chartSavingsSubtitle", comment: "") }
        static var chartPlanned: String { ls("cashFlowPlan.chartPlanned", comment: "") }
        static func commentSavingsBelow(_ diff: String) -> String {
            String(format: ls("cashFlowPlan.commentSavingsBelow", comment: ""), diff)
        }
        static func commentSavingsAbove(_ diff: String, _ balance: String) -> String {
            String(format: ls("cashFlowPlan.commentSavingsAbove", comment: ""), diff, balance)
        }
        static func commentHealthyWithSavings(_ avg: String, _ balance: String) -> String {
            String(format: ls("cashFlowPlan.commentHealthyWithSavings", comment: ""), avg, balance)
        }
    }

    // MARK: - Groupings

    enum Groupings {
        static var daily: String { ls("grouping.day", comment: "") }
        static var weekly: String { ls("grouping.week", comment: "") }
        static var monthly: String { ls("grouping.month", comment: "") }
    }

    // MARK: - Tab

    enum Tab {
        static var panel: String { ls("tab.panel", comment: "") }
        static var statistics: String { ls("tab.statistics", comment: "") }
        static var planning: String { ls("tab.planning", comment: "") }
        static var more: String { ls("tab.more", comment: "") }
        static var search: String { ls("tab.search", comment: "") }
        static var records: String { ls("tab.records", comment: "") }
        static var reports: String { ls("tab.reports", comment: "") }
        static var groups: String { ls("tab.groups", comment: "") }
    }

    // MARK: - Period

    enum Period {
        static var thisWeek: String { ls("period.thisWeek", comment: "") }
        static var lastWeek: String { ls("period.lastWeek", comment: "") }
        static var nextWeek: String { ls("period.nextWeek", comment: "") }
        static var last7Days: String { ls("period.last7Days", comment: "") }
        static var last30Days: String {
            ls("period.last30Days", comment: "Last 30 days")
        }
        static var thisMonth: String {
            ls("period.thisMonth", comment: "This month")
        }
        static var lastMonth: String {
            ls("period.lastMonth", comment: "Last month")
        }
        static var nextMonth: String {
            ls("period.nextMonth", comment: "Next month")
        }
        static var thisYear: String { ls("period.thisYear", comment: "This year") }
        static var lastYear: String { ls("period.lastYear", comment: "Last year") }
        static var nextYear: String { ls("period.nextYear", comment: "Next year") }
        static var allTime: String { ls("period.allTime", comment: "All time") }
        static var custom: String { ls("period.custom", comment: "Custom period") }
        static var startDate: String {
            ls("period.startDate", comment: "Start date")
        }
        static var endDate: String { ls("period.endDate", comment: "End date") }
        static var selectRange: String {
            ls("period.selectRange", comment: "Select range")
        }
        static var selectedRange: String {
            ls("period.selectedRange", comment: "Selected range")
        }
    }

    // MARK: - Insights
    enum Insights {
        static var title: String { ls("insights.title", comment: "") }
        static var records: String { ls("insights.records", comment: "") }
        static var inThisPeriod: String { ls("insights.inThisPeriod", comment: "") }
        static var dailyAverage: String { ls("insights.dailyAverage", comment: "") }
        static var topCategory: String { ls("insights.topCategory", comment: "") }
        static var topSubcategory: String { ls("insights.topSubcategory", comment: "") }
        static var highestExpense: String { ls("insights.highestExpense", comment: "") }
        static var highestAvgWeekday: String { ls("insights.highestAvgWeekday", comment: "") }
        static var subscriptions: String { ls("insights.subscriptions", comment: "") }
        static var quickStats: String { ls("insights.quickStats", comment: "") }
        static var comparison: String { ls("insights.comparison", comment: "") }
        static var weekdayAverage: String { ls("insights.weekdayAverage", comment: "") }
        static var needDistribution: String { ls("insights.needDistribution", comment: "") }
        static var commitments: String { ls("insights.commitments", comment: "") }
        static var commitmentsNote: String { ls("insights.commitmentsNote", comment: "") }
        static var pendingPayments: String { ls("insights.pendingPayments", comment: "") }
        static var activeSubscriptions: String { ls("insights.activeSubscriptions", comment: "") }
        static var budgetsAtRisk: String { ls("insights.budgetsAtRisk", comment: "") }
        static var yearOverYear: String { ls("insights.yearOverYear", comment: "") }
        static func yearComparison(previous: String, current: String) -> String {
            String(format: ls("insights.yearComparison", comment: ""), previous, current)
        }
        static var intelligentInsights: String { ls("insights.intelligentInsights", comment: "") }
        static var funFact: String { ls("insights.funFact", comment: "") }
        static var emptyTitle: String { ls("insights.emptyTitle", comment: "") }
        static var emptyBody: String { ls("insights.emptyBody", comment: "") }
        static var fewTransactions: String { ls("insights.fewTransactions", comment: "") }
        static var monthly: String { ls("insights.monthly", comment: "") }
        static var perDay: String { ls("insights.perDay", comment: "") }
        static var ofTotal: String { ls("insights.ofTotal", comment: "") }
        static var analyzingData: String { ls("insights.analyzingData", comment: "") }
        static var activateAITitle: String { ls("insights.activateAITitle", comment: "") }
        static var activateAIBody: String { ls("insights.activateAIBody", comment: "") }
        static var activateAIDisclaimer: String { ls("insights.activateAIDisclaimer", comment: "") }
        static var activate: String { ls("insights.activate", comment: "") }
        static var goToSettings: String { ls("insights.goToSettings", comment: "") }
        static var notInterested: String { ls("insights.notInterested", comment: "") }
        static var offlineCached: String { ls("insights.offlineCached", comment: "") }
        static var offlineNoCache: String { ls("insights.offlineNoCache", comment: "") }
        static var aiSectionTitle: String { ls("insights.aiSectionTitle", comment: "") }
        static var aiToggle: String { ls("insights.aiToggle", comment: "") }
        static var aiCaption: String { ls("insights.aiCaption", comment: "") }
        static var metricsSection: String { ls("insights.metricsSection", comment: "") }
        static var chartsSection: String { ls("insights.chartsSection", comment: "") }
        static var analysisSection: String { ls("insights.analysisSection", comment: "") }
        static var restoreDefaults: String { ls("insights.restoreDefaults", comment: "") }
        // Rule-based insight templates (with tone variants)
        static func ruleTopCategory(_ name: String, _ pct: Int, tone: InsightTone = .normal) -> String {
            let key = "insights.ruleTopCategory.\(tone.rawValue)"
            return String(format: ls(key, comment: ""), name, pct)
        }
        static func ruleExpenseUp(_ formatted: String, tone: InsightTone = .normal) -> String {
            let key = "insights.ruleExpenseUp.\(tone.rawValue)"
            return String(format: ls(key, comment: ""), formatted)
        }
        static func ruleExpenseDown(_ formatted: String, tone: InsightTone = .normal) -> String {
            let key = "insights.ruleExpenseDown.\(tone.rawValue)"
            return String(format: ls(key, comment: ""), formatted)
        }
        static func ruleBudgetRisk(_ name: String, _ pct: Int, tone: InsightTone = .normal) -> String {
            let key = "insights.ruleBudgetRisk.\(tone.rawValue)"
            return String(format: ls(key, comment: ""), name, pct)
        }
        static func ruleOptionalHigh(_ pct: Int, tone: InsightTone = .normal) -> String {
            let key = "insights.ruleOptionalHigh.\(tone.rawValue)"
            return String(format: ls(key, comment: ""), pct)
        }

        // Tips (no tone variant)
        static func tipTopCategory(_ name: String) -> String {
            String(format: ls("insights.tipTopCategory", comment: ""), name)
        }
        static var tipExpenseUp: String { ls("insights.tipExpenseUp", comment: "") }
        static func tipBudgetRisk(_ name: String) -> String {
            String(format: ls("insights.tipBudgetRisk", comment: ""), name)
        }
        static var tipOptionalHigh: String { ls("insights.tipOptionalHigh", comment: "") }

        // Universal rules (sin tonos, válidas para todos los períodos)
        static func ruleDailyAverage(_ amount: String) -> String {
            String(format: ls("insights.ruleDailyAverage %@", comment: "Universal daily average snapshot"), amount)
        }
        static func ruleSavingsPositive(_ pct: Int) -> String {
            String(format: ls("insights.ruleSavingsPositive %d", comment: "Savings ratio positive — income exceeds expenses by N%%"), pct)
        }
        static var ruleSavingsNegative: String {
            ls("insights.ruleSavingsNegative", comment: "Savings ratio negative — expenses exceed income in period")
        }

        // Group insight rules
        static func ruleSharedRatio(_ pct: Int, tone: InsightTone = .normal) -> String {
            String(format: ls("insights.ruleSharedRatio.\(tone.rawValue)", comment: ""), pct)
        }
        static func ruleMostExpensiveGroup(_ name: String, _ pct: Int, tone: InsightTone = .normal) -> String {
            String(format: ls("insights.ruleMostExpensiveGroup.\(tone.rawValue)", comment: ""), name, pct)
        }
        static func ruleSharedFrequency(_ count: Int, tone: InsightTone = .normal) -> String {
            String(format: ls("insights.ruleSharedFrequency.\(tone.rawValue)", comment: ""), count)
        }
        static func ruleDominantSharedCategory(_ name: String, _ pct: Int, tone: InsightTone = .normal) -> String {
            String(format: ls("insights.ruleDominantSharedCategory.\(tone.rawValue)", comment: ""), name, pct)
        }
        static func ruleSharedMoM(_ variation: String, tone: InsightTone = .normal) -> String {
            String(format: ls("insights.ruleSharedMoM.\(tone.rawValue)", comment: ""), variation)
        }

        // Tone/Focus display names
        static func toneName(_ tone: InsightTone) -> String {
            ls("insights.tone.\(tone.rawValue)", comment: "")
        }
        static func tonePreview(_ tone: InsightTone) -> String {
            ls("insights.tone.\(tone.rawValue).preview", comment: "")
        }
        static func focusName(_ focus: InsightFocus) -> String {
            ls("insights.focus.\(focus.rawValue)", comment: "")
        }
        static func focusDescription(_ focus: InsightFocus) -> String {
            ls("insights.focus.\(focus.rawValue).desc", comment: "")
        }

        // Settings labels
        static var toneLabel: String { ls("insights.toneLabel", comment: "") }
        static var focusLabel: String { ls("insights.focusLabel", comment: "") }

        // AI teaser
        static var aiTeaser: String { ls("insights.aiTeaser", comment: "") }
        static var aiTeaserPlaceholder1: String { ls("insights.aiTeaserPlaceholder1", comment: "") }
        static var aiTeaserPlaceholder2: String { ls("insights.aiTeaserPlaceholder2", comment: "") }

        // AI on-demand
        static var generateAI: String { ls("insights.generateAI", comment: "") }
        static var generateAIHint: String { ls("insights.generateAIHint", comment: "") }
    }

    // MARK: - Statistics
    enum Statistics {
        static var title: String { ls("statistics.title", comment: "") }
        static var trends: String { ls("statistics.trends", comment: "") }
        static var categories: String { ls("statistics.categories", comment: "") }
        static var records: String { ls("statistics.records", comment: "") }
        static var noRecordsFiltered: String {
            ls("statistics.noRecordsFiltered", comment: "")
        }
        static var noRecordsDescription: String {
            ls("statistics.noRecordsDescription", comment: "")
        }
        static var periodComparison: String {
            ls("statistics.periodComparison", comment: "")
        }
        static var vsPreviousPeriod: String {
            ls("statistics.vsPreviousPeriod", comment: "")
        }
        static var vsPreviousYear: String {
            ls("statistics.vsPreviousYear", comment: "")
        }
        static var currentPeriod: String {
            ls("statistics.currentPeriod", comment: "")
        }
        static var previousPeriod: String {
            ls("statistics.previousPeriod", comment: "")
        }
        static var latestRecords: String {
            ls("statistics.latestRecords", comment: "")
        }
        static var noCategoryData: String {
            ls("statistics.noCategoryData", comment: "")
        }
        static var noSubcategoryData: String {
            ls("statistics.noSubcategoryData", comment: "")
        }
        static var noExpensesInPeriod: String {
            ls("statistics.noExpensesInPeriod", comment: "")
        }
        static var topCategories: String {
            ls("statistics.topCategories", comment: "")
        }
        static var topSubcategories: String {
            ls("statistics.topSubcategories", comment: "")
        }
        static var noDataToShow: String {
            ls("statistics.noDataToShow", comment: "")
        }
        static var noRecords: String {
            ls("statistics.noRecords", comment: "")
        }
        static var ofExpense: String {
            ls("statistics.ofExpense", comment: "")
        }
        static var spendingAnalysis: String {
            ls("statistics.spendingAnalysis", comment: "")
        }
        static var incomeAnalysis: String {
            ls("statistics.incomeAnalysis", comment: "")
        }

        enum Sankey {
            static var title: String { ls("statistics.sankey.title", comment: "") }
            static var expenses: String { ls("statistics.sankey.expenses", comment: "") }
            static var available: String { ls("statistics.sankey.available", comment: "") }
            static var others: String { ls("statistics.sankey.others", comment: "") }
            static var planned: String { ls("statistics.sankey.planned", comment: "") }
            static var plannedRecurring: String { ls("statistics.sankey.plannedRecurring", comment: "") }
            static var plannedSubscription: String { ls("statistics.sankey.plannedSubscription", comment: "") }
            static var otherFunds: String { ls("statistics.sankey.otherFunds", comment: "") }
            static var plannedHint: String { ls("statistics.sankey.plannedHint", comment: "") }
            static var toggleAmount: String { ls("statistics.sankey.toggleAmount", comment: "") }
            static var togglePercentage: String { ls("statistics.sankey.togglePercentage", comment: "") }
        }
    }

    // MARK: - Report

    enum Report {
        static var title: String { ls("report.title", comment: "") }

        enum Tab {
            static var comparative: String { ls("report.tab.comparative", comment: "") }
            static var cashFlow: String { ls("report.tab.cashFlow", comment: "") }
        }

        static var income: String { ls("report.income", comment: "") }
        static var expense: String { ls("report.expense", comment: "") }
        static var netFlow: String { ls("report.netFlow", comment: "") }
        static var noData: String { ls("report.noData", comment: "") }
        static var noDataDescription: String { ls("report.noDataDescription", comment: "") }
        static var uncategorized: String { ls("report.uncategorized", comment: "") }
        static var noSubcategory: String { ls("report.noSubcategory", comment: "") }
        static var noTag: String { ls("report.noTag", comment: "") }
        static var noAccount: String { ls("report.noAccount", comment: "") }

        enum Grouping {
            static var type: String { ls("report.grouping.type", comment: "") }
            static var category: String { ls("report.grouping.category", comment: "") }
            static var subcategory: String { ls("report.grouping.subcategory", comment: "") }
            static var tag: String { ls("report.grouping.tag", comment: "") }
            static var account: String { ls("report.grouping.account", comment: "") }
            static var currency: String { ls("report.grouping.currency", comment: "") }
            static var nature: String { ls("report.grouping.nature", comment: "") }
            static var drillDown: String { ls("report.grouping.drillDown", comment: "") }
            static var hint: String { ls("report.grouping.hint", comment: "") }
            static var active: String { ls("report.grouping.active", comment: "") }
            static var available: String { ls("report.grouping.available", comment: "") }
        }
    }

    // MARK: - Nature
    enum Need {
        static var title: String {
            ls("need.expensesByNeed", comment: "Expenses by need")
        }
        static var label: String {
            ls("need.title", comment: "Need label")
        }
        static var essential: String { ls("need.essential", comment: "") }
        static var essentialDesc: String {
            ls("need.essential.desc", comment: "")
        }
        static var priority: String { ls("need.priority", comment: "") }
        static var priorityDesc: String {
            ls("need.priority.desc", comment: "")
        }
        static var optional: String { ls("need.optional", comment: "") }
        static var optionalDesc: String {
            ls("need.optional.desc", comment: "")
        }
        static var unclassified: String {
            ls("need.unclassified", comment: "")
        }
        static var unclassifiedDesc: String {
            ls("need.unclassified.desc", comment: "")
        }
        static var incomeNotApplicable: String {
            ls(
                "need.incomeNotApplicable",
                comment: "Message shown when income filter is active - need classification doesn't apply"
            )
        }
    }

    // MARK: - Records

    enum Records {
        static var title: String { ls("records.title", comment: "") }
        static var latest: String { ls("records.latest", comment: "") }
        static var noRecords: String { ls("records.noRecords", comment: "") }
        static var noRecordsThisDay: String { ls("records.noRecordsThisDay", comment: "Calendario: día seleccionado sin registros") }
        static var viewModeListA11y: String { ls("records.viewModeListA11y", comment: "A11y: botón vista lista") }
        static var viewModeCalendarA11y: String { ls("records.viewModeCalendarA11y", comment: "A11y: botón vista calendario") }
        static func deleteConfirmTitle(_ count: Int) -> String {
            String(format: ls("records.deleteConfirmTitle", comment: ""), count)
        }

        enum Duplicates {
            static var menuTitle: String { ls("records.duplicates.menuTitle", comment: "") }
            static var matchBy: String { ls("records.duplicates.matchBy", comment: "") }
            static var deactivate: String { ls("records.duplicates.deactivate", comment: "") }
            static var emptyTitle: String { ls("records.duplicates.emptyTitle", comment: "") }
            static var emptyMessage: String { ls("records.duplicates.emptyMessage", comment: "") }
            static var bannerTitle: String { ls("records.duplicates.bannerTitle", comment: "") }
        }
    }

    // MARK: - Filters

    enum Filters {
        static var title: String { ls("filters.title", comment: "") }
        static var all: String { ls("filters.all", comment: "") }
        static var allAccounts: String { ls("filters.allAccounts", comment: "") }
        static var allCategories: String { ls("filters.allCategories", comment: "") }
        static var clearFilters: String { ls("filters.clearFilters", comment: "") }
        static var selectCategories: String {
            ls("filters.selectCategories", comment: "")
        }
        static var selectAll: String {
            ls("filters.selectAll", comment: "")
        }
        static var deselectAll: String {
            ls("filters.deselectAll", comment: "")
        }
        static var noSubcategories: String {
            ls("filters.noSubcategories", comment: "")
        }
        static var noneSelected: String {
            ls("filters.noneSelected", comment: "")
        }
        static var allSubcategories: String {
            ls("filters.allSubcategories", comment: "")
        }
        static var filterOptions: String {
            ls("filters.filterOptions", comment: "")
        }
        static var noteContains: String {
            ls("filters.noteContains", comment: "")
        }
        static var selectAccounts: String {
            ls("filters.selectAccounts", comment: "")
        }
        static var selectTags: String {
            ls("filters.selectTags", comment: "")
        }
        static var selectCurrencies: String {
            ls("filters.selectCurrencies", comment: "")
        }
        static var allTags: String {
            ls("filters.allTags", comment: "")
        }
        static var noTags: String {
            ls("filters.noTags", comment: "")
        }
        static var allCurrencies: String {
            ls("filters.allCurrencies", comment: "")
        }
        static var allNeeds: String {
            ls("filters.allNeeds", comment: "")
        }
        static func selectedCount(_ count: Int) -> String {
            String(format: ls("filters.selectedCount", comment: ""), count)
        }
        static func subcategoriesSelectedCount(_ count: Int) -> String {
            String(format: ls("filters.subcategoriesSelectedCount", comment: ""), count)
        }
        static var categories: String { ls("filters.categories", comment: "") }
        static var type: String { ls("filters.type", comment: "") }
        static var need: String { ls("filters.need", comment: "") }
        static var currency: String { ls("filters.currency", comment: "") }
        static var includeMode: String { ls("filters.includeMode", comment: "") }
        static var excludeMode: String { ls("filters.excludeMode", comment: "") }
        static var nothingExcluded: String { ls("filters.nothingExcluded", comment: "") }
        static func datePrefix(_ date: String) -> String { String(format: ls("filters.datePrefix %@", comment: ""), date) }
    }

    // MARK: - Actions

    enum Action {
        static var apply: String { ls("action.apply", comment: "") }
        static var cancel: String { ls("action.cancel", comment: "") }
        static var done: String { ls("action.done", comment: "") }
        static var save: String { ls("action.save", comment: "") }
        static var delete: String { ls("action.delete", comment: "") }
        static var edit: String { ls("action.edit", comment: "") }
        static var add: String { ls("action.add", comment: "") }
        static var viewAll: String { ls("action.viewAll", comment: "") }
        static var viewLess: String { ls("action.viewLess", comment: "") }
        static var multipleEdit: String { ls("action.multipleEdit", comment: "") }
        static var back: String { ls("action.back", comment: "") }
        static var next: String { ls("action.next", comment: "") }
        static var duplicate: String { ls("action.duplicate", comment: "") }
        static var favorite: String { ls("action.favorite", comment: "") }
        static var recurring: String { ls("action.recurring", comment: "") }
        static var saveAsFavorite: String { ls("action.saveAsFavorite", comment: "") }
        static var saveAsRecurring: String { ls("action.saveAsRecurring", comment: "") }
        static var savedAsFavorite: String { ls("action.savedAsFavorite", comment: "") }
        static var savedAsRecurring: String { ls("action.savedAsRecurring", comment: "") }
        static var duplicated: String { ls("action.duplicated", comment: "") }
        static var select: String { ls("action.select", comment: "") }
        static var retry: String { ls("action.retry", comment: "") }
        static var later: String { ls("action.later", comment: "") }
        static var close: String { ls("action.close", comment: "") }
        static var reorder: String { ls("action.reorder", comment: "") }
        static var clearAll: String { ls("action.clearAll", comment: "") }
        static var calculate: String { ls("action.calculate", comment: "") }
        // Naming `continueAction` para evitar choque con keyword `continue` de Swift.
        static var continueAction: String { ls("action.continue", comment: "") }
    }

    // MARK: - Split Calculator

    enum Split {
        static var title: String { ls("split.title", comment: "") }
        static var totalAmount: String { ls("split.totalAmount", comment: "") }
        static var yourPortion: String { ls("split.yourPortion", comment: "") }
        static var useAmount: String { ls("split.useAmount", comment: "") }
        static var typePercentage: String { ls("split.typePercentage", comment: "") }
        static var typeEqual: String { ls("split.typeEqual", comment: "") }
        static var typeExact: String { ls("split.typeExact", comment: "") }
        static var typeShares: String { ls("split.typeShares", comment: "") }
        // Short labels for the segmented selector (full names stay in the chip below the amount).
        static var typePercentageShort: String { ls("split.typePercentageShort", comment: "") }
        static var typeEqualShort: String { ls("split.typeEqualShort", comment: "") }
        static var typeExactShort: String { ls("split.typeExactShort", comment: "") }
        static var typeSharesShort: String { ls("split.typeSharesShort", comment: "") }
        // Inline labels for the "Dividido [modo]" chip below the amount (GroupExpenseFormView).
        static var inlineEqual: String { ls("split.inlineEqual", comment: "") }
        static var inlinePercentage: String { ls("split.inlinePercentage", comment: "") }
        static var inlineExact: String { ls("split.inlineExact", comment: "") }
        static var inlineShares: String { ls("split.inlineShares", comment: "") }
        static var percentage: String { ls("split.percentage", comment: "") }
        static var people: String { ls("split.people", comment: "") }
        static var yourPart: String { ls("split.yourPart", comment: "") }
        static var yourShares: String { ls("split.yourShares", comment: "") }
        static var totalShares: String { ls("split.totalShares", comment: "") }
        static var tipPercentage: String { ls("split.tipPercentage", comment: "") }
        static var tipEqual: String { ls("split.tipEqual", comment: "") }
        static var tipExact: String { ls("split.tipExact", comment: "") }
        static var tipShares: String { ls("split.tipShares", comment: "") }
        // Description templates for chip display
        static func descPercentage(_ pct: String, _ total: String) -> String { String(format: ls("split.descPercentage %@ %@", comment: ""), pct, total) }
        static func descEqual(_ people: Int) -> String { String(format: ls("split.descEqual %d", comment: ""), people) }
        static func descShares(_ my: Int, _ total: Int) -> String { String(format: ls("split.descShares %d %d", comment: ""), my, total) }
        static func descExact(_ amount: String) -> String { String(format: ls("split.descExact %@", comment: ""), amount) }
        // Shares inline labels
        static var sharesYouPay: String { ls("split.sharesYouPay", comment: "") }
        static var sharesOf: String { ls("split.sharesOf", comment: "") }
        static var sharesParts: String { ls("split.sharesParts", comment: "") }
        // Chip detail labels (renderiza "Tu: X · Resto: Y" debajo del monto en GroupExpenseFormView)
        static var totalLabel: String { ls("split.totalLabel", comment: "") }
        static var youLabel: String { ls("split.you", comment: "") }
        static var restLabel: String { ls("split.rest", comment: "") }
        /// "Pagaste todo" — chip cuando current user paga pero NO participa en la división.
        static var youPaidAll: String { ls("split.youPaidAll", comment: "") }
        /// "(50%)" — suffix percentual del chip-detalle. `pct` ya viene como string trimmed (ej. "50" o "33.3").
        static func percentSuffix(_ pct: String) -> String {
            String(format: ls("split.percentSuffix %@", comment: ""), pct)
        }
        /// "(1/3 partes)" — suffix de proporciones del chip-detalle.
        static func sharesSuffix(_ n: Int, _ total: Int) -> String {
            String(format: ls("split.sharesSuffix %d %d", comment: ""), n, total)
        }
    }

    // MARK: - Groups

    enum Groups {
        static var title: String { ls("groups.title", comment: "") }
        static var newGroup: String { ls("groups.new", comment: "") }
        static var editGroup: String { ls("groups.edit", comment: "") }
        /// Título del sheet selector de grupo (al crear un gasto desde el FAB del tab).
        static var selectGroup: String { ls("groups.selectGroup", comment: "") }
        /// Etiqueta singular "Grupo" — chip de contexto de grupo en el form de gasto.
        static var groupLabel: String { ls("groups.groupLabel", comment: "") }

        enum Empty {
            static var title: String { ls("groups.empty.title", comment: "") }
            static var message: String { ls("groups.empty.message", comment: "") }
            static var action: String { ls("groups.empty.action", comment: "") }
        }

        enum Summary {
            static var owedToMe: String { ls("groups.summary.owedToMe", comment: "") }
            static var iOwe: String { ls("groups.summary.iOwe", comment: "") }
            static var pendingSettlements: String { ls("groups.summary.pendingSettlements", comment: "") }
            static var allSettled: String { ls("groups.summary.allSettled", comment: "") }
        }

        enum Detail {
            static var records: String { ls("groups.detail.records", comment: "") }
            static var balances: String { ls("groups.detail.balances", comment: "") }
            static var stats: String { ls("groups.detail.stats", comment: "") }
            static var comingSoon: String { ls("groups.detail.comingSoon", comment: "") }
            // A0-Bridge V2.0 (P1-3): CTA desde TX bridgeada read-only
            static var openGroup: String { ls("groups.detail.openGroup", comment: "") }
            // Banda de balance del header del detalle
            static var yourBalance: String { ls("groups.detail.yourBalance", comment: "") }
            static var settledUp: String { ls("groups.detail.settledUp", comment: "") }
            static func memberCount(_ count: Int) -> String { String(format: ls("groups.detail.memberCount", comment: ""), count) }
        }

        enum Options {
            static var ownerOnlyHint: String { ls("groups.options.ownerOnlyHint", comment: "") }
        }

        enum Stats {
            static var totalSpent: String { ls("groups.stats.totalSpent", comment: "") }
            static var myPortion: String { ls("groups.stats.myPortion", comment: "") }
            static var whoMadeMostPayments: String { ls("groups.stats.whoMadeMostPayments", comment: "") }
            static var categories: String { ls("groups.stats.categories", comment: "") }
            static var monthlyTrend: String { ls("groups.stats.monthlyTrend", comment: "") }
            static var noExpenses: String { ls("groups.stats.noExpenses", comment: "") }
            static var uncategorized: String { ls("groups.stats.uncategorized", comment: "") }
            static var thisMonth: String { ls("groups.stats.thisMonth", comment: "") }
            static var last3Months: String { ls("groups.stats.last3Months", comment: "") }
            static var last6Months: String { ls("groups.stats.last6Months", comment: "") }
            static var thisYear: String { ls("groups.stats.thisYear", comment: "") }
            static var allTime: String { ls("groups.stats.allTime", comment: "") }
            static var assignCategoriesHint: String {
                ls("groups.stats.assignCategoriesHint", comment: "")
            }
            static func convertedToNote(_ currency: String) -> String {
                String(format: ls("groups.stats.convertedToNote", comment: "Nota bajo el donut (modo Todas): moneda destino de la conversión"), currency)
            }
        }

        // MARK: - Bridge (A0-Bridge)

        enum OpeningBalance {
            /// Descripción del SplitExpense de saldo inicial (también label base del feed).
            static var entryDescription: String { ls("groups.openingBalance.entryDescription", comment: "") }
            /// Fila del feed: "%1$@ le debe a %2$@".
            static func feedRow(_ debtor: String, _ creditor: String) -> String {
                String(format: ls("groups.openingBalance.feedRow", comment: ""), debtor, creditor)
            }
            // Editor
            static var editorTitle: String { ls("groups.openingBalance.editorTitle", comment: "") }
            static var debtorLabel: String { ls("groups.openingBalance.debtorLabel", comment: "") }   // "Quién debe"
            static var creditorLabel: String { ls("groups.openingBalance.creditorLabel", comment: "") } // "A quién"
            static var dateLabel: String { ls("groups.openingBalance.dateLabel", comment: "") }       // "Fecha"
            // Sección de Ajustes (owner-only)
            static var sectionTitle: String { ls("groups.openingBalance.sectionTitle", comment: "") }
            static var addButton: String { ls("groups.openingBalance.addButton", comment: "") }
            static var emptyState: String { ls("groups.openingBalance.emptyState", comment: "") }
            /// Rollup por miembro: "%@ debe" (deudor neto).
            static var rollupOwes: String { ls("groups.openingBalance.rollupOwes", comment: "") }
            /// Rollup por miembro: "a %@ le deben" (acreedor neto).
            static var rollupOwed: String { ls("groups.openingBalance.rollupOwed", comment: "") }
            // Atajo al aprobar miembro
            static func approvalPromptTitle(_ name: String) -> String {
                String(format: ls("groups.openingBalance.approvalPromptTitle", comment: ""), name)
            }
            static var approvalPromptBody: String { ls("groups.openingBalance.approvalPromptBody", comment: "") }
            static var approvalPromptAdd: String { ls("groups.openingBalance.approvalPromptAdd", comment: "") }
            static var approvalPromptSkip: String { ls("groups.openingBalance.approvalPromptSkip", comment: "") }
            // Errores
            static var errorNotOwner: String { ls("groups.openingBalance.errorNotOwner", comment: "") }
            static var errorSameMember: String { ls("groups.openingBalance.errorSameMember", comment: "") }
        }

        enum Bridge {
            // Delete guards
            static var deleteExpenseBlocked: String { ls("groups.bridge.deleteExpenseBlocked", comment: "") }
            // Read-only TX edit
            static var editFromGroup: String { ls("groups.bridge.editFromGroup", comment: "") }
            static var assignFromInbox: String { ls("groups.bridge.assignFromInbox", comment: "") }
            static var editSettlementInGroup: String { ls("groups.bridge.editSettlementInGroup", comment: "") }
            // M6: Caso A edit parcial banner + draft hint reasons
            static var editPartialBanner: String { ls("groups.bridge.editPartialBanner", comment: "") }
            static var draftReasonRemoteCreate: String { ls("groups.bridge.draftReasonRemoteCreate", comment: "") }
            static var draftReasonCurrencyChanged: String { ls("groups.bridge.draftReasonCurrencyChanged", comment: "") }
            // Activation/deactivation modals (F12)
            static var activateTitle: String { ls("groups.bridge.activateTitle", comment: "") }
            static func activateBody(_ count: Int) -> String {
                String(format: ls("groups.bridge.activateBody", comment: ""), count)
            }
            static var activateOptionFromNow: String { ls("groups.bridge.activateOptionFromNow", comment: "") }
            static var activateOptionFromNowHint: String { ls("groups.bridge.activateOptionFromNowHint", comment: "") }
            static var activateOptionImportAll: String { ls("groups.bridge.activateOptionImportAll", comment: "") }
            static func activateOptionImportAllHint(_ count: Int) -> String {
                String(format: ls("groups.bridge.activateOptionImportAllHint", comment: ""), count)
            }
            static var activateImportRegenerationNote: String { ls("groups.bridge.activateImportRegenerationNote", comment: "") }
            static var deactivateTitle: String { ls("groups.bridge.deactivateTitle", comment: "") }
            static var deactivateBody: String { ls("groups.bridge.deactivateBody", comment: "") }
            static var deactivateOptionDelete: String { ls("groups.bridge.deactivateOptionDelete", comment: "") }
            static var deactivateOptionKeep: String { ls("groups.bridge.deactivateOptionKeep", comment: "") }
            // Deactivation sheet (F5)
            static var deactivationSheetTitle: String { ls("groups.bridge.deactivationSheetTitle", comment: "") }
            static var deactivationSheetBody: String { ls("groups.bridge.deactivationSheetBody", comment: "") }
            static var deactivationOptionFreeze: String { ls("groups.bridge.deactivationOptionFreeze", comment: "") }
            static var deactivationOptionDelete: String { ls("groups.bridge.deactivationOptionDelete", comment: "") }
            static var importing: String { ls("groups.bridge.importing", comment: "") }
            static var importError: String { ls("groups.bridge.importError", comment: "") }
            // Upsell para .groupInvite users
            static var upsellGroupInviteSettlement: String { ls("groups.bridge.upsellGroupInviteSettlement", comment: "") }
            // Opt-out alert (F2c)
            static var optoutAlertTitle: String { ls("groups.bridge.optoutAlertTitle", comment: "") }
            static var optoutAlertBody: String { ls("groups.bridge.optoutAlertBody", comment: "") }
            static var optoutAlertYes: String { ls("groups.bridge.optoutAlertYes", comment: "") }
            static var optoutAlertNo: String { ls("groups.bridge.optoutAlertNo", comment: "") }
        }

        enum GlobalSettings {
            static var title: String { ls("groups.globalSettings.title", comment: "") }
            static var bridgeSectionTitle: String { ls("groups.globalSettings.bridgeSectionTitle", comment: "") }
            static var bridgeToggleLabel: String { ls("groups.globalSettings.bridgeToggleLabel", comment: "") }
            static var bridgeCaption: String { ls("groups.globalSettings.bridgeCaption", comment: "") }
            static var visibilitySectionTitle: String { ls("groups.globalSettings.visibilitySectionTitle", comment: "") }
            static var visibilityCaption: String { ls("groups.globalSettings.visibilityCaption", comment: "") }
            static var includeGroupTransactionsInFeedLabel: String { ls("groups.globalSettings.includeGroupTransactionsInFeedLabel", comment: "") }
        }

        enum Form {
            static var name: String { ls("groups.form.name", comment: "") }
            static var namePlaceholder: String { ls("groups.form.namePlaceholder", comment: "") }
            static var currency: String { ls("groups.form.currency", comment: "") }
            static var icon: String { ls("groups.form.icon", comment: "") }
            static var simplifyDebts: String { ls("groups.form.simplifyDebts", comment: "") }
            static var simplifyDebtsHint: String { ls("groups.form.simplifyDebtsHint", comment: "") }
            static var showDebtsInSingleCurrency: String { ls("groups.form.showDebtsInSingleCurrency", comment: "") }
            static var showDebtsInSingleCurrencyHint: String { ls("groups.form.showDebtsInSingleCurrencyHint", comment: "") }
            static var defaultSplitType: String { ls("groups.form.defaultSplitType", comment: "") }
            static var membersCanInvite: String { ls("groups.form.membersCanInvite", comment: "") }
            static var membersCanInviteHint: String { ls("groups.form.membersCanInviteHint", comment: "") }
        }

        enum Settings {
            static var title: String { ls("groups.settings.title", comment: "") }
            static var members: String { ls("groups.settings.members", comment: "") }
            static var addMember: String { ls("groups.settings.addMember", comment: "") }
            static var addMemberPrompt: String { ls("groups.settings.addMemberPrompt", comment: "") }
            static var invite: String { ls("groups.settings.invite", comment: "") }
            static var inviteLinkHint: String { ls("groups.settings.inviteLinkHint", comment: "") }
            static var leaveGroup: String { ls("groups.settings.leaveGroup", comment: "") }
            static var leaveGroupConfirm: String { ls("groups.settings.leaveGroupConfirm", comment: "") }
            static var leaveGroupWithDebtWarning: String { ls("groups.settings.leaveGroupWithDebtWarning", comment: "") }
            static var deleteGroup: String { ls("groups.settings.deleteGroup", comment: "") }
            static var deleteGroupConfirm: String { ls("groups.settings.deleteGroupConfirm", comment: "") }
            static var deleteGroupFinalConfirm: String { ls("groups.settings.deleteGroupFinalConfirm", comment: "") }
            static var deleteGroupDisabledHint: String { ls("groups.settings.deleteGroupDisabledHint", comment: "") }
            static var archive: String { ls("groups.settings.archive", comment: "") }
            static var unarchive: String { ls("groups.settings.unarchive", comment: "") }
            static var archiveHint: String { ls("groups.settings.archiveHint", comment: "") }
            static var archiveConfirm: String { ls("groups.settings.archiveConfirm", comment: "") }
            static var archiveWithDebtWarning: String { ls("groups.settings.archiveWithDebtWarning", comment: "") }
            static var generatingInvite: String { ls("groups.settings.generatingInvite", comment: "") }
            static var options: String { ls("groups.settings.options", comment: "") }
            static var info: String { ls("groups.settings.info", comment: "") }
            static var showArchived: String { ls("groups.settings.showArchived", comment: "") }
            static func showArchivedCount(_ count: Int) -> String { String(format: ls("groups.settings.showArchivedCount", comment: ""), count) }
            static var hideArchived: String { ls("groups.settings.hideArchived", comment: "") }
            // Personal integration (Bridge override per-grupo, F4)
            static var personalIntegrationSectionTitle: String { ls("groups.settings.personalIntegrationSectionTitle", comment: "") }
            static var personalIntegrationToggleLabel: String { ls("groups.settings.personalIntegrationToggleLabel", comment: "") }
            static var personalIntegrationHintInheritOn: String { ls("groups.settings.personalIntegrationHintInheritOn", comment: "") }
            static var personalIntegrationHintLocalOff: String { ls("groups.settings.personalIntegrationHintLocalOff", comment: "") }
            static var personalIntegrationHintBlockedByGlobal: String { ls("groups.settings.personalIntegrationHintBlockedByGlobal", comment: "") }
        }

        enum Errors {
            /// surfaced cuando el current user pending intenta una acción que requiere active.
            static var pendingApproval: String { ls("groups.errors.pendingApproval", comment: "") }
            /// Acción de grupo que necesita el sync pero el primer import de iCloud no se asentó.
            static var syncPreparing: String { ls("groups.errors.syncPreparing", comment: "") }
            /// Falló la generación del enlace de invitación.
            static var inviteFailed: String { ls("groups.errors.inviteFailed", comment: "") }
            /// Fallo genérico de una acción de grupo (eliminar gasto, liquidar, aprobar/rechazar).
            static var actionFailed: String { ls("groups.errors.actionFailed", comment: "") }
            /// El usuario elige "Solo grupos" sin cuenta iCloud activa (grupos exige iCloud).
            static var iCloudRequiredTitle: String { ls("groups.errors.iCloudRequiredTitle", comment: "") }
            static var iCloudRequiredBody: String { ls("groups.errors.iCloudRequiredBody", comment: "") }
            /// G6-3: el grupo se migró a la nube de Yala y está congelado en este device (hay que re-entrar).
            static var movedToBackend: String { ls("groups.errors.movedToBackend", comment: "") }
        }

        /// G6-3: grupo migrado a la nube de Yala (congelado en CloudKit) — banner/CTA/borrar copia.
        enum Migrated {
            /// Banner de progreso del uploader ("moviendo tus grupos a la nube de Yala…").
            static var migratingBanner: String { ls("groups.migrated.migratingBanner", comment: "") }
            static var bannerTitle: String { ls("groups.migrated.bannerTitle", comment: "") }
            static var bannerBody: String { ls("groups.migrated.bannerBody", comment: "") }
            static var rejoinCTA: String { ls("groups.migrated.rejoinCTA", comment: "") }
            static var deleteCopyRow: String { ls("groups.migrated.deleteCopyRow", comment: "") }
            static var deleteCopyHint: String { ls("groups.migrated.deleteCopyHint", comment: "") }
            static var deleteCopyConfirmTitle: String { ls("groups.migrated.deleteCopyConfirmTitle", comment: "") }
            static var deleteCopyConfirmBody: String { ls("groups.migrated.deleteCopyConfirmBody", comment: "") }
            static var deleteCopyConfirmButton: String { ls("groups.migrated.deleteCopyConfirmButton", comment: "") }
        }

        /// G4-invites (A2, §8): consentimiento informado de grupos (molde Storage.Consent).
        enum Consent {
            static var title: String { ls("groups.consent.title", comment: "") }
            static var point1: String { ls("groups.consent.point1", comment: "") }
            static var point2: String { ls("groups.consent.point2", comment: "") }
            static var point3: String { ls("groups.consent.point3", comment: "") }
            static var point4: String { ls("groups.consent.point4", comment: "") }
            static var accept: String { ls("groups.consent.accept", comment: "") }
        }

        /// G4-invites (A2, §16d): sign-in solo-grupos (SIWA para unirse por link backend).
        enum SignIn {
            static var title: String { ls("groups.signin.title", comment: "") }
            static var body: String { ls("groups.signin.body", comment: "") }
            /// Invariante R9: esta será LA cuenta si algún día migra lo personal.
            static var accountNote: String { ls("groups.signin.accountNote", comment: "") }
            static var error: String { ls("groups.signin.error", comment: "") }
        }

        /// #26: chips mostrados en GroupCardView cuando el current user está
        /// en estado pendingApproval o rejected (en lugar del balance trailing).
        enum Card {
            static var pendingApprovalChip: String { ls("groups.card.pendingApprovalChip", comment: "") }
            static var rejectedChip: String { ls("groups.card.rejectedChip", comment: "") }
            /// G6-3: chip "se movió" en la card de un grupo migrado y congelado.
            static var movedChip: String { ls("groups.card.movedChip", comment: "") }
            static var leaveGroupAlertTitle: String { ls("groups.card.leaveGroupAlertTitle", comment: "") }
            static var leaveGroupAlertBody: String { ls("groups.card.leaveGroupAlertBody", comment: "") }
            // M6 D3: chip overflow cuando hay más de 3 deudas en la card.
            static func moreDebts(_ count: Int) -> String {
                String(format: ls("groups.card.moreDebts", comment: ""), count)
            }
            /// "%@ te debe" — otro miembro le debe al usuario actual (perspectiva theyOweMe).
            static func theyOweYou(_ name: String) -> String {
                String(format: ls("groups.card.theyOweYou", comment: ""), name)
            }
            /// "Le debes a %@" — el usuario actual le debe a otro miembro (perspectiva iOwe).
            static func youOwe(_ name: String) -> String {
                String(format: ls("groups.card.youOwe", comment: ""), name)
            }
        }

        enum Member {
            static var admin: String { ls("groups.member.admin", comment: "") }
            static var member: String { ls("groups.member.member", comment: "") }
            static var you: String { ls("groups.member.you", comment: "") }
            static var deletedUser: String { ls("groups.member.deletedUser", comment: "") }
            static var left: String { ls("groups.member.left", comment: "") }
            static var removed: String { ls("groups.member.removed", comment: "") }
            static var changeRole: String { ls("groups.member.changeRole", comment: "") }
            static var remove: String { ls("groups.member.remove", comment: "") }
            static var removeConfirm: String { ls("groups.member.removeConfirm", comment: "") }
            static var removeWithDebtWarning: String { ls("groups.member.removeWithDebtWarning", comment: "") }
            static var actions: String { ls("groups.member.actions", comment: "") }
            static func activeCount(_ count: Int) -> String { String(format: ls("groups.member.activeCount", comment: ""), count) }
            static func pendingCount(_ count: Int) -> String { String(format: ls("groups.member.pendingCount", comment: ""), count) }
            static var statusPending: String { ls("groups.member.statusPending", comment: "") }
            static var statusRejected: String { ls("groups.member.statusRejected", comment: "") }
            static var approve: String { ls("groups.member.approve", comment: "") }
            static var reject: String { ls("groups.member.reject", comment: "") }
            static func approveConfirm(_ name: String) -> String {
                String(format: ls("groups.member.approveConfirm", comment: ""), name)
            }
            static func rejectConfirm(_ name: String) -> String {
                String(format: ls("groups.member.rejectConfirm", comment: ""), name)
            }
            static var pendingRequestsSection: String { ls("groups.member.pendingRequestsSection", comment: "") }
            static func pendingRequestsCount(_ count: Int) -> String {
                String(format: ls("groups.member.pendingRequestsCount", comment: ""), count)
            }
        }

        enum Balance {
            static var title: String { ls("groups.balance.title", comment: "") }
            static var noDebts: String { ls("groups.balance.noDebts", comment: "") }
            static var pendingDebts: String { ls("groups.balance.pendingDebts", comment: "") }
            static var settlements: String { ls("groups.balance.settlements", comment: "") }
            static var confirmed: String { ls("groups.balance.confirmed", comment: "") }
            static var pending: String { ls("groups.balance.pending", comment: "") }
        }

        enum Expense {
            static var noExpenses: String { ls("groups.expense.noExpenses", comment: "") }
            static var newExpense: String { ls("groups.expense.newExpense", comment: "") }
            static var paidByTitle: String { ls("groups.expense.paidByTitle", comment: "") }
            /// "Pagaste %@" — when current user is the payer.
            static func youPaid(_ amount: String) -> String {
                String(format: ls("groups.expense.youPaid", comment: ""), amount)
            }
            /// "%@ pagó %@" — when another member is the payer.
            static func memberPaid(_ name: String, _ amount: String) -> String {
                String(format: ls("groups.expense.memberPaid", comment: ""), name, amount)
            }
            /// Caption: "Prestaste" — current user paid, others owe.
            static var youAreOwed: String { ls("groups.expense.youAreOwed", comment: "") }
            /// Caption: "Te prestaron" — current user owes their share.
            static var youOwe: String { ls("groups.expense.youOwe", comment: "") }
            /// Caption: "No participaste" — current user not in the split.
            static var notIncluded: String { ls("groups.expense.notIncluded", comment: "") }
            static var selectAll: String { ls("groups.expense.selectAll", comment: "") }
            static var deselectAll: String { ls("groups.expense.deselectAll", comment: "") }
            static func membersSelected(_ count: Int, _ total: Int) -> String {
                String(format: ls("groups.expense.membersSelected %d %d", comment: ""), count, total)
            }
            /// Chip "Dividir entre" cuando TODOS los miembros están seleccionados.
            static var allMembers: String { ls("groups.expense.allMembers", comment: "") }
            /// Título (toolbar) del sheet de división del gasto.
            static var dividePayment: String { ls("groups.expense.dividePayment", comment: "") }
            /// Label inline antes del chip de modo de división ("Dividido [en partes iguales]").
            static var dividedLabel: String { ls("groups.expense.dividedLabel", comment: "") }
            /// Alert al tocar el chip "Dividido" (o la pre-pantalla de 2 personas) con monto 0:
            /// no se abre el sheet de división (dividir 0 no tiene sentido) y se pide el monto.
            static var amountRequiredTitle: String { ls("groups.expense.amountRequiredTitle", comment: "") }
            static var amountRequiredMessage: String { ls("groups.expense.amountRequiredMessage", comment: "") }
            /// Banner cuando lo asignado supera el total.
            static func overAllocated(_ amount: String) -> String {
                String(format: ls("groups.expense.overAllocated %@", comment: ""), amount)
            }
            /// Pre-pantalla de split rápido para grupos de 2: 4 opciones en lenguaje natural.
            enum TwoPerson {
                /// Título (toolbar) del sheet de 4 opciones.
                static var sheetTitle: String { ls("groups.expense.twoPerson.sheetTitle", comment: "") }
                /// Acción: pagaste tú, partes iguales.
                static var actionIPaidEqual: String { ls("groups.expense.twoPerson.actionIPaidEqual", comment: "") }
                /// Acción: pagaste tú, el gasto es todo de %@.
                static func actionIPaidOwedFull(_ name: String) -> String {
                    String(format: ls("groups.expense.twoPerson.actionIPaidOwedFull", comment: ""), name)
                }
                /// Acción: pagó %@, partes iguales.
                static func actionTheyPaidEqual(_ name: String) -> String {
                    String(format: ls("groups.expense.twoPerson.actionTheyPaidEqual", comment: ""), name)
                }
                /// Acción: pagó %@, el gasto es todo tuyo.
                static func actionTheyPaidOwedFull(_ name: String) -> String {
                    String(format: ls("groups.expense.twoPerson.actionTheyPaidOwedFull", comment: ""), name)
                }
                /// Deuda: "%1$@ te debe %2$@" (nombre, monto).
                static func theyOweAmount(_ name: String, _ amount: String) -> String {
                    String(format: ls("groups.expense.twoPerson.theyOweAmount", comment: ""), name, amount)
                }
                /// Deuda: "Le debes %2$@ a %1$@" (nombre, monto).
                static func youOweAmount(_ name: String, _ amount: String) -> String {
                    String(format: ls("groups.expense.twoPerson.youOweAmount", comment: ""), name, amount)
                }
                /// Botón: bajar al editor detallado (%, exacto, partes).
                static var moreOptions: String { ls("groups.expense.twoPerson.moreOptions", comment: "") }
                /// Botón: volver a las 4 opciones rápidas desde el editor detallado.
                static var quickOptions: String { ls("groups.expense.twoPerson.quickOptions", comment: "") }
            }
            /// Título + explicación del sheet de división, por tipo.
            enum SplitSheet {
                static var equalTitle: String { ls("groups.expense.splitSheet.equalTitle", comment: "") }
                static var equalHint: String { ls("groups.expense.splitSheet.equalHint", comment: "") }
                static var percentageTitle: String { ls("groups.expense.splitSheet.percentageTitle", comment: "") }
                static var percentageHint: String { ls("groups.expense.splitSheet.percentageHint", comment: "") }
                static var exactTitle: String { ls("groups.expense.splitSheet.exactTitle", comment: "") }
                static var exactHint: String { ls("groups.expense.splitSheet.exactHint", comment: "") }
                static var sharesTitle: String { ls("groups.expense.splitSheet.sharesTitle", comment: "") }
                static var sharesHint: String { ls("groups.expense.splitSheet.sharesHint", comment: "") }
            }
            /// Pantalla de éxito tras crear/editar un gasto de grupo (GroupExpenseSuccessView).
            enum Success {
                static var titleCreated: String { ls("groups.expense.success.titleCreated", comment: "") }
                static var titleUpdated: String { ls("groups.expense.success.titleUpdated", comment: "") }
                static var group: String { ls("groups.expense.success.group", comment: "") }
                static var splitLabel: String { ls("groups.expense.success.splitLabel", comment: "") }
                static var participants: String { ls("groups.expense.success.participants", comment: "") }
                static var addAnother: String { ls("groups.expense.success.addAnother", comment: "") }
            }
            static var title: String { ls("groups.expense.title", comment: "") }
            static var editTitle: String { ls("groups.expense.editTitle", comment: "") }
            static var descriptionLabel: String { ls("groups.expense.description", comment: "") }
            static var descriptionPlaceholder: String { ls("groups.expense.descriptionPlaceholder", comment: "") }
            static var noteLabel: String { ls("groups.expense.note", comment: "") }
            static var notePlaceholder: String { ls("groups.expense.notePlaceholder", comment: "") }
            static var category: String { ls("groups.expense.category", comment: "") }
            static var currency: String { ls("groups.expense.currency", comment: "") }
            static var date: String { ls("groups.expense.date", comment: "") }
            static var splitType: String { ls("groups.expense.splitType", comment: "") }
            static var remaining: String { ls("groups.expense.remaining", comment: "") }
            static func remainingAmount(_ amount: String) -> String { String(format: ls("groups.expense.remainingAmount", comment: ""), amount) }
            static var balanced: String { ls("groups.expense.balanced", comment: "") }
            static var eachPays: String { ls("groups.expense.eachPays", comment: "") }
        }

        enum Settlement {
            static var title: String { ls("groups.settlement.title", comment: "") }
            static var payTo: String { ls("groups.settlement.payTo", comment: "") }
            static var registerPayment: String { ls("groups.settlement.registerPayment", comment: "") }
            static var confirm: String { ls("groups.settlement.confirm", comment: "") }
            static var reject: String { ls("groups.settlement.reject", comment: "") }
            static var settle: String { ls("groups.settlement.settle", comment: "") }
            static var settleHint: String { ls("groups.settlement.settleHint", comment: "") }
            static var confirmQuestion: String { ls("groups.settlement.confirmQuestion", comment: "") }
            static var rejectQuestion: String { ls("groups.settlement.rejectQuestion", comment: "") }
            // A0-Bridge Caso C proactivo
            static var fromAccount: String { ls("groups.settlement.fromAccount", comment: "") }
            static var fromAccountNone: String { ls("groups.settlement.fromAccountNone", comment: "") }
        }

        enum Notifications {
            static var promptTitle: String { ls("groups.notifications.prompt.title", comment: "") }
            static var promptMessage: String { ls("groups.notifications.prompt.message", comment: "") }
            static var promptEnable: String { ls("groups.notifications.prompt.enable", comment: "") }
            /// title de la notif "👋 %@ quiere unirse a %@" — solo recibida por admins.
            static func newPendingRequest(_ name: String, _ groupName: String) -> String {
                String(format: ls("groups.notifications.newPendingRequest", comment: ""), name, groupName)
            }
            /// body de la notif: "Aprueba o rechaza desde Yala."
            static var newPendingRequestBody: String {
                ls("groups.notifications.newPendingRequestBody", comment: "")
            }
        }

        enum Invite {
            static var welcome: String { ls("groups.invite.welcome", comment: "") }
            static func welcomeWithGroup(_ name: String) -> String { String(format: ls("groups.invite.welcomeWithGroup", comment: ""), name) }
            static var subtitle: String { ls("groups.invite.subtitle", comment: "") }
            static var namePlaceholder: String { ls("groups.invite.namePlaceholder", comment: "") }
            static var joinButton: String { ls("groups.invite.joinButton", comment: "") }
            static var ready: String { ls("groups.invite.ready", comment: "") }
            static var goToGroup: String { ls("groups.invite.goToGroup", comment: "") }
            static var waitingApprovalTitle: String { ls("groups.invite.waitingApproval.title", comment: "") }
            static var waitingApprovalBody: String { ls("groups.invite.waitingApproval.body", comment: "") }
            static var waitingApprovalBanner: String { ls("groups.invite.waitingApproval.banner", comment: "") }
            static var rejectedTitle: String { ls("groups.invite.rejected.title", comment: "") }
            static var rejectedBody: String { ls("groups.invite.rejected.body", comment: "") }
            static var joiningTitle: String { ls("groups.invite.joining.title", comment: "") }
            static var joiningBody: String { ls("groups.invite.joining.body", comment: "") }
            static var slowTitle: String { ls("groups.invite.slow.title", comment: "") }
            static var slowBody: String { ls("groups.invite.slow.body", comment: "") }
            static var slowContinueButton: String { ls("groups.invite.slow.continueButton", comment: "") }
            static var errorTitle: String { ls("groups.invite.error.title", comment: "") }
            static var errorBody: String { ls("groups.invite.error.body", comment: "") }
            static var errorExitButton: String { ls("groups.invite.error.exitButton", comment: "") }
            static var syncBanner: String { ls("groups.invite.syncBanner", comment: "") }
            static var expiredBanner: String { ls("groups.invite.expired.banner", comment: "") }
        }

        enum Reconnect {
            static var title: String { ls("groups.reconnect.title", comment: "") }
            static var subtitle: String { ls("groups.reconnect.subtitle", comment: "") }
            static func subtitleWithGroup(_ name: String) -> String { String(format: ls("groups.reconnect.subtitleWithGroup", comment: ""), name) }
            /// Fallback nombre genérico cuando el invite link no trae `n=` (ej. CKShare nativo).
            static var fallbackGroupName: String { ls("groups.reconnect.fallbackGroupName", comment: "") }

            // E1 — archived
            static func archivedTitle(_ name: String) -> String { String(format: ls("groups.reconnect.archived.title", comment: ""), name) }
            static var archivedBody: String { ls("groups.reconnect.archived.body", comment: "") }
            static var archivedCta: String { ls("groups.reconnect.archived.cta", comment: "") }

            // E2 — alreadyMember
            static func alreadyMemberTitle(_ name: String) -> String { String(format: ls("groups.reconnect.alreadyMember.title", comment: ""), name) }
            static var alreadyMemberBody: String { ls("groups.reconnect.alreadyMember.body", comment: "") }
            static var alreadyMemberCta: String { ls("groups.reconnect.alreadyMember.cta", comment: "") }

            // E3 — pendingDuplicate
            static func pendingDuplicateTitle(_ name: String) -> String { String(format: ls("groups.reconnect.pendingDuplicate.title", comment: ""), name) }
            static var pendingDuplicateBody: String { ls("groups.reconnect.pendingDuplicate.body", comment: "") }
            static var pendingDuplicateCta: String { ls("groups.reconnect.pendingDuplicate.cta", comment: "") }

            // E4 — rejectedRetry
            static var rejectedRetryTitle: String { ls("groups.reconnect.rejectedRetry.title", comment: "") }
            static var rejectedRetryBody: String { ls("groups.reconnect.rejectedRetry.body", comment: "") }

            // E5 — leftRetry
            static func leftRetryTitle(_ name: String) -> String { String(format: ls("groups.reconnect.leftRetry.title", comment: ""), name) }
            static var leftRetryBody: String { ls("groups.reconnect.leftRetry.body", comment: "") }

            // E6 — removedRetry
            static func removedRetryTitle(_ name: String) -> String { String(format: ls("groups.reconnect.removedRetry.title", comment: ""), name) }
            static var removedRetryBody: String { ls("groups.reconnect.removedRetry.body", comment: "") }

            /// CTA compartido por rejectedRetry / leftRetry / removedRetry: "Volver a pedir".
            static var retryCta: String { ls("groups.reconnect.retryCta", comment: "") }

            // B-16 — override CTA cuando user pre-onboarded llega a modes que normalmente
            // navegan (alreadyMember/pendingDuplicate). MainTabView no está montado en
            // pre-onboarding → CTA dismissea + vuelve al Chooser.
            static var backToStart: String { ls("groups.reconnect.backToStart", comment: "") }

            // FU-02 — deletedForAll (grupo eliminado por owner, irreversible)
            static func deletedForAllTitle(_ name: String) -> String { String(format: ls("groups.reconnect.deletedForAll.title", comment: ""), name) }
            static var deletedForAllBody: String { ls("groups.reconnect.deletedForAll.body", comment: "") }
            static var deletedForAllCta: String { ls("groups.reconnect.deletedForAll.cta", comment: "") }
        }

        enum Activate {
            static var title: String { ls("groups.activate.title", comment: "") }
            static var subtitle: String { ls("groups.activate.subtitle", comment: "") }
            static var accountStep: String { ls("groups.activate.accountStep", comment: "") }
            static var accountName: String { ls("groups.activate.accountName", comment: "") }
            static var notificationStep: String { ls("groups.activate.notificationStep", comment: "") }
            static var notificationMessage: String { ls("groups.activate.notificationMessage", comment: "") }
            static var enableNotifications: String { ls("groups.activate.enableNotifications", comment: "") }
            static var skipNotifications: String { ls("groups.activate.skipNotifications", comment: "") }
            static var done: String { ls("groups.activate.done", comment: "") }
        }

        // MARK: Beta Gate (validación v2.0.1 — gate TEMPORAL, remover al estabilizar)

        enum Beta {
            static var title: String { ls("groups.beta.gate.title", comment: "") }
            static var message: String { ls("groups.beta.gate.message", comment: "") }
            static var haveCode: String { ls("groups.beta.gate.haveCode", comment: "") }
            static var codePrompt: String { ls("groups.beta.gate.codePrompt", comment: "") }
            static var placeholder: String { ls("groups.beta.gate.placeholder", comment: "") }
            static var wrongCode: String { ls("groups.beta.gate.wrongCode", comment: "") }
        }

        // MARK: iCloud Availability Gate (§i.8(c)2 — endurecimiento Grupos-v1)

        enum ICloudGate {
            static var title: String { ls("groups.icloud.gate.title", comment: "") }
            static var message: String { ls("groups.icloud.gate.message", comment: "") }
            static var openSettings: String { ls("groups.icloud.gate.openSettings", comment: "") }
        }

        // MARK: Nudge (GC-09)

        enum Nudge {
            // Titles (static)
            static func title(for nudge: NudgeType) -> String {
                ls("groups.nudge.\(nudge.rawValue).title", comment: "")
            }

            // CTA labels (static)
            static func cta(for nudge: NudgeType) -> String {
                ls("groups.nudge.\(nudge.rawValue).cta", comment: "")
            }

            // Messages (dynamic — some have placeholders)
            static func message(for nudge: NudgeType, context: NudgeTriggerContext) -> String {
                let template = ls("groups.nudge.\(nudge.rawValue).message", comment: "")
                switch nudge {
                case .invitedSpendingInsight:
                    return String(format: template, formattedAmount(context.totalSharedAmount))
                case .invitedPostSettlement:
                    return template
                case .invitedMonthTwo:
                    let pct = context.personalTransactionCount > 0
                        ? Int(Double(context.sharedExpenseCount) / Double(context.sharedExpenseCount + context.personalTransactionCount) * 100)
                        : 100
                    return String(format: template, pct)
                case .invitedSocialProof:
                    return String(format: template, context.groupMemberCount)
                case .dormantNewExpenses:
                    return String(format: template, context.sharedExpenseCount)
                case .sporadicImbalance:
                    return String(format: template, context.sharedExpenseCount, context.personalTransactionCount)
                case .sporadicTrendAlert:
                    return String(format: template, Int(context.monthOverMonthVariation * 100))
                default:
                    return template
                }
            }

            /// Quick format for amounts in nudge messages (no currency symbol — too complex per-user).
            private static func formattedAmount(_ amount: Double) -> String {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 0
                return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
            }
        }

        // MARK: - Groups Onboarding (3 steps informativo, primer tap del tab)

        enum Onboarding {
            // Common
            static var progressLabel: String { ls("groups.onboarding.progressLabel", comment: "") }

            // Step 1 — Hero animado
            static var step1Title: String { ls("groups.onboarding.step1.title", comment: "") }
            static var step1Subtitle: String { ls("groups.onboarding.step1.subtitle", comment: "") }
            static var step1DemoMemberName: String { ls("groups.onboarding.step1.demoMemberName", comment: "") }
            static var step1DemoGroupName: String { ls("groups.onboarding.step1.demoGroupName", comment: "") }
            /// "%1$@ agregó %2$@ al grupo %3$@" — positional para reorder por locale.
            static var step1DemoNotifTemplate: String { ls("groups.onboarding.step1.demoNotifTemplate", comment: "") }
            /// "Saldo: %@" — label inicial del balance demo.
            static var step1DemoBalanceLabelInitial: String { ls("groups.onboarding.step1.demoBalanceLabelInitial", comment: "") }
            /// "Debes %@" — label tras transición (monto positivo abs(value)).
            static var step1DemoBalanceLabelDebt: String { ls("groups.onboarding.step1.demoBalanceLabelDebt", comment: "") }
            /// "%1$@ agregó %2$@ al grupo %3$@. Ahora debes %4$@." — 4 placeholders positional.
            static var step1A11yLabelTemplate: String { ls("groups.onboarding.step1.a11yLabelTemplate", comment: "") }

            // Step 2 — Capabilities
            static var step2Title: String { ls("groups.onboarding.step2.title", comment: "") }
            static var step2Subtitle: String { ls("groups.onboarding.step2.subtitle", comment: "") }
            static var step2Card1Title: String { ls("groups.onboarding.step2.card1.title", comment: "") }
            static var step2Card1Body: String { ls("groups.onboarding.step2.card1.body", comment: "") }
            static var step2Card2Title: String { ls("groups.onboarding.step2.card2.title", comment: "") }
            static var step2Card2Body: String { ls("groups.onboarding.step2.card2.body", comment: "") }
            static var step2Card3Title: String { ls("groups.onboarding.step2.card3.title", comment: "") }
            static var step2Card3Body: String { ls("groups.onboarding.step2.card3.body", comment: "") }
            /// F6 awareness Perfil A: bridge crea TX real automáticamente.
            static var step2BridgeAwareness: String { ls("groups.onboarding.step2.bridgeAwareness", comment: "") }

            // Step 3 — Privacy + CTA
            static var step3Title: String { ls("groups.onboarding.step3.title", comment: "") }
            static var step3Subtitle: String { ls("groups.onboarding.step3.subtitle", comment: "") }
            static var step3Point1: String { ls("groups.onboarding.step3.point1", comment: "") }
            static var step3Point2: String { ls("groups.onboarding.step3.point2", comment: "") }
            static var step3CTA: String { ls("groups.onboarding.step3.cta", comment: "") }
            /// F6 awareness: hint que el bridge es configurable en Ajustes de Grupos.
            static var step3BridgeAwareness: String { ls("groups.onboarding.step3.bridgeAwareness", comment: "") }
        }
    }

    // MARK: - AI Consent

    // MARK: - AI Settings (Personalization Sheet from Chat)

    enum AISettings {
        static var title: String { ls("aiSettings.title", comment: "") }
        static var toneSection: String { ls("aiSettings.toneSection", comment: "") }
        static var styleSection: String { ls("aiSettings.styleSection", comment: "") }
        static var appliesHint: String { ls("aiSettings.appliesHint", comment: "") }
    }

    // MARK: - AI Privacy (sub-view from Profile > Security)

    enum AIPrivacy {
        static var title: String { ls("aiPrivacy.title", comment: "") }
        static var processingRow: String { ls("aiPrivacy.processingRow", comment: "") }
        static var chatRow: String { ls("aiPrivacy.chatRow", comment: "") }
        static var insightsRow: String { ls("aiPrivacy.insightsRow", comment: "") }
        static var revokeConfirmTitle: String { ls("aiPrivacy.revokeConfirmTitle", comment: "") }
        static var revokeConfirmMessage: String { ls("aiPrivacy.revokeConfirmMessage", comment: "") }
        static var revokeConfirmAction: String { ls("aiPrivacy.revokeConfirmAction", comment: "") }
        static var footerHint: String { ls("aiPrivacy.footerHint", comment: "") }
        static var policyLink: String { ls("aiPrivacy.policyLink", comment: "") }
    }

    enum AIConsent {
        static var processingTitle: String { ls("aiConsent.processingTitle", comment: "") }
        static var processingMessage: String { ls("aiConsent.processingMessage", comment: "") }
        static var insightsTitle: String { ls("aiConsent.insightsTitle", comment: "") }
        static var insightsMessage: String { ls("aiConsent.insightsMessage", comment: "") }
        static var accept: String { ls("aiConsent.accept", comment: "") }
        static var privacyPolicy: String { ls("aiConsent.privacyPolicy", comment: "") }
        static var inlineHintProcessing: String { ls("aiConsent.inlineHintProcessing", comment: "") }
        static var inlineHintInsights: String { ls("aiConsent.inlineHintInsights", comment: "") }
        static var inlineHintBoth: String { ls("aiConsent.inlineHintBoth", comment: "") }
        static var chatTitle: String { ls("aiConsent.chatTitle", comment: "") }
        static var chatMessage: String { ls("aiConsent.chatMessage", comment: "") }
        static var inlineHintChat: String { ls("aiConsent.inlineHintChat", comment: "") }
        static var inlineHintMultiple: String { ls("aiConsent.inlineHintMultiple", comment: "") }
    }

    // MARK: - Chat Assistant

    enum Chat {
        static var title: String { ls("chat.title", comment: "") }
        static var inputPlaceholder: String { ls("chat.inputPlaceholder", comment: "") }
        static var send: String { ls("chat.send", comment: "") }
        static var emptySubtitle: String { ls("chat.emptySubtitle", comment: "") }
        static var errorTimeout: String { ls("chat.errorTimeout", comment: "") }
        static var errorOffline: String { ls("chat.errorOffline", comment: "") }
        static var errorGeneric: String { ls("chat.errorGeneric", comment: "") }
        static var errorNoData: String { ls("chat.errorNoData", comment: "") }
        static var dailyLimitReached: String { ls("chat.dailyLimitReached", comment: "") }
        static func questionsRemaining(_ count: Int) -> String {
            String(format: ls("chat.questionsRemaining", comment: ""), count)
        }
        static var loading: String { ls("chat.loading", comment: "") }
        static var questionTooLong: String { ls("chat.questionTooLong", comment: "") }
        static var contextHint: String { ls("chat.contextHint", comment: "") }

        // MARK: - Yala IA Redesign (Fases 3 & 5)
        static var assistantName: String { ls("chat.assistantName", comment: "") }
        static var greeting: String { ls("chat.greeting", comment: "") }
        static var dailyResetSubtitle: String { ls("chat.dailyResetSubtitle", comment: "") }
        static var disclaimer: String { ls("chat.disclaimer", comment: "") }
        static var daySeparatorToday: String { ls("chat.daySeparatorToday", comment: "") }
        static var topicsButton: String { ls("chat.topicsButton", comment: "") }
        static var errorTranscription: String { ls("chat.errorTranscription", comment: "") }
        static var errorMicPermission: String { ls("chat.errorMicPermission", comment: "") }
        static var resetContext: String { ls("chat.resetContext", comment: "") }
        static var listening: String { ls("chat.listening", comment: "") }
        static var transcribing: String { ls("chat.transcribing", comment: "") }
        static var preparingAI: String { ls("chat.preparingAI", comment: "") }
        static var noVoiceDetected: String { ls("chat.noVoiceDetected", comment: "") }
        static var unavailable: String { ls("chat.unavailable", comment: "") }
        static var retry: String { ls("chat.retry", comment: "") }
        static func contextMemory(_ count: Int) -> String {
            String(format: ls("chat.contextMemory", comment: ""), count)
        }

        enum Topics {
            static var title: String { ls("chat.topics.title", comment: "") }
        }

        // Chat → Registrar transacciones (incremento Yala IA Registrar)
        enum Draft {
            static var chipExpense: String { ls("chat.draft.chipExpense", comment: "") }
            static var chipIncome: String { ls("chat.draft.chipIncome", comment: "") }
            static var amountPlaceholder: String { ls("chat.draft.amountPlaceholder", comment: "") }
            static var accountLabel: String { ls("chat.draft.accountLabel", comment: "") }
            static var subcategoryLabel: String { ls("chat.draft.subcategoryLabel", comment: "") }
            static var dateLabel: String { ls("chat.draft.dateLabel", comment: "") }
            static var noteLabel: String { ls("chat.draft.noteLabel", comment: "") }
            static var tagsLabel: String { ls("chat.draft.tagsLabel", comment: "") }
            static var tagsNone: String { ls("chat.draft.tagsNone", comment: "") }
            static var savedBadge: String { ls("chat.draft.savedBadge", comment: "") }
            static var discardedBadge: String { ls("chat.draft.discardedBadge", comment: "") }
            static var discardButton: String { ls("chat.draft.discardButton", comment: "") }
            static var saveFailedGeneric: String { ls("chat.draft.saveFailedGeneric", comment: "") }
            static var saveFailedAccount: String { ls("chat.draft.saveFailedAccount", comment: "") }
            static var saveFailedSubcategory: String { ls("chat.draft.saveFailedSubcategory", comment: "") }
            static var saveFailedAmount: String { ls("chat.draft.saveFailedAmount", comment: "") }
            static var viewRecordsButton: String { ls("chat.draft.viewRecordsButton", comment: "") }
            static var selectAccount: String { ls("chat.draft.selectAccount", comment: "") }
            static var selectSubcategory: String { ls("chat.draft.selectSubcategory", comment: "") }
            static var saveButton: String { ls("chat.draft.saveButton", comment: "") }
            static var editButton: String { ls("chat.draft.editButton", comment: "") }
            static var failedSavingLine: String { ls("chat.draft.failedSavingLine", comment: "") }
            static var retryButton: String { ls("chat.draft.retryButton", comment: "") }
            static var noAccountsBlocking: String { ls("chat.draft.noAccountsBlocking", comment: "") }
            static var ambiguousCanned: String { ls("chat.draft.ambiguousCanned", comment: "") }
            static var ambiguousChipRegister: String { ls("chat.draft.ambiguousChipRegister", comment: "") }
            static var ambiguousChipAsk: String { ls("chat.draft.ambiguousChipAsk", comment: "") }
            static var confirmRegisterSingular: String { ls("chat.draft.confirmRegisterSingular", comment: "") }
            static var confirmRegisterPlural: String { ls("chat.draft.confirmRegisterPlural", comment: "") }
            static func overflowFormat(_ detected: Int, _ kept: Int) -> String {
                String(format: ls("chat.draft.overflowFormat", comment: ""), detected, kept)
            }
        }
    }

    // MARK: - Accessibility

    enum Accessibility {
        static var closeMenu: String { ls("accessibility.closeMenu", comment: "") }
        static var newRecord: String { ls("accessibility.newRecord", comment: "") }
        static var filters: String { ls("accessibility.filters", comment: "") }
        static var clearFilters: String { ls("accessibility.clearFilters", comment: "") }
        static var cancelRecording: String { ls("accessibility.cancelRecording", comment: "") }
        static var stopRecording: String { ls("accessibility.stopRecording", comment: "") }
        static var startRecording: String { ls("accessibility.startRecording", comment: "") }
        static var cancelPreview: String { ls("accessibility.cancelPreview", comment: "") }
        static var cancelProcessing: String { ls("accessibility.cancelProcessing", comment: "") }
        static var cashFlowChart: String { ls("accessibility.cashFlowChart", comment: "") }
        static var categoryPieChart: String { ls("accessibility.categoryPieChart", comment: "") }
        static var subcategoryPieChart: String { ls("accessibility.subcategoryPieChart", comment: "") }
        static var tagPieChart: String { ls("accessibility.tagPieChart", comment: "") }
        static var widgetFixed: String { ls("accessibility.widgetFixed", comment: "") }
        static var favoriteTemplates: String { ls("accessibility.favoriteTemplates", comment: "") }
        static var exceeded: String { ls("accessibility.exceeded", comment: "") }
        static var inbox: String { ls("accessibility.inbox", comment: "") }
        static var previousPeriod: String { ls("accessibility.previousPeriod", comment: "") }
        static var nextPeriod: String { ls("accessibility.nextPeriod", comment: "") }
        static var expand: String { ls("accessibility.expand", comment: "") }
        static var collapse: String { ls("accessibility.collapse", comment: "") }
        static var widgetPreferences: String { ls("accessibility.widgetPreferences", comment: "") }
        static var sectionsConfig: String { ls("accessibility.sectionsConfig", comment: "Opens the Panel sections config sheet") }
        static func toggleSection(_ name: String) -> String { String(format: ls("accessibility.toggleSection %@", comment: "Accessibility label for the per-section visibility toggle"), name) }
        static func sectionPrefsButton(_ name: String) -> String { String(format: ls("accessibility.sectionPrefsButton %@", comment: "Accessibility label for the per-section preferences gear button (P20-03)"), name) }
        static var createAccountFirst: String { ls("accessibility.createAccountFirst", comment: "") }
        static var removeFilter: String { ls("accessibility.removeFilter", comment: "") }
        static var viewDetails: String { ls("accessibility.viewDetails", comment: "") }
        static var viewAllRecords: String { ls("accessibility.viewAllRecords", comment: "") }
        static var viewAllCategories: String { ls("accessibility.viewAllCategories", comment: "") }
        static var deleteSubcategory: String { ls("accessibility.deleteSubcategory", comment: "") }
        static var deleteCategory: String { ls("accessibility.deleteCategory", comment: "") }
        static var deleteTag: String { ls("accessibility.deleteTag", comment: "") }
        static var processAudio: String { ls("accessibility.processAudio", comment: "") }
        static var exchangeRateChart: String { ls("accessibility.exchangeRateChart", comment: "") }
        static var periodComparison: String { ls("accessibility.periodComparison", comment: "") }
        static var needTrend: String { ls("accessibility.needTrend", comment: "") }
        static var noData: String { ls("accessibility.noData", comment: "") }
        static var completeFormHint: String { ls("accessibility.completeFormHint", comment: "") }
        static var completeSelectionHint: String { ls("accessibility.completeSelectionHint", comment: "") }
        static func periodComparisonValue(_ count: Int) -> String { String(format: ls("accessibility.periodComparisonValue %d", comment: ""), count) }
        static func trendChart(_ type: String) -> String { String(format: ls("accessibility.trendChart %@", comment: ""), type) }
        static func dataPoints(_ count: Int) -> String { String(format: ls("accessibility.dataPoints %d", comment: ""), count) }
        static func categoriesCount(_ count: Int, _ total: String) -> String { String(format: ls("accessibility.categoriesCount %d %@", comment: ""), count, total) }
        static func subcategoriesCount(_ count: Int, _ total: String) -> String { String(format: ls("accessibility.subcategoriesCount %d %@", comment: ""), count, total) }
        static func tagsCount(_ count: Int, _ total: String) -> String { String(format: ls("accessibility.tagsCount %d %@", comment: ""), count, total) }
        static func periodsCount(_ count: Int) -> String { String(format: ls("accessibility.periodsCount %d", comment: ""), count) }
        static func currenciesCount(_ count: Int) -> String { String(format: ls("accessibility.currenciesCount %d", comment: ""), count) }
        static func cashFlowSummary(income: String, expense: String) -> String { String(format: ls("accessibility.cashFlowSummary %@ %@", comment: ""), income, expense) }
        static var selectAtLeastOneDraft: String { ls("accessibility.selectAtLeastOneDraft", comment: "") }
        static var approveCompleteHint: String { ls("accessibility.approveCompleteHint", comment: "") }
        static var updatingExchangeRates: String { ls("accessibility.updatingExchangeRates", comment: "") }
        static var authenticating: String { ls("accessibility.authenticating", comment: "") }
        static var showMoreSubcategories: String { ls("accessibility.showMoreSubcategories", comment: "") }
        static var subscriptionToggle: String { ls("accessibility.subscriptionToggle", comment: "") }
        static var skipSync: String { ls("accessibility.skipSync", comment: "") }
        static var tabLimitReached: String { ls("accessibility.tabLimitReached", comment: "") }
        static var noTransactionsToExport: String { ls("accessibility.noTransactionsToExport", comment: "") }
        static func accountCard(_ name: String, _ balance: String) -> String { String(format: ls("accessibility.accountCard %@ %@", comment: ""), name, balance) }
        static var editAccount: String { ls("accessibility.editAccount", comment: "") }
        static func pageIndicator(_ current: Int, _ total: Int) -> String { String(format: ls("accessibility.pageIndicator %d %d", comment: ""), current, total) }
        static func accountRow(_ name: String, _ currency: String) -> String { String(format: ls("accessibility.accountRow %@ %@", comment: ""), name, currency) }
        static func budgetRow(_ name: String, _ percent: Int, _ spent: String, _ limit: String) -> String { String(format: ls("accessibility.budgetRow %@ %d %@ %@", comment: ""), name, percent, spent, limit) }
        static func searchResultRow(_ note: String, _ amount: String, _ category: String) -> String { String(format: ls("accessibility.searchResultRow %@ %@ %@", comment: ""), note, amount, category) }
        static var regeneratingInsights: String { ls("accessibility.regeneratingInsights", comment: "") }
        static var completeCalculation: String { ls("accessibility.completeCalculation", comment: "") }
        static var noDraftsToApprove: String { ls("accessibility.noDraftsToApprove", comment: "") }
        static var categoriesLocked: String { ls("accessibility.categoriesLocked", comment: "") }
        static var systemMonochromeIcons: String { ls("accessibility.systemMonochromeIcons", comment: "") }
        static var maxCurrenciesSelected: String { ls("accessibility.maxCurrenciesSelected", comment: "") }
        static var invalidThreshold: String { ls("accessibility.invalidThreshold", comment: "") }
        static var filterScheduledAll: String { ls("accessibility.filterScheduledAll", comment: "") }
        static var filterScheduledRecurring: String { ls("accessibility.filterScheduledRecurring", comment: "") }
        static var filterScheduledSubscriptions: String { ls("accessibility.filterScheduledSubscriptions", comment: "") }
        static func calendarDay(_ day: Int) -> String { String(format: ls("accessibility.calendarDay %d", comment: ""), day) }
        static func recentRecord(_ note: String, _ amount: String, _ time: String) -> String { String(format: ls("accessibility.recentRecord %@ %@ %@", comment: ""), note, amount, time) }
        static var sourceAmount: String { ls("accessibility.sourceAmount", comment: "") }
        static var destinationAmount: String { ls("accessibility.destinationAmount", comment: "") }
        static var exchangeRate: String { ls("accessibility.exchangeRate", comment: "") }
        static func draftRow(_ note: String, _ amount: String, _ status: String) -> String { String(format: ls("accessibility.draftRow %@ %@ %@", comment: ""), note, amount, status) }
        static var metricBalance: String { ls("accessibility.metricBalance", comment: "") }
        static var metricIncome: String { ls("accessibility.metricIncome", comment: "") }
        static var metricExpense: String { ls("accessibility.metricExpense", comment: "") }
        static func colorOption(_ name: String) -> String { String(format: ls("accessibility.colorOption %@", comment: ""), name) }
        static var close: String { ls("accessibility.close", comment: "") }
        static var dismiss: String { ls("accessibility.dismiss", comment: "") }
        static var remove: String { ls("accessibility.remove", comment: "") }
        static var clearSelection: String { ls("accessibility.clearSelection", comment: "") }
        static var selectColor: String { ls("accessibility.selectColor", comment: "") }
        static var newBudget: String { ls("accessibility.newBudget", comment: "") }
        static var newPayment: String { ls("accessibility.newPayment", comment: "") }
        static var importingHint: String { ls("accessibility.importingHint", comment: "") }
        static func variationIncrease(_ value: String) -> String { String(format: ls("accessibility.variationIncrease %@", comment: ""), value) }
        static func variationDecrease(_ value: String) -> String { String(format: ls("accessibility.variationDecrease %@", comment: ""), value) }
        static var processing: String { ls("accessibility.processing", comment: "") }
        static func removeTab(_ name: String) -> String { String(format: ls("accessibility.removeTab %@", comment: ""), name) }
        static var selectAtLeastOneColumn: String { ls("accessibility.selectAtLeastOneColumn", comment: "") }
        static var completeRequiredFilters: String { ls("accessibility.completeRequiredFilters", comment: "") }
        static var exportingHint: String { ls("accessibility.exportingHint", comment: "") }
        static var assignAllCurrencies: String { ls("accessibility.assignAllCurrencies", comment: "") }
        static var fillRequiredFields: String { ls("accessibility.fillRequiredFields", comment: "") }
        static var noTransactions: String { ls("accessibility.noTransactions", comment: "") }
        static var selectDraftsFirst: String { ls("accessibility.selectDraftsFirst", comment: "") }
        static var proFeature: String { ls("accessibility.proFeature", comment: "") }
        static var noActiveAccounts: String { ls("accessibility.noActiveAccounts", comment: "") }
        static var noInactiveBudgets: String { ls("accessibility.noInactiveBudgets", comment: "") }
        static var profile: String { ls("accessibility.profile", comment: "") }
    }

    // MARK: - Search

    enum Search {
        static var noResults: String { ls("search.noResults", comment: "") }
        static var tryAnotherTerm: String { ls("search.tryAnotherTerm", comment: "") }
        static func resultsCount(_ count: Int) -> String { String(format: ls("search.resultsCount", comment: ""), count) }

        enum Filter {
            static var all: String { ls("search.filter.all", comment: "") }
            static var note: String { ls("search.filter.note", comment: "") }
            static var category: String { ls("search.filter.category", comment: "") }
            static var subcategory: String { ls("search.filter.subcategory", comment: "") }
            static var account: String { ls("search.filter.account", comment: "") }
            static var need: String { ls("search.filter.need", comment: "") }
            static var tag: String { ls("search.filter.tag", comment: "") }
        }
    }

    // MARK: - Date Helpers

    enum Date {
        static var today: String { ls("date.today", comment: "") }
        static var yesterday: String { ls("date.yesterday", comment: "") }

        static func weekOf(_ date: String) -> String {
            String(format: ls("date.weekOf %@", comment: ""), date)
        }
    }

    // MARK: - Exchange Rate

    enum ExchangeRate {
        static var title: String { ls("exchangeRate.title", comment: "") }
        static var updated: String { ls("exchangeRate.updated", comment: "") }
        static var loadError: String { ls("exchangeRate.loadError", comment: "") }
        static var noSecondaryCurrenciesHint: String {
            ls("exchangeRate.noSecondaryCurrenciesHint", comment: "")
        }
        static var noSecondaryCurrenciesPath: String {
            ls("exchangeRate.noSecondaryCurrenciesPath", comment: "")
        }
    }

    // MARK: - Currency Names

    enum Currency {
        // Latinoamérica
        static var pen: String { ls("currency.pen", comment: "") }
        static var usd: String { ls("currency.usd", comment: "") }
        static var mxn: String { ls("currency.mxn", comment: "") }
        static var cop: String { ls("currency.cop", comment: "") }
        static var brl: String { ls("currency.brl", comment: "") }
        static var ars: String { ls("currency.ars", comment: "") }
        static var clp: String { ls("currency.clp", comment: "") }
        static var uyu: String { ls("currency.uyu", comment: "") }
        static var bob: String { ls("currency.bob", comment: "") }
        static var pyg: String { ls("currency.pyg", comment: "") }
        static var crc: String { ls("currency.crc", comment: "") }
        static var gtq: String { ls("currency.gtq", comment: "") }
        static var hnl: String { ls("currency.hnl", comment: "") }
        static var nio: String { ls("currency.nio", comment: "") }
        static var pab: String { ls("currency.pab", comment: "") }
        static var dop: String { ls("currency.dop", comment: "") }
        // Europa
        static var eur: String { ls("currency.eur", comment: "") }
        static var gbp: String { ls("currency.gbp", comment: "") }
        static var chf: String { ls("currency.chf", comment: "") }
        static var sek: String { ls("currency.sek", comment: "") }
        static var nok: String { ls("currency.nok", comment: "") }
        static var dkk: String { ls("currency.dkk", comment: "") }
        static var pln: String { ls("currency.pln", comment: "") }
        static var czk: String { ls("currency.czk", comment: "") }
        static var huf: String { ls("currency.huf", comment: "") }
        static var ron: String { ls("currency.ron", comment: "") }
        static var rub: String { ls("currency.rub", comment: "") }
        static var uah: String { ls("currency.uah", comment: "") }
        static var `try`: String { ls("currency.try", comment: "") }
        // Asia
        static var jpy: String { ls("currency.jpy", comment: "") }
        static var cny: String { ls("currency.cny", comment: "") }
        static var krw: String { ls("currency.krw", comment: "") }
        static var inr: String { ls("currency.inr", comment: "") }
        static var idr: String { ls("currency.idr", comment: "") }
        static var php: String { ls("currency.php", comment: "") }
        static var thb: String { ls("currency.thb", comment: "") }
        static var myr: String { ls("currency.myr", comment: "") }
        static var sgd: String { ls("currency.sgd", comment: "") }
        static var hkd: String { ls("currency.hkd", comment: "") }
        static var twd: String { ls("currency.twd", comment: "") }
        static var vnd: String { ls("currency.vnd", comment: "") }
        // Oceanía
        static var aud: String { ls("currency.aud", comment: "") }
        static var nzd: String { ls("currency.nzd", comment: "") }
        // Medio Oriente
        static var aed: String { ls("currency.aed", comment: "") }
        static var sar: String { ls("currency.sar", comment: "") }
        static var ils: String { ls("currency.ils", comment: "") }
        static var qar: String { ls("currency.qar", comment: "") }
        static var kwd: String { ls("currency.kwd", comment: "") }
        // África
        static var zar: String { ls("currency.zar", comment: "") }
        static var egp: String { ls("currency.egp", comment: "") }
        static var ngn: String { ls("currency.ngn", comment: "") }
        static var kes: String { ls("currency.kes", comment: "") }
        static var mad: String { ls("currency.mad", comment: "") }
        // Norteamérica
        static var cad: String { ls("currency.cad", comment: "") }

        /// Nombres cortos en plural (sin país) para ejemplos de voz
        enum Plural {
            // Latinoamérica
            static var pen: String { ls("currency.plural.pen", comment: "") }
            static var usd: String { ls("currency.plural.usd", comment: "") }
            static var mxn: String { ls("currency.plural.mxn", comment: "") }
            static var cop: String { ls("currency.plural.cop", comment: "") }
            static var brl: String { ls("currency.plural.brl", comment: "") }
            static var ars: String { ls("currency.plural.ars", comment: "") }
            static var clp: String { ls("currency.plural.clp", comment: "") }
            static var uyu: String { ls("currency.plural.uyu", comment: "") }
            static var bob: String { ls("currency.plural.bob", comment: "") }
            static var pyg: String { ls("currency.plural.pyg", comment: "") }
            static var crc: String { ls("currency.plural.crc", comment: "") }
            static var gtq: String { ls("currency.plural.gtq", comment: "") }
            static var hnl: String { ls("currency.plural.hnl", comment: "") }
            static var nio: String { ls("currency.plural.nio", comment: "") }
            static var pab: String { ls("currency.plural.pab", comment: "") }
            static var dop: String { ls("currency.plural.dop", comment: "") }
            // Europa
            static var eur: String { ls("currency.plural.eur", comment: "") }
            static var gbp: String { ls("currency.plural.gbp", comment: "") }
            static var chf: String { ls("currency.plural.chf", comment: "") }
            static var sek: String { ls("currency.plural.sek", comment: "") }
            static var nok: String { ls("currency.plural.nok", comment: "") }
            static var dkk: String { ls("currency.plural.dkk", comment: "") }
            static var pln: String { ls("currency.plural.pln", comment: "") }
            static var czk: String { ls("currency.plural.czk", comment: "") }
            static var huf: String { ls("currency.plural.huf", comment: "") }
            static var ron: String { ls("currency.plural.ron", comment: "") }
            static var rub: String { ls("currency.plural.rub", comment: "") }
            static var uah: String { ls("currency.plural.uah", comment: "") }
            static var `try`: String { ls("currency.plural.try", comment: "") }
            // Asia
            static var jpy: String { ls("currency.plural.jpy", comment: "") }
            static var cny: String { ls("currency.plural.cny", comment: "") }
            static var krw: String { ls("currency.plural.krw", comment: "") }
            static var inr: String { ls("currency.plural.inr", comment: "") }
            static var idr: String { ls("currency.plural.idr", comment: "") }
            static var php: String { ls("currency.plural.php", comment: "") }
            static var thb: String { ls("currency.plural.thb", comment: "") }
            static var myr: String { ls("currency.plural.myr", comment: "") }
            static var sgd: String { ls("currency.plural.sgd", comment: "") }
            static var hkd: String { ls("currency.plural.hkd", comment: "") }
            static var twd: String { ls("currency.plural.twd", comment: "") }
            static var vnd: String { ls("currency.plural.vnd", comment: "") }
            // Oceanía
            static var aud: String { ls("currency.plural.aud", comment: "") }
            static var nzd: String { ls("currency.plural.nzd", comment: "") }
            // Medio Oriente
            static var aed: String { ls("currency.plural.aed", comment: "") }
            static var sar: String { ls("currency.plural.sar", comment: "") }
            static var ils: String { ls("currency.plural.ils", comment: "") }
            static var qar: String { ls("currency.plural.qar", comment: "") }
            static var kwd: String { ls("currency.plural.kwd", comment: "") }
            // África
            static var zar: String { ls("currency.plural.zar", comment: "") }
            static var egp: String { ls("currency.plural.egp", comment: "") }
            static var ngn: String { ls("currency.plural.ngn", comment: "") }
            static var kes: String { ls("currency.plural.kes", comment: "") }
            static var mad: String { ls("currency.plural.mad", comment: "") }
            // Norteamérica
            static var cad: String { ls("currency.plural.cad", comment: "") }
        }
    }

    // MARK: - Continents

    enum Continent {
        static var latinAmerica: String { ls("continent.latinAmerica", comment: "") }
        static var europe: String { ls("continent.europe", comment: "") }
        static var asia: String { ls("continent.asia", comment: "") }
        static var oceania: String { ls("continent.oceania", comment: "") }
        static var middleEast: String { ls("continent.middleEast", comment: "") }
        static var africa: String { ls("continent.africa", comment: "") }
        static var northAmerica: String { ls("continent.northAmerica", comment: "") }
    }

    // MARK: - Empty States

    enum Empty {
        static var noData: String { ls("empty.noData", comment: "") }
        static var noTransactions: String { ls("empty.noTransactions", comment: "") }
        static var noFavorites: String { ls("empty.noFavorites", comment: "") }
        static var noTags: String { ls("empty.noTags", comment: "") }
        static var noAccounts: String { ls("empty.noAccounts", comment: "") }
        static var noCategories: String { ls("empty.noCategories", comment: "") }
        static var categoriesDescription: String {
            ls("empty.categoriesDescription", comment: "")
        }
        static var noSubcategories: String {
            ls("empty.noSubcategories", comment: "")
        }
        static var noExpenses: String { ls("empty.noExpenses", comment: "") }
        static var tagsDescription: String {
            ls("empty.tagsDescription", comment: "")
        }
        static var accountsDescription: String {
            ls("empty.accountsDescription", comment: "")
        }
        static var activateCategoriesTitle: String {
            ls("empty.activateCategoriesTitle", comment: "")
        }
        static var activateCategoriesMessage: String {
            ls("empty.activateCategoriesMessage", comment: "")
        }
        static var activateCategoriesAction: String {
            ls("empty.activateCategoriesAction", comment: "")
        }
    }

    // MARK: - Transaction

    enum Transaction {
        static var new: String { ls("transaction.new", comment: "") }
        static var edit: String { ls("transaction.edit", comment: "") }
        static var newTransaction: String {
            ls("transaction.newTransaction", comment: "")
        }
        static var editTransaction: String {
            ls("transaction.editTransaction", comment: "")
        }
        static var type: String { ls("transaction.type", comment: "") }
        static var amount: String { ls("transaction.amount", comment: "") }
        static var description: String { ls("transaction.description", comment: "") }
        static var descriptionHint: String {
            ls("transaction.descriptionHint", comment: "")
        }
        static var note: String { ls("transaction.note", comment: "") }
        static var notePlaceholder: String {
            ls("transaction.notePlaceholder", comment: "")
        }
        static var date: String { ls("transaction.date", comment: "") }
        static var tags: String { ls("transaction.tags", comment: "") }
        static var addTags: String { ls("transaction.addTags", comment: "") }
        static var category: String { ls("transaction.category", comment: "") }
        static var subcategory: String { ls("transaction.subcategory", comment: "") }
        static var select: String { ls("transaction.select", comment: "") }
        static var total: String { ls("transaction.total", comment: "") }
        static var income: String { ls("transaction.income", comment: "") }
        static var expense: String { ls("transaction.expense", comment: "") }
        static var transfer: String { ls("transaction.transfer", comment: "") }
        static var origin: String { ls("transaction.origin", comment: "") }
        static var destination: String { ls("transaction.destination", comment: "") }
        static var sourceAccount: String {
            ls("transaction.sourceAccount", comment: "")
        }
        static var destinationAccount: String {
            ls("transaction.destinationAccount", comment: "")
        }
        static var account: String { ls("transaction.account", comment: "") }
        /// Caption abreviado del tipo de cambio bajo el monto convertido ("TC: 3.7500")
        static func exchangeRateShort(_ rate: String) -> String {
            String(format: ls("transaction.exchangeRateShort %@", comment: ""), rate)
        }
        static var exchangeRate: String {
            ls("transaction.exchangeRate", comment: "")
        }
        static var willReceive: String { ls("transaction.willReceive", comment: "") }
        static var createAnother: String {
            ls("transaction.createAnother", comment: "")
        }
        static var recents: String { ls("transaction.recents", comment: "") }
        static var successTitle: String {
            ls("transaction.successTitle", comment: "")
        }

        enum TransactionType {
            static var expense: String {
                ls("transaction.type.expense", comment: "")
            }
            static var income: String {
                ls("transaction.type.income", comment: "")
            }
            static var transfer: String {
                ls("transaction.type.transfer", comment: "")
            }
        }
    }

    // MARK: - Account

    enum Account {
        static var new: String { ls("account.new", comment: "") }
        static var edit: String { ls("account.edit", comment: "") }
        static var configure: String { ls("account.configure", comment: "") }
        static var name: String { ls("account.name", comment: "") }
        static var accountName: String { ls("account.accountName", comment: "") }
        static var accountNumber: String { ls("account.accountNumber", comment: "") }
        static var type: String { ls("account.type", comment: "") }
        static var currency: String { ls("account.currency", comment: "") }
        static var balance: String { ls("account.balance", comment: "") }
        static var initialBalance: String {
            ls("account.initialBalance", comment: "")
        }
        static var sign: String { ls("account.sign", comment: "") }
        static var positive: String { ls("account.positive", comment: "") }
        static var negative: String { ls("account.negative", comment: "") }
        static var adjustment: String { ls("account.adjustment", comment: "") }

        enum Sign {
            static var inFavor: String { ls("account.sign.inFavor", comment: "") }
            static var consumed: String { ls("account.sign.consumed", comment: "") }
        }

        // MARK: - System Account (A0-Bridge)

        enum System {
            /// "Grupos %@" — nombre de cuenta virtual sistema con currency code (ej: "Grupos PEN").
            /// Format string para String(format:_:).
            static var groups: String { ls("account.system.groups", comment: "") }
            /// "Sistema" — badge/etiqueta para distinguir cuentas sistema.
            static var badge: String { ls("account.system.badge", comment: "") }
        }
        static var selected: String { ls("account.selected", comment: "") }
        static var selectAccount: String { ls("account.selectAccount", comment: "") }
        static var archived: String { ls("account.archived", comment: "") }
        static var archive: String { ls("account.archive", comment: "") }
        static var unarchive: String { ls("account.unarchive", comment: "") }
        static var excludeFromStats: String {
            ls("account.excludeFromStats", comment: "")
        }
        static var delete: String { ls("account.delete", comment: "") }
        static var deleteError: String { ls("account.deleteError", comment: "") }
        static var deleteBalanceError: String {
            ls("account.deleteBalanceError", comment: "")
        }
        static var addAccount: String { ls("account.addAccount", comment: "") }

        enum AccountType {
            static var general: String { ls("account.type.general", comment: "") }
            static var cash: String { ls("account.type.cash", comment: "") }
            static var current: String { ls("account.type.current", comment: "") }
            static var savings: String { ls("account.type.savings", comment: "") }
            static var creditCard: String {
                ls("account.type.creditCard", comment: "")
            }
            static var investment: String {
                ls("account.type.investment", comment: "")
            }
            static var loan: String { ls("account.type.loan", comment: "") }
            static var other: String { ls("account.type.other", comment: "") }
        }

        // Balance Adjustments
        static var newBalance: String { ls("account.newBalance", comment: "") }
        static var currentBalance: String {
            ls("account.currentBalance", comment: "")
        }
        static func adjustmentPreview(_ amount: String) -> String {
            String(format: ls("account.adjustmentPreview", comment: ""), amount)
        }
        static var initialBalanceNote: String {
            ls("account.initialBalanceNote", comment: "")
        }
        static var adjustmentNote: String {
            ls("account.adjustmentNote", comment: "")
        }
        static func existingInitialBalance(_ amount: String) -> String {
            String(format: ls("account.existingInitialBalance", comment: ""), amount)
        }
        static var modifyInitialBalance: String {
            ls("account.modifyInitialBalance", comment: "")
        }
        static var adjustmentDate: String {
            ls("account.adjustmentDate", comment: "")
        }
        static var finalBalance: String {
            ls("account.finalBalance", comment: "")
        }
        static var adjustByEntry: String {
            ls("account.adjustByEntry", comment: "")
        }
        static var adjustByEntryDesc: String {
            ls("account.adjustByEntryDesc", comment: "")
        }
        static var changeInitialBalanceName: String {
            ls("account.changeInitialBalanceName", comment: "")
        }
        static var changeInitialBalanceDesc: String {
            ls("account.changeInitialBalanceDesc", comment: "")
        }

        // MARK: - Secondary Currency Suggestion
        static var secondaryCurrencyTitle: String {
            ls("account.secondaryCurrency.title", comment: "")
        }
        static func secondaryCurrencyMessage(_ currency: String, _ preferred: String, _ target: String) -> String {
            String(format: ls("account.secondaryCurrency.message", comment: ""), currency, preferred, target)
        }
        static var secondaryCurrencyAccept: String {
            ls("account.secondaryCurrency.accept", comment: "")
        }
        static var secondaryCurrencyReject: String {
            ls("account.secondaryCurrency.reject", comment: "")
        }

        // MARK: - Credit Card
        enum CreditCard {
            static var sectionTitle: String { ls("account.creditCard.sectionTitle", comment: "") }
            static var paymentReminder: String { ls("account.creditCard.paymentReminder", comment: "") }
            static var paymentDay: String { ls("account.creditCard.paymentDay", comment: "") }
            static func paymentNotification(_ accountName: String) -> String {
                String(format: ls("account.creditCard.paymentNotification", comment: ""), accountName)
            }
        }

    }

    // MARK: - Category

    enum Category {
        static var new: String { ls("category.new", comment: "") }
        static var edit: String { ls("category.edit", comment: "") }
        static var editTitle: String { ls("category.editTitle", comment: "") }
        static var name: String { ls("category.name", comment: "") }
        static var need: String { ls("category.need", comment: "") }
        static var show: String { ls("category.show", comment: "") }
        static var hiddenTitle: String { ls("category.hiddenTitle", comment: "") }
        static var hiddenDescription: String {
            ls("category.hiddenDescription", comment: "")
        }
        static var addSubcategory: String {
            ls("category.addSubcategory", comment: "")
        }
        static var subcategories: String {
            ls("category.subcategories", comment: "")
        }
        static var noSubcategoriesYet: String {
            ls("category.noSubcategoriesYet", comment: "")
        }
        static var requiresSubcategory: String {
            ls("category.requiresSubcategory", comment: "")
        }
        static var addOneSubcategory: String {
            ls("category.addOneSubcategory", comment: "")
        }
        static var delete: String { ls("category.delete", comment: "") }
        static var deleteConfirmTitle: String {
            ls("category.deleteConfirmTitle", comment: "")
        }
        static var deleteConfirmMessage: String {
            ls("category.deleteConfirmMessage", comment: "")
        }
        static var cannotDeleteTitle: String {
            ls("category.cannotDeleteTitle", comment: "")
        }
        static func cannotDeleteMessage(_ count: Int) -> String {
            String(
                format: ls("category.cannotDeleteMessage", comment: ""),
                count
            )
        }
        static var newCategory: String {
            ls("category.newCategory", comment: "")
        }
        static var namePlaceholder: String {
            ls("category.namePlaceholder", comment: "")
        }
        static var activeSubcategories: String {
            ls("category.activeSubcategories", comment: "")
        }
        static var hiddenSubcategories: String {
            ls("category.hiddenSubcategories", comment: "")
        }
        static var details: String {
            ls("category.details", comment: "")
        }
        static var others: String {
            ls("category.others", comment: "")
        }
        // Seed names
        static var food: String { ls("category.food", comment: "") }
        static var shopping: String { ls("category.shopping", comment: "") }
        static var transport: String { ls("category.transport", comment: "") }
        static var finance: String { ls("category.finance", comment: "") }
        static var housing: String { ls("category.housing", comment: "") }
        static var entertainment: String { ls("category.entertainment", comment: "") }
        static var personal: String { ls("category.personal", comment: "") }
        static var pets: String { ls("category.pets", comment: "") }
        static var vehicle: String { ls("category.vehicle", comment: "") }
        static var incomeCategory: String { ls("category.income", comment: "") }
        static var other: String { ls("category.other", comment: "") }

        // MARK: - System Categories (A0-Bridge)

        enum System {
            /// "Grupos" — categoría sistema expense para subcategorías sistema del bridge.
            static var groups: String { ls("category.system.groups", comment: "") }
            /// "Cobros de grupos" — categoría sistema income para subcategorías sistema del bridge.
            static var groupCollections: String { ls("category.system.groupCollections", comment: "") }
        }
    }

    // MARK: - Subcategory

    enum Subcategory {
        static var newTitle: String { ls("subcategory.newTitle", comment: "") }
        static var editTitle: String { ls("subcategory.editTitle", comment: "") }
        static var delete: String { ls("subcategory.delete", comment: "") }
        static var deleteConfirmTitle: String {
            ls("subcategory.deleteConfirmTitle", comment: "")
        }
        static var deleteConfirmMessage: String {
            ls("subcategory.deleteConfirmMessage", comment: "")
        }
        static var cannotDeleteTitle: String {
            ls("subcategory.cannotDeleteTitle", comment: "")
        }
        static func cannotDeleteMessage(_ count: Int) -> String {
            String(
                format: ls("subcategory.cannotDeleteMessage", comment: ""),
                count
            )
        }

        // Transfer sheet
        static var transferTitle: String {
            ls("subcategory.transferTitle", comment: "")
        }
        static var transferHeader: String {
            ls("subcategory.transferHeader", comment: "")
        }
        static func transferDescription(_ count: Int, _ name: String) -> String {
            String(
                format: ls("subcategory.transferDescription", comment: ""),
                count,
                name
            )
        }
        static var transferToSpecific: String {
            ls("subcategory.transferToSpecific", comment: "")
        }
        static var transferToSpecificDesc: String {
            ls("subcategory.transferToSpecificDesc", comment: "")
        }
        static var transferToUnassigned: String {
            ls("subcategory.transferToUnassigned", comment: "")
        }
        static var transferToUnassignedDesc: String {
            ls("subcategory.transferToUnassignedDesc", comment: "")
        }
        static var deleteTransactions: String {
            ls("subcategory.deleteTransactions", comment: "")
        }
        static var deleteTransactionsDesc: String {
            ls("subcategory.deleteTransactionsDesc", comment: "")
        }
        static var selectDestination: String {
            ls("subcategory.selectDestination", comment: "")
        }
        static var deleteTransactionsConfirmTitle: String {
            ls("subcategory.deleteTransactionsConfirmTitle", comment: "")
        }
        static var deleteTransactionsConfirm: String {
            ls("subcategory.deleteTransactionsConfirm", comment: "")
        }
        static func deleteTransactionsConfirmMessage(_ count: Int) -> String {
            String(
                format: ls("subcategory.deleteTransactionsConfirmMessage", comment: ""),
                count
            )
        }
        static var details: String {
            ls("subcategory.details", comment: "")
        }
        static var namePlaceholder: String {
            ls("subcategory.namePlaceholder", comment: "")
        }
        static var unassigned: String {
            ls("subcategory.unassigned", comment: "")
        }
        static var noSubcategory: String {
            ls("subcategories.noSubcategory", comment: "")
        }
        // Seed names - Alimentación
        static var delivery: String { ls("subcategory.delivery", comment: "") }
        static var restaurants: String { ls("subcategory.restaurants", comment: "") }
        static var supplements: String { ls("subcategory.supplements", comment: "") }
        static var supermarkets: String { ls("subcategory.supermarkets", comment: "") }
        // Seed names - Compras
        static var personalCare: String { ls("subcategory.personalCare", comment: "") }
        static var pharmacy: String { ls("subcategory.pharmacy", comment: "") }
        static var homeDecor: String { ls("subcategory.homeDecor", comment: "") }
        static var otherShopping: String { ls("subcategory.otherShopping", comment: "") }
        static var gifts: String { ls("subcategory.gifts", comment: "") }
        static var clothing: String { ls("subcategory.clothing", comment: "") }
        static var tech: String { ls("subcategory.tech", comment: "") }
        // Seed names - Transporte
        static var occasionalMobility: String { ls("subcategory.occasionalMobility", comment: "") }
        static var rideshare: String { ls("subcategory.rideshare", comment: "") }
        static var publicTransport: String { ls("subcategory.publicTransport", comment: "") }
        // Seed names - Finanzas
        static var fees: String { ls("subcategory.fees", comment: "") }
        static var taxes: String { ls("subcategory.taxes", comment: "") }
        static var pensions: String { ls("subcategory.pensions", comment: "") }
        static var loans: String { ls("subcategory.loans", comment: "") }
        static var insurance: String { ls("subcategory.insurance", comment: "") }
        // Seed names - Hogar
        static var rent: String { ls("subcategory.rent", comment: "") }
        static var maintenance: String { ls("subcategory.maintenance", comment: "") }
        static var otherHousing: String { ls("subcategory.otherHousing", comment: "") }
        static var supportStaff: String { ls("subcategory.supportStaff", comment: "") }
        static var homeInsurance: String { ls("subcategory.homeInsurance", comment: "") }
        static var utilities: String { ls("subcategory.utilities", comment: "") }
        // Seed names - Entretenimiento
        static var bars: String { ls("subcategory.bars", comment: "") }
        static var sports: String { ls("subcategory.sports", comment: "") }
        static var shows: String { ls("subcategory.shows", comment: "") }
        static var nightlife: String { ls("subcategory.nightlife", comment: "") }
        static var hobbies: String { ls("subcategory.hobbies", comment: "") }
        static var coupleDates: String { ls("subcategory.coupleDates", comment: "") }
        static var streaming: String { ls("subcategory.streaming", comment: "") }
        static var travel: String { ls("subcategory.travel", comment: "") }
        // Seed names - Personal
        static var consulting: String { ls("subcategory.consulting", comment: "") }
        static var beauty: String { ls("subcategory.beauty", comment: "") }
        static var education: String { ls("subcategory.education", comment: "") }
        static var fitness: String { ls("subcategory.fitness", comment: "") }
        static var health: String { ls("subcategory.health", comment: "") }
        static var leisureSubs: String { ls("subcategory.leisureSubs", comment: "") }
        static var utilitySubs: String { ls("subcategory.utilitySubs", comment: "") }
        static var phone: String { ls("subcategory.phone", comment: "") }
        // Seed names - Mascotas
        static var petAccessories: String { ls("subcategory.petAccessories", comment: "") }
        static var petFood: String { ls("subcategory.petFood", comment: "") }
        static var vet: String { ls("subcategory.vet", comment: "") }
        static var petServices: String { ls("subcategory.petServices", comment: "") }
        // Seed names - Vehículo
        static var fuel: String { ls("subcategory.fuel", comment: "") }
        static var parking: String { ls("subcategory.parking", comment: "") }
        static var leasing: String { ls("subcategory.leasing", comment: "") }
        static var vehicleMaintenance: String { ls("subcategory.vehicleMaintenance", comment: "") }
        static var vehicleLoan: String { ls("subcategory.vehicleLoan", comment: "") }
        static var vehicleInsurance: String { ls("subcategory.vehicleInsurance", comment: "") }
        // Seed names - Ingresos
        static var rentalIncome: String { ls("subcategory.rentalIncome", comment: "") }
        static var subsidies: String { ls("subcategory.subsidies", comment: "") }
        static var freelance: String { ls("subcategory.freelance", comment: "") }
        static var dividends: String { ls("subcategory.dividends", comment: "") }
        static var refunds: String { ls("subcategory.refunds", comment: "") }
        static var giftIncome: String { ls("subcategory.giftIncome", comment: "") }
        static var salary: String { ls("subcategory.salary", comment: "") }
        static var sales: String { ls("subcategory.sales", comment: "") }
        static var accountTransfer: String { ls("subcategory.accountTransfer", comment: "") }
        // Seed names - Otros
        static var balanceAdjustment: String { ls("subcategory.balanceAdjustment", comment: "") }
        static var accountTransferOther: String { ls("subcategory.accountTransferOther", comment: "") }

        // MARK: - System Subcategories (A0-Bridge)

        enum System {
            /// "Préstamo a grupos" — Caso A TX2 (income, virtual): pagué un gasto del grupo, me deben el total.
            static var loanToGroups: String { ls("subcategory.system.loanToGroups", comment: "") }
            /// "Cobro de préstamo" — Caso D TX1 (expense, virtual): mi crédito virtual se redujo (alguien me liquidó).
            static var loanCollection: String { ls("subcategory.system.loanCollection", comment: "") }
            /// "Pago de liquidación" — Caso C TX1 (income, virtual): pagué a otro, mi deuda virtual se canceló.
            static var settlementPayment: String { ls("subcategory.system.settlementPayment", comment: "") }
            /// "Liquidación enviada" — Caso C TX2 (expense, cuenta real): salida a cuenta real para liquidar.
            static var settlementSent: String { ls("subcategory.system.settlementSent", comment: "") }
            /// "Liquidación recibida" — Caso D TX2 (income, cuenta real): entrada a cuenta real desde otro miembro.
            static var settlementReceived: String { ls("subcategory.system.settlementReceived", comment: "") }
            /// "Saldo inicial (me deben)" — saldo de apertura donde soy acreedor (income, virtual).
            static var openingBalanceOwed: String { ls("subcategory.system.openingBalanceOwed", comment: "") }
            /// "Saldo inicial (debo)" — saldo de apertura donde soy deudor (expense, virtual).
            static var openingBalanceDebt: String { ls("subcategory.system.openingBalanceDebt", comment: "") }
        }
    }

    // MARK: - Tag

    enum Tag {
        static var new: String { ls("tag.new", comment: "") }
        static var edit: String { ls("tag.edit", comment: "") }
        static var newTag: String { ls("tag.newTag", comment: "") }
        static var editTag: String { ls("tag.editTag", comment: "") }
        static var createFirstDescription: String {
            ls("tag.createFirstDescription", comment: "")
        }
        static var delete: String { ls("tag.delete", comment: "") }
        static var deleteConfirmation: String {
            ls("tag.deleteConfirmation", comment: "")
        }
        static var namePlaceholder: String {
            ls("tag.namePlaceholder", comment: "")
        }
        static var color: String {
            ls("tag.color", comment: "")
        }
        static func colorSelected(_ hex: String) -> String {
            String(format: ls("tag.colorSelected", comment: ""), hex)
        }
    }

    // MARK: - Alert

    enum Alert {
        static var unsavedChanges: String { ls("alert.unsavedChanges", comment: "") }
        static var discardChanges: String { ls("alert.discardChanges", comment: "") }
        static var keepEditing: String { ls("alert.keepEditing", comment: "") }
        static var confirmDelete: String { ls("alert.confirmDelete", comment: "") }
        static var deleteWarning: String { ls("alert.deleteWarning", comment: "") }
    }

    // MARK: - Import

    enum Import {
        static var title: String { ls("import.title", comment: "") }
        static var selectFile: String { ls("import.selectFile", comment: "") }
        static var importing: String { ls("import.importing", comment: "") }
        static var downloadTemplate: String {
            ls("import.downloadTemplate", comment: "")
        }
        static var createCategories: String {
            ls("import.createCategories", comment: "")
        }
        static var continueBtn: String { ls("import.continue", comment: "") }
        static var noAccountsAvailable: String {
            ls("import.noAccountsAvailable", comment: "")
        }
        static var createAccountFirst: String {
            ls("import.createAccountFirst", comment: "")
        }
        static var completed: String {
            ls("import.completed", comment: "")
        }
        static var importError: String {
            ls("import.error", comment: "")
        }
        static var templateGenerated: String {
            ls("import.templateGenerated", comment: "")
        }
        static var templateGeneratedMessage: String {
            ls("import.templateGeneratedMessage", comment: "")
        }
        static var introDescription: String {
            ls("import.introDescription", comment: "")
        }
        static var templateDescription: String {
            ls("import.templateDescription", comment: "")
        }
        static var categoriesDescription: String {
            ls("import.categoriesDescription", comment: "")
        }
        static var selectAccount: String {
            ls("import.selectAccount", comment: "")
        }
        static var fileUrlError: String {
            ls("import.fileUrlError", comment: "")
        }
        static var createAccountBeforeImport: String {
            ls("import.createAccountBeforeImport", comment: "")
        }

        // Multi-currency import
        static var multiCurrencyDetected: String {
            ls("import.multiCurrencyDetected", comment: "")
        }
        static var assignAccountPerCurrency: String {
            ls("import.assignAccountPerCurrency", comment: "")
        }
        static var selectAccountForCurrency: String {
            ls("import.selectAccountForCurrency", comment: "")
        }
        static func currenciesDetected(_ count: Int) -> String {
            String(format: ls("import.currenciesDetected", comment: ""), count)
        }
        static func recordsImported(_ count: Int) -> String {
            String(format: ls("import.recordsImported", comment: ""), count)
        }
        static func recordsImportedMultiCurrency(_ count: Int, _ currencies: Int) -> String {
            String(format: ls("import.recordsImportedMultiCurrency", comment: ""), count, currencies)
        }
        static func noAccountsForCurrency(_ currency: String) -> String {
            String(format: ls("import.noAccountsForCurrency", comment: ""), currency)
        }
        static var noCurrenciesDetected: String {
            ls("import.noCurrenciesDetected", comment: "")
        }
        static var importAction: String {
            ls("import.importAction", comment: "")
        }
    }

    // MARK: - Export

    enum Export {
        static var title: String { ls("export.title", comment: "") }
        static var filters: String { ls("export.filters", comment: "") }
        static var columns: String { ls("export.columns", comment: "") }
        static var summary: String { ls("export.summary", comment: "") }
        static var format: String { ls("export.format", comment: "") }
        static var period: String { ls("export.period", comment: "") }
        static var selectAll: String { ls("export.selectAll", comment: "") }
        static var deselectAll: String { ls("export.deselectAll", comment: "") }
        static var customizeFile: String { ls("export.customizeFile", comment: "") }
        static var csvGeneratedSuccess: String {
            ls("export.csvGeneratedSuccess", comment: "")
        }
        /// F1 review G5-D2: el usuario pidió incluir grupos y el CSV de grupos falló — cero silencios.
        static var groupsExportFailedNote: String {
            ls("export.groupsExportFailedNote", comment: "")
        }
        static var confirmExport: String { ls("export.confirmExport", comment: "") }
        static var selectColumns: String {
            ls("export.selectColumns", comment: "")
        }
        static var availableColumns: String {
            ls("export.availableColumns", comment: "")
        }
        static var columnsDescription: String {
            ls("export.columnsDescription", comment: "")
        }
        static var summaryAndExport: String {
            ls("export.summaryAndExport", comment: "")
        }
        static var summaryDescription: String {
            ls("export.summaryDescription", comment: "")
        }
        static var filtersSummary: String {
            ls("export.filtersSummary", comment: "")
        }
        static var columnsToExport: String {
            ls("export.columnsToExport", comment: "")
        }
        static var exportToCSV: String {
            ls("export.exportToCSV", comment: "")
        }
        static var exportBtn: String {
            ls("export.exportBtn", comment: "")
        }
        static var exportError: String {
            ls("export.exportError", comment: "")
        }
        static var exportCompleted: String {
            ls("export.exportCompleted", comment: "")
        }
        static var backToSettings: String {
            ls("export.backToSettings", comment: "")
        }
        static var exportData: String {
            ls("export.exportData", comment: "")
        }
        static var greaterThan: String {
            ls("export.greaterThan", comment: "")
        }
        static var lessThan: String {
            ls("export.lessThan", comment: "")
        }
        static var selectSingleCurrency: String {
            ls("export.selectSingleCurrency", comment: "")
        }
        static var allAvailable: String {
            ls("export.allAvailable", comment: "")
        }
        static var noTagsSelected: String {
            ls("export.noTagsSelected", comment: "")
        }
        static var noSubcategorySelected: String {
            ls("export.noSubcategorySelected", comment: "")
        }
        static var any: String {
            ls("export.any", comment: "")
        }
        static var between: String {
            ls("export.between", comment: "")
        }
        static var condition: String {
            ls("export.condition", comment: "")
        }
        static var noneSelected: String {
            ls("export.noneSelected", comment: "")
        }
        static func accountsSelected(_ count: Int) -> String {
            String(format: ls("export.accountsSelected", comment: ""), count)
        }
        static var allCategories: String {
            ls("export.allCategories", comment: "")
        }
        static func subcategoriesSelected(_ count: Int) -> String {
            String(format: ls("export.subcategoriesSelected", comment: ""), count)
        }
        static var allTags: String {
            ls("export.allTags", comment: "")
        }
        static var allCurrencies: String {
            ls("export.allCurrencies", comment: "")
        }

        // Column display names
        static var columnDate: String { ls("export.column.date", comment: "") }
        static var columnAmount: String { ls("export.column.amount", comment: "") }
        static var columnCurrency: String { ls("export.column.currency", comment: "") }
        static var columnAccount: String { ls("export.column.account", comment: "") }
        static var columnCategory: String { ls("export.column.category", comment: "") }
        static var columnSubcategory: String { ls("export.column.subcategory", comment: "") }
        static var columnTags: String { ls("export.column.tags", comment: "") }
        static var columnNote: String { ls("export.column.note", comment: "") }
        static var columnSplitTotal: String { ls("export.column.splitTotal", comment: "") }
        static var columnSplitPortion: String { ls("export.column.splitPortion", comment: "") }

        // Column descriptions
        static var columnDateDesc: String { ls("export.column.date.description", comment: "") }
        static var columnAmountDesc: String { ls("export.column.amount.description", comment: "") }
        static var columnCurrencyDesc: String { ls("export.column.currency.description", comment: "") }
        static var columnAccountDesc: String { ls("export.column.account.description", comment: "") }
        static var columnCategoryDesc: String { ls("export.column.category.description", comment: "") }
        static var columnSubcategoryDesc: String { ls("export.column.subcategory.description", comment: "") }
        static var columnTagsDesc: String { ls("export.column.tags.description", comment: "") }
        static var columnNoteDesc: String { ls("export.column.note.description", comment: "") }
        static var columnSplitTotalDesc: String { ls("export.column.splitTotal.description", comment: "") }
        static var columnSplitPortionDesc: String { ls("export.column.splitPortion.description", comment: "") }

        // G5-D2: export ampliado con grupos (archivo CSV aparte)
        static var includeGroups: String { ls("export.includeGroups", comment: "") }
        static var includeGroupsDescription: String { ls("export.includeGroups.description", comment: "") }

        enum Groups {
            // Headers de columnas del CSV de grupos
            static var headerGroup: String { ls("export.groups.header.group", comment: "") }
            static var headerType: String { ls("export.groups.header.type", comment: "") }
            static var headerDate: String { ls("export.groups.header.date", comment: "") }
            static var headerDescription: String { ls("export.groups.header.description", comment: "") }
            static var headerFrom: String { ls("export.groups.header.from", comment: "") }
            static var headerTo: String { ls("export.groups.header.to", comment: "") }
            static var headerPaidBy: String { ls("export.groups.header.paidBy", comment: "") }
            static var headerAmount: String { ls("export.groups.header.amount", comment: "") }
            static var headerMyShare: String { ls("export.groups.header.myShare", comment: "") }
            static var headerCurrency: String { ls("export.groups.header.currency", comment: "") }

            // Valores de la columna "tipo"
            static var typeExpense: String { ls("export.groups.type.expense", comment: "") }
            static var typeSettlement: String { ls("export.groups.type.settlement", comment: "") }
            static var typeBalance: String { ls("export.groups.type.balance", comment: "") }
        }
    }

    // MARK: - Favorites

    enum Favorites {
        static var title: String { ls("favorites.title", comment: "") }
        static var new: String { ls("favorites.new", comment: "") }
        static var edit: String { ls("favorites.edit", comment: "") }
        static var noFavorites: String { ls("favorites.noFavorites", comment: "") }
        static var createTemplate: String {
            ls("favorites.createTemplate", comment: "")
        }
        static var newTitle: String {
            ls("favorites.newTitle", comment: "")
        }
        static var editTitle: String {
            ls("favorites.editTitle", comment: "")
        }
        static var namePlaceholder: String {
            ls("favorites.namePlaceholder", comment: "")
        }
        static var notConfigured: String {
            ls("favorites.notConfigured", comment: "")
        }
        static var descriptionPlaceholder: String {
            ls("favorites.descriptionPlaceholder", comment: "")
        }
        static var saveDescription: String {
            ls("favorites.saveDescription", comment: "")
        }
    }

    // MARK: - Scheduled

    enum Scheduled {
        static var saveDescription: String {
            ls("scheduled.saveDescription", comment: "")
        }

        static var paid: String {
            ls("scheduled.paid", comment: "Paid badge for scheduled payments")
        }

        static var draftCreatedTitle: String {
            ls("scheduled.draftCreatedTitle", comment: "Alert title when drafts created")
        }

        static func draftCreatedMessage(_ count: Int) -> String {
            String(format: ls("scheduled.draftCreatedMessage", comment: "Alert message"), count)
        }

        static var viewInbox: String {
            ls("scheduled.viewInbox", comment: "Button to view inbox")
        }

        enum Recurrence {
            static var daily: String { ls("scheduled.recurrence.daily", comment: "") }
            static var weekly: String { ls("scheduled.recurrence.weekly", comment: "") }
            static var monthly: String { ls("scheduled.recurrence.monthly", comment: "") }
            static var yearly: String { ls("scheduled.recurrence.yearly", comment: "") }
            static var day: String { ls("scheduled.recurrence.day", comment: "") }
            static var week: String { ls("scheduled.recurrence.week", comment: "") }
            static var month: String { ls("scheduled.recurrence.month", comment: "") }
            static var year: String { ls("scheduled.recurrence.year", comment: "") }
            static var days: String { ls("scheduled.recurrence.days", comment: "") }
            static var weeks: String { ls("scheduled.recurrence.weeks", comment: "") }
            static var months: String { ls("scheduled.recurrence.months", comment: "") }
            static var years: String { ls("scheduled.recurrence.years", comment: "") }
        }

        enum Category {
            static var recurring: String { ls("scheduled.category.recurring", comment: "") }
            static var subscription: String { ls("scheduled.category.subscription", comment: "") }
        }

        enum Status {
            static var past: String { ls("scheduled.status.past", comment: "") }
            static var today: String { ls("scheduled.status.today", comment: "") }
            static var upcoming: String { ls("scheduled.status.upcoming", comment: "") }
        }

        enum Filter {
            static var all: String { ls("scheduled.filter.all", comment: "") }
            static var paid: String { ls("scheduled.filter.paid", comment: "") }
            static var pending: String { ls("scheduled.filter.pending", comment: "") }
        }

        enum Tab {
            static var recurring: String { ls("scheduled.tab.recurring", comment: "") }
            static var subscriptions: String { ls("scheduled.tab.subscriptions", comment: "") }
            static var all: String { ls("scheduled.tab.all", comment: "") }
        }

        enum Widget {
            static var count: String { ls("scheduled.widget.count", comment: "") }
            static var emptyTitle: String { ls("scheduled.widget.empty.title", comment: "") }
            static var emptyMessage: String { ls("scheduled.widget.empty.message", comment: "") }
            static var daysAgo: String { ls("scheduled.widget.daysAgo", comment: "") }
            static var tomorrow: String { ls("scheduled.widget.tomorrow", comment: "") }
            static var inDays: String { ls("scheduled.widget.inDays", comment: "") }
            static var smallTitle: String { ls("scheduled.widget.smallTitle", comment: "") }
            static var smallToPay: String { ls("scheduled.widget.smallToPay", comment: "") }
            static var smallPaidAmount: String { ls("scheduled.widget.smallPaidAmount", comment: "") }
            static var smallActivePending: String { ls("scheduled.widget.smallActivePending", comment: "") }
            static var smallAllPaid: String { ls("scheduled.widget.smallAllPaid", comment: "") }
            static var largeTitleRecurring: String { ls("scheduled.widget.largeTitle.recurring", comment: "PP2-07 large-mode dynamic title when filter = recurring") }
        }

        enum Help {
            static var title: String { ls("scheduled.help.title", comment: "") }
            static var message: String { ls("scheduled.help.message", comment: "") }
        }

        enum Associate {
            static var paymentHeader: String { ls("scheduled.associate.paymentHeader", comment: "") }
            static var candidatesHeader: String { ls("scheduled.associate.candidatesHeader", comment: "") }
        }

        enum VariableAmount {
            static var toggle: String { ls("scheduled.variableAmount.toggle", comment: "") }
            static var helper: String { ls("scheduled.variableAmount.helper", comment: "") }
            static var badge: String { ls("scheduled.variableAmount.badge", comment: "") }
        }

        enum GroupExpense {
            static var toggle: String { ls("scheduled.groupExpense.toggle", comment: "") }
            static var toggleHelper: String { ls("scheduled.groupExpense.toggleHelper", comment: "") }
            static var sectionTitle: String { ls("scheduled.groupExpense.sectionTitle", comment: "") }
            static var groupRow: String { ls("scheduled.groupExpense.groupRow", comment: "") }
            static var currencyRow: String { ls("scheduled.groupExpense.currencyRow", comment: "") }
            static var divisionRow: String { ls("scheduled.groupExpense.divisionRow", comment: "") }
            static var totalHint: String { ls("scheduled.groupExpense.totalHint", comment: "") }
            static var sharedBadge: String { ls("scheduled.groupExpense.sharedBadge", comment: "") }
            /// "Entre %d · %@ · Tu parte %@" — participantes, modo de división, tu parte.
            static func splitSummary(_ count: Int, _ mode: String, _ share: String) -> String {
                String(format: ls("scheduled.groupExpense.splitSummary", comment: ""), count, mode, share)
            }
        }

        enum Editor {
            static var recurrence: String { ls("scheduled.editor.recurrence", comment: "") }
            static var dayOfMonth: String { ls("scheduled.editor.day.of.month", comment: "") }
            static var isSubscription: String { ls("scheduled.is.subscription", comment: "") }
            static var onetime: String { ls("scheduled.recurrence.onetime", comment: "") }
            static var recurring: String { ls("scheduled.recurrence.recurring", comment: "") }
            static var every: String { ls("scheduled.every", comment: "") }
            static var whichDays: String { ls("scheduled.which.days", comment: "") }
            static var paymentDate: String { ls("scheduled.payment.date", comment: "") }
            static var startDate: String { ls("scheduled.start.date", comment: "") }
            static var hasEndDate: String { ls("scheduled.has.end.date", comment: "") }
            static var endDate: String { ls("scheduled.end.date", comment: "") }
            static var yearlyDate: String { ls("scheduled.yearly.date", comment: "") }
            static var account: String { ls("scheduled.editor.account", comment: "") }
            static var subcategory: String { ls("scheduled.editor.subcategory", comment: "") }
            static var preview: String { ls("scheduled.editor.preview", comment: "") }
        }

        enum Detail {
            static var frequency: String { ls("scheduled.detail.frequency", comment: "") }
            static var nextDate: String { ls("scheduled.detail.next.date", comment: "") }
            static var endDate: String { ls("scheduled.detail.end.date", comment: "") }
            static var upcoming: String { ls("scheduled.detail.upcoming", comment: "") }
            static var history: String { ls("scheduled.detail.history", comment: "") }
            static var infoNote: String { ls("scheduled.detail.info.note", comment: "") }
            static var statusInactive: String { ls("scheduled.status.inactive", comment: "") }
            static var statusSkipped: String { ls("scheduled.status.skipped", comment: "") }
            static var statusPaid: String { ls("scheduled.status.paid", comment: "") }
            static var statusOverdue: String { ls("scheduled.status.overdue", comment: "") }
            static var skip: String { ls("scheduled.skip", comment: "") }
            static var skipUndo: String { ls("scheduled.skip.undo", comment: "") }
            static var nextFirst: String { ls("scheduled.next.first", comment: "") }
            static var nextSecond: String { ls("scheduled.next.second", comment: "") }
            static var nextThird: String { ls("scheduled.next.third", comment: "") }
            static var associateTitle: String { ls("scheduled.associate.title", comment: "") }
            static var unlink: String { ls("scheduled.unlink", comment: "") }
            static var advance: String { ls("scheduled.advance", comment: "") }
            static var viewRecord: String { ls("scheduled.view.record", comment: "") }
        }
    }

    // MARK: - Settings

    enum Settings {
        static var title: String { ls("settings.title", comment: "") }
        static var theme: String { ls("settings.theme", comment: "") }
        static var themeDescription: String {
            ls("settings.themeDescription", comment: "")
        }
        static var currency: String { ls("settings.currency", comment: "") }
        static var appIcon: String { ls("settings.appIcon", comment: "") }
        static var appIconDescription: String {
            ls("settings.appIconDescription", comment: "")
        }
        static var personalization: String {
            ls("settings.personalization", comment: "")
        }
        static var personalizationDescription: String {
            ls("settings.personalizationDescription", comment: "")
        }
        static var sectionInterface: String { ls("settings.sectionInterface", comment: "") }
        static var sectionCalendar: String { ls("settings.sectionCalendar", comment: "") }
        static var sectionIndicators: String { ls("settings.sectionIndicators", comment: "") }
        static var sectionFormat: String { ls("settings.sectionFormat", comment: "") }
        static var accounts: String { ls("settings.accounts", comment: "") }
        static var categories: String { ls("settings.categories", comment: "") }
        static var tags: String { ls("settings.tags", comment: "") }
        static var notifications: String {
            ls("settings.notifications", comment: "")
        }
        static var favorites: String { ls("settings.favorites", comment: "") }
        static var budgets: String { ls("settings.budgets", comment: "") }
        static var budgetsFavorites: String {
            ls("settings.budgetsFavorites", comment: "")
        }
        static var budgetsFavoritesInfo: String {
            ls("settings.budgetsFavoritesInfo", comment: "")
        }
        static var budgetsFavoritesEmptyHint: String {
            ls("settings.budgetsFavoritesEmptyHint", comment: "")
        }
        static var budgetsFavoritesReorder: String {
            ls("settings.budgetsFavoritesReorder", comment: "")
        }
        static var tabBarConfig: String {
            ls("settings.tabBarConfig", comment: "")
        }
        static var tabBarConfigInfo: String {
            ls("settings.tabBarConfigInfo", comment: "")
        }
        static var tabBarConfigActive: String {
            ls("settings.tabBarConfigActive", comment: "")
        }
        static var tabBarConfigAvailable: String {
            ls("settings.tabBarConfigAvailable", comment: "")
        }
        static var tabBarConfigReorderHint: String {
            ls("settings.tabBarConfigReorderHint", comment: "")
        }
        static var tabBarConfigMinWarning: String {
            ls("settings.tabBarConfigMinWarning", comment: "")
        }
        static var customizeAISummary: String {
            ls("settings.customizeAISummary", comment: "")
        }
        static var customizeAISummaryHint: String {
            ls("settings.customizeAISummaryHint", comment: "")
        }
        static var tabBarConfigMaxWarning: String {
            ls("settings.tabBarConfigMaxWarning", comment: "")
        }
        static var plannedPayments: String {
            ls("settings.plannedPayments", comment: "")
        }
        static var voiceInputEnabled: String {
            ls("settings.voiceInputEnabled", comment: "")
        }
        static var voiceLanguage: String {
            ls("settings.voiceLanguage", comment: "")
        }
        static var appLanguage: String {
            ls("settings.appLanguage", comment: "")
        }
        static var appLanguageRestart: String {
            ls("settings.appLanguageRestart", comment: "")
        }
        static var imageInputEnabled: String {
            ls("settings.imageInputEnabled", comment: "")
        }
        static var resetData: String { ls("settings.resetData", comment: "") }
        static var version: String { ls("settings.version", comment: "") }
        static var light: String { ls("settings.light", comment: "") }
        static var dark: String { ls("settings.dark", comment: "") }
        static var system: String { ls("settings.system", comment: "") }
        static var themeIndigo: String { ls("settings.theme.indigo", comment: "") }
        static var themeRosa: String { ls("settings.theme.rosa", comment: "") }
        static var themeTeal: String { ls("settings.theme.teal", comment: "") }
        static var themeMinimalist: String { ls("settings.theme.minimalist", comment: "") }
        static var themeTranslucent: String { ls("settings.theme.translucent", comment: "") }
        static var themeLiquidGlass: String { ls("settings.theme.liquidGlass", comment: "") }
        static var defaultCurrency: String {
            ls("settings.defaultCurrency", comment: "")
        }
        static var currentIcon: String { ls("settings.currentIcon", comment: "") }
        static var resetAllData: String { ls("settings.resetAllData", comment: "") }
        static var deleteAllData: String {
            ls("settings.deleteAllData", comment: "")
        }
        static var currencyAndExchange: String {
            ls("settings.currencyAndExchange", comment: "")
        }
        static var currencyDescription: String {
            ls("settings.currencyDescription", comment: "")
        }
        static var preferredCurrency: String {
            ls("settings.preferredCurrency", comment: "")
        }
        static var exchangeRate: String { ls("settings.exchangeRate", comment: "") }
        static var secondaryCurrencies: String {
            ls("settings.secondaryCurrencies", comment: "")
        }
        static var secondaryCurrenciesHint: String {
            ls("settings.secondaryCurrenciesHint", comment: "")
        }
        static var showMoreCurrencies: String {
            ls("settings.showMoreCurrencies", comment: "")
        }
        static var recommendedCurrencies: String {
            ls("settings.recommendedCurrencies", comment: "")
        }

        static var versionInfo: String { ls("settings.versionInfo", comment: "") }

        // Sections
        static var organization: String { ls("settings.organization", comment: "") }
        static var preferences: String { ls("settings.preferences", comment: "") }
        static var aiFeatures: String { ls("settings.aiFeatures", comment: "") }
        static var chatAssistant: String { ls("settings.chatAssistant", comment: "") }
        static var data: String { ls("settings.data", comment: "") }
        static var security: String { ls("settings.security", comment: "") }
        static var help: String { ls("settings.help", comment: "") }
        static var legal: String { ls("settings.legal", comment: "") }

        // Rows
        static var importData: String { ls("settings.importData", comment: "") }
        static var exportData: String { ls("settings.exportData", comment: "") }
        static var wipeData: String { ls("settings.wipeData", comment: "") }
        static var faceId: String { ls("settings.faceId", comment: "") }
        static var permissions: String { ls("settings.permissions", comment: "") }
        static var faceIDProtection: String { ls("settings.faceIDProtection", comment: "") }
        static var aiPrivacy: String { ls("settings.aiPrivacy", comment: "") }
        static var subscriptions: String {
            ls("settings.subscriptions", comment: "")
        }
        static var rateApp: String { ls("settings.rateApp", comment: "") }
        static var tutorials: String { ls("settings.tutorials", comment: "") }
        static var faq: String { ls("settings.faq", comment: "") }
        static var contact: String { ls("settings.contact", comment: "") }
        static var privacy: String { ls("settings.privacy", comment: "") }
        static var terms: String { ls("settings.terms", comment: "") }

        // system, light, dark removed (duplicates)

        static var defaultPeriod: String {
            ls("settings.defaultPeriod", comment: "")
        }
        static var defaultPeriodDescription: String {
            ls("settings.defaultPeriodDescription", comment: "")
        }
        static var colorfulIcons: String {
            ls("settings.colorfulIcons", comment: "")
        }
        static var colorfulIconsDescription: String {
            ls("settings.colorfulIconsDescription", comment: "")
        }
        static var colorfulIconsDisabledByTheme: String {
            ls("settings.colorfulIconsDisabledByTheme", comment: "")
        }
        static var firstWeekday: String {
            ls("settings.firstWeekday", comment: "")
        }
        static var firstWeekdayDescription: String {
            ls("settings.firstWeekdayDescription", comment: "")
        }
        static var sunday: String {
            ls("settings.sunday", comment: "")
        }
        static var monday: String {
            ls("settings.monday", comment: "")
        }
        static var widgetHints: String {
            ls("settings.widgetHints", comment: "")
        }
        static var widgetHintsDescription: String {
            ls("settings.widgetHintsDescription", comment: "")
        }
        static var showVariations: String {
            ls("settings.showVariations", comment: "")
        }
        static var showVariationsDescription: String {
            ls("settings.showVariationsDescription", comment: "")
        }
        static var averageLine: String {
            ls("settings.averageLine", comment: "")
        }
        static var averageLineDescription: String {
            ls("settings.averageLineDescription", comment: "")
        }
        static var averageLineOff: String {
            ls("settings.averageLine.off", comment: "")
        }
        static var averageLineTotal: String {
            ls("settings.averageLine.total", comment: "")
        }
        static var averageLineSegmented: String {
            ls("settings.averageLine.segmented", comment: "")
        }
        static var averageLineOffDescription: String {
            ls("settings.averageLine.offDescription", comment: "")
        }
        static var averageLineTotalDescription: String {
            ls("settings.averageLine.totalDescription", comment: "")
        }
        static var averageLineSegmentedDescription: String {
            ls("settings.averageLine.segmentedDescription", comment: "")
        }
        static var decimalPlaces: String {
            ls("settings.decimalPlaces", comment: "")
        }
        static var decimalPlacesDescription: String {
            ls("settings.decimalPlacesDescription", comment: "")
        }
        static var decimalsNone: String {
            ls("settings.decimalsNone", comment: "")
        }
        static var decimalsOne: String {
            ls("settings.decimalsOne", comment: "")
        }
        static var decimalsTwo: String {
            ls("settings.decimalsTwo", comment: "")
        }
        static var currencyFormat: String {
            ls("settings.currencyFormat", comment: "")
        }
        static var currencyFormatDescription: String {
            ls("settings.currencyFormatDescription", comment: "")
        }
        static var currencyCode: String {
            ls("settings.currencyCode", comment: "")
        }
        static var currencySymbol: String {
            ls("settings.currencySymbol", comment: "")
        }
        static var autoFocusField: String {
            ls("settings.autoFocusField", comment: "")
        }
        static var autoFocusFieldDescription: String {
            ls("settings.autoFocusFieldDescription", comment: "")
        }
        static var autoFocusAmount: String {
            ls("settings.autoFocusAmount", comment: "")
        }
        static var autoFocusNote: String {
            ls("settings.autoFocusNote", comment: "")
        }
        static var autoFocusNone: String {
            ls("settings.autoFocusNone", comment: "")
        }
        // resetData removed (duplicate)
        static var resetDataDescription: String {
            ls("settings.resetDataDescription", comment: "")
        }
        // deleteAllData removed (duplicate)
        static var deleteDataConfirmation: String {
            ls("settings.deleteDataConfirmation", comment: "")
        }
        static var deleteDataWarning: String {
            ls("settings.deleteDataWarning", comment: "")
        }
        static var wipeICloudWarning: String {
            ls("settings.wipeICloudWarning", comment: "")
        }
        /// Aclaración: el wipe NO toca grupos (separación A0-Bridge V2.0).
        static var wipeGroupsExclusionNote: String {
            ls("settings.wipeGroupsExclusionNote", comment: "")
        }
        /// Descripción de "Borrar datos" en modo solo-grupos (sin finanzas personales).
        static var resetDataDescriptionGroupsOnly: String {
            ls("settings.resetDataDescriptionGroupsOnly", comment: "")
        }
        /// Advertencia de la alerta de borrado en modo solo-grupos.
        static var deleteDataWarningGroupsOnly: String {
            ls("settings.deleteDataWarningGroupsOnly", comment: "")
        }
        // Cierre de sesión universal (H4 — privada y nube)
        static var signOut: String { ls("settings.signOut", comment: "") }
        static var signOutConfirmTitle: String { ls("settings.signOutConfirmTitle", comment: "") }
        static var signOutConfirmAction: String { ls("settings.signOutConfirmAction", comment: "") }
        static var signOutConfirmMessageCloud: String {
            ls("settings.signOutConfirmMessageCloud", comment: "")
        }
        static var signOutConfirmMessageICloud: String {
            ls("settings.signOutConfirmMessageICloud", comment: "")
        }
        static var signOutConfirmMessageSecondary: String {
            ls("settings.signOutConfirmMessageSecondary", comment: "")
        }
        static var signOutConfirmMessageGroupsOnly: String {
            ls("settings.signOutConfirmMessageGroupsOnly", comment: "")
        }
        static var groupsAccountRowTitle: String {
            ls("settings.groupsAccountRowTitle", comment: "")
        }
        static var groupsAccountRowSubtitle: String {
            ls("settings.groupsAccountRowSubtitle", comment: "")
        }
        static var signOutBlockedTitle: String { ls("settings.signOutBlockedTitle", comment: "") }
        static var signOutBlockedMessage: String { ls("settings.signOutBlockedMessage", comment: "") }
        // Eliminar mi cuenta (G5-D1b — borrado GDPR, DARK)
        static var deleteAccount: String { ls("settings.deleteAccount", comment: "") }
        static var deleteAccountConfirmTitle: String { ls("settings.deleteAccountConfirmTitle", comment: "") }
        static var deleteAccountConfirmMessageCloud: String {
            ls("settings.deleteAccountConfirmMessageCloud", comment: "")
        }
        static var deleteAccountConfirmMessageGroupsOnly: String {
            ls("settings.deleteAccountConfirmMessageGroupsOnly", comment: "")
        }
        static var deleteAccountContinue: String { ls("settings.deleteAccountContinue", comment: "") }
        static var deleteAccountFinalTitle: String { ls("settings.deleteAccountFinalTitle", comment: "") }
        static var deleteAccountFinalMessage: String { ls("settings.deleteAccountFinalMessage", comment: "") }
        static var deleteAccountFinalAction: String { ls("settings.deleteAccountFinalAction", comment: "") }
        static var deleteAccountErrorTitle: String { ls("settings.deleteAccountErrorTitle", comment: "") }
        static var deleteAccountErrorMessage: String { ls("settings.deleteAccountErrorMessage", comment: "") }
        static var deleteAccountRetry: String { ls("settings.deleteAccountRetry", comment: "") }
        static var delete: String { ls("settings.delete", comment: "") }
        static var cancel: String { ls("settings.cancel", comment: "") }
        static var iconOriginal: String { ls("settings.iconOriginal", comment: "") }
        static var iconDark: String { ls("settings.iconDark", comment: "") }
        static var iconLight: String { ls("settings.iconLight", comment: "") }
        static var iconNeon: String { ls("settings.iconNeon", comment: "") }
        static var deleteAllDataAction: String {
            ls("settings.deleteAllDataAction", comment: "")
        }
        static var deletingData: String {
            ls("settings.deletingData", comment: "")
        }
        static var appIconTitle: String {
            ls("settings.appIconTitle", comment: "")
        }
        static var iconNotSupported: String {
            ls("settings.iconNotSupported", comment: "")
        }
        static func iconChangeFailed(_ error: String) -> String {
            String(format: ls("settings.iconChangeFailed", comment: ""), error)
        }
        static var deleteDataError: String {
            ls("settings.deleteDataError", comment: "")
        }
        static var deleteDataUnknownError: String {
            ls("settings.deleteDataUnknownError", comment: "")
        }

        // Expenses Only Mode
        static var sectionUsageMode: String { ls("settings.sectionUsageMode", comment: "") }
        static var expensesOnlyMode: String { ls("settings.expensesOnlyMode", comment: "") }
        // A0-Bridge: Group visibility settings
        static var sectionGroups: String { ls("settings.sectionGroups", comment: "") }
        static var sectionGroupsHint: String { ls("settings.sectionGroupsHint", comment: "") }
        static var includeGroupsInPanelTotal: String { ls("settings.includeGroupsInPanelTotal", comment: "") }
        static var includeGroupTransactionsInStats: String { ls("settings.includeGroupTransactionsInStats", comment: "") }
        static var expensesOnlyModeDescription: String { ls("settings.expensesOnlyModeDescription", comment: "") }
        static var expensesOnlyActivateTitle: String { ls("settings.expensesOnlyActivateTitle", comment: "") }
        static var expensesOnlyActivateMessage: String { ls("settings.expensesOnlyActivateMessage", comment: "") }
        static var expensesOnlyActivateConfirm: String { ls("settings.expensesOnlyActivateConfirm", comment: "") }
        static var expensesOnlyDeactivateTitle: String { ls("settings.expensesOnlyDeactivateTitle", comment: "") }
        static var expensesOnlyDeactivateMessage: String { ls("settings.expensesOnlyDeactivateMessage", comment: "") }
        static var expensesOnlyDeactivateConfirm: String { ls("settings.expensesOnlyDeactivateConfirm", comment: "") }
        static var expensesOnlyActive: String { ls("settings.expensesOnlyActive", comment: "") }
        static var categoryHidden: String { ls("settings.categoryHidden", comment: "") }
    }

    // MARK: - Support

    enum Support {
        static var title: String { ls("support.title", comment: "") }
        static var type: String { ls("support.type", comment: "") }
        static var typeError: String { ls("support.typeError", comment: "") }
        static var typeImprovement: String { ls("support.typeImprovement", comment: "") }
        static var typeIdea: String { ls("support.typeIdea", comment: "") }
        static var message: String { ls("support.message", comment: "") }
        static var messagePlaceholder: String { ls("support.messagePlaceholder", comment: "") }
        static var send: String { ls("support.send", comment: "") }
    }

    // MARK: - Profile

    enum Profile {
        static var defaultName: String { ls("profile.defaultName", comment: "") }
        static var title: String { ls("profile.title", comment: "") }
        static var edit: String { ls("profile.edit", comment: "") }
        static var importSuccess: String { ls("profile.importSuccess", comment: "") }
        static var importError: String { ls("profile.importError", comment: "") }
        static var appearance: String { ls("profile.appearance", comment: "") }
        static var personalDetails: String {
            ls("profile.personalDetails", comment: "")
        }
        static var changePhoto: String { ls("profile.changePhoto", comment: "") }
        static var addPhoto: String { ls("profile.addPhoto", comment: "") }
        static var yourName: String { ls("profile.yourName", comment: "") }
        static var aliasPlaceholder: String {
            ls("profile.aliasPlaceholder", comment: "")
        }
        static var characters: String { ls("profile.characters", comment: "") }
        static var minChars: String { ls("profile.minChars", comment: "") }
        static var maxChars: String { ls("profile.maxChars", comment: "") }
        static var allowedChars: String { ls("profile.allowedChars", comment: "") }
        static var aliasAvailable: String {
            ls("profile.aliasAvailable", comment: "")
        }
        static var aliasHelper: String { ls("profile.aliasHelper", comment: "") }
        static var privacyTitle: String { ls("profile.privacyTitle", comment: "") }
        static var privacyDesc: String { ls("profile.privacyDesc", comment: "") }
        static var aliasFutureNote: String {
            ls("profile.aliasFutureNote", comment: "")
        }
        static var proMember: String {
            ls("profile.proMember", comment: "Pro member subtitle")
        }
        static var choosePhoto: String { ls("profile.choosePhoto", comment: "") }
        static var chooseIcon: String { ls("profile.chooseIcon", comment: "") }
        static var removeAvatar: String { ls("profile.removeAvatar", comment: "") }
        static var editAvatar: String { ls("profile.editAvatar", comment: "") }
    }

    // MARK: - Common

    enum Common {
        static var accept: String { ls("common.accept", comment: "") }
        static var name: String { ls("common.name", comment: "") }
        static var alias: String { ls("common.alias", comment: "") }
        static var color: String { ls("common.color", comment: "") }
        static var icon: String { ls("common.icon", comment: "") }
        static var changeIcon: String { ls("common.changeIcon", comment: "") }
        static var search: String { ls("common.search", comment: "") }
        static var loading: String { ls("common.loading", comment: "") }
        static var error: String { ls("common.error", comment: "") }
        static var success: String { ls("common.success", comment: "") }
        static var unknownError: String { ls("common.unknownError", comment: "") }
        static var saveError: String { ls("common.saveError", comment: "") }
        static var deleteError: String { ls("common.deleteError", comment: "") }
        static var dataPrivacy: String { ls("common.dataPrivacy", comment: "") }
        static var active: String { ls("common.active", comment: "") }
        static var inactive: String { ls("common.inactive", comment: "") }
        static var hidden: String { ls("common.hidden", comment: "") }
        static var archived: String { ls("common.archived", comment: "") }
        static var recent: String { ls("common.recent", comment: "") }
        static var updatingRecords: String {
            ls("common.updatingRecords", comment: "")
        }
        static var recalculatingConversions: String {
            ls("common.recalculatingConversions", comment: "")
        }
        static var next: String { ls("common.next", comment: "") }
        static var vs: String { ls("common.vs", comment: "Separator between current and previous amount in chart comparisons") }
        static var moreOptions: String { ls("common.moreOptions", comment: "") }
        static var comingSoon: String { ls("common.comingSoon", comment: "") }
        static var all: String { ls("common.all", comment: "") }
        static var others: String { ls("common.others", comment: "") }
        static var remaining: String { ls("common.remaining", comment: "") }
        static var uncategorized: String { ls("common.uncategorized", comment: "") }
        static var date: String { ls("common.date", comment: "") }
        static var amount: String { ls("common.amount", comment: "") }
        static var base: String { ls("common.base", comment: "") }
        static var selectedDate: String { ls("common.selectedDate", comment: "") }
        static var selectedValue: String { ls("common.selectedValue", comment: "") }
        static var selectColor: String { ls("common.selectColor", comment: "") }
        static var useThisColor: String { ls("common.useThisColor", comment: "") }
        static var newColor: String { ls("common.newColor", comment: "") }
        static var understood: String { ls("common.understood", comment: "") }
        static var cannotUndo: String { ls("common.cannotUndo", comment: "") }
        static var general: String { ls("common.general", comment: "") }
        static var status: String { ls("common.status", comment: "") }
        static var actions: String { ls("common.actions", comment: "") }
        static var lastUpdate: String { ls("common.lastUpdate", comment: "") }
        static var cancel: String { ls("action.cancel", comment: "") }
        static var apply: String { ls("common.apply", comment: "Apply action") }
        static var selected: String { ls("common.selected", comment: "") }
        static var details: String { ls("common.details", comment: "") }
        static var select: String { ls("common.select", comment: "") }
        static var seeAll: String { ls("common.seeAll", comment: "") }
        static var none: String { ls("common.none", comment: "") }
        static var ok: String { ls("common.ok", comment: "") }
    }

    // MARK: - Widgets

    enum Widget {
        static var today: String { ls("widget.today", comment: "") }
        static var noData: String { ls("widget.noData", comment: "") }
        static var loading: String { ls("widget.loading", comment: "") }
        static var visible: String { ls("widget.visible", comment: "") }
        static var summary: String { ls("widget.summary", comment: "") }
        static var list: String { ls("widget.list", comment: "") }
        static var calendar: String { ls("widget.calendar", comment: "") }
        static var preferencesDescription: String {
            ls("widget.preferences.description", comment: "")
        }
        static var resetLayout: String { ls("widget.resetLayout", comment: "") }
        static var alwaysVisible: String { ls("widget.alwaysVisible", comment: "") }
        static var fixedPosition: String { ls("widget.fixedPosition", comment: "") }
        static var sizeLabel: String { ls("widget.sizeLabel", comment: "") }
        static var chatFabToggle: String { ls("widget.chatFab.toggle", comment: "") }
        static var chatFabDescription: String { ls("widget.chatFab.description", comment: "") }
        static var chatFabHint: String { ls("widget.chatFab.hint", comment: "") }
        static var aiCapabilitiesHeader: String { ls("widget.aiCapabilities.header", comment: "") }
        static var main: String { ls("widget.main", comment: "") }
        static var topCategories: String { ls("widget.topCategories", comment: "") }
        static var topSubcategories: String {
            ls("widget.topSubcategories", comment: "")
        }

        static var subcategories: String { ls("widget.subcategories", comment: "") }
        static var categories: String { ls("widget.categories", comment: "") }
        static var noExpensesPeriod: String {
            ls("widget.noExpensesPeriod", comment: "")
        }
        static var noExpensesSubcategoriesPeriod: String {
            ls("widget.noExpensesSubcategoriesPeriod", comment: "")
        }
        static var noExpensesNeedPeriod: String {
            ls("widget.noExpensesNeedPeriod", comment: "")
        }
        static var noExpensesDescriptionCategories: String {
            ls("widget.noExpensesDescriptionCategories", comment: "")
        }
        static var noExpensesDescriptionSubcategories: String {
            ls("widget.noExpensesDescriptionSubcategories", comment: "")
        }
        static var of: String { ls("widget.of", comment: "") }
        static var ofTotal: String { ls("widget.ofTotal", comment: "") }
        static var ofExpense: String { ls("widget.ofExpense", comment: "") }
        static var categoryAbbr: String { ls("widget.categoryAbbr", comment: "") }
        static var distributionByCategory: String {
            ls("widget.distributionByCategory", comment: "")
        }
        static var distributionBySubcategory: String {
            ls("widget.distributionBySubcategory", comment: "")
        }
        static var distributionByNeed: String {
            ls("widget.distributionByNeed", comment: "")
        }
        static var distributionByTag: String {
            ls("widget.distributionByTag", comment: "")
        }
        static var noDataForPeriod: String {
            ls("widget.noDataForPeriod", comment: "")
        }
        static func selectCurrencies(_ currency: String) -> String {
            String(format: ls("widget.selectCurrencies", comment: ""), currency)
        }
        static var currenciesToCompare: String {
            ls("widget.currenciesToCompare", comment: "")
        }
        static var noRecordsForFilters: String {
            ls("widget.noRecordsForFilters", comment: "")
        }
        static var recordsWillAppear: String {
            ls("widget.recordsWillAppear", comment: "")
        }
        static var total: String { ls("widget.total", comment: "") }
        static var average: String { ls("widget.average", comment: "") }

        // Widget Hints
        enum Hint {
            static var trend: String {
                ls("widget.hint.trend", comment: "")
            }
            static var topCategories: String {
                ls("widget.hint.topCategories", comment: "")
            }
            static var topSubcategories: String {
                ls("widget.hint.topSubcategories", comment: "")
            }
            static var categoriesPie: String {
                ls("widget.hint.categoriesPie", comment: "")
            }
            static var subcategoriesPie: String {
                ls("widget.hint.subcategoriesPie", comment: "")
            }
            static var tagsPie: String {
                ls("widget.hint.tagsPie", comment: "")
            }
            static var needTrend: String {
                ls("widget.hint.needTrend", comment: "")
            }
            static var cashFlow: String {
                ls("widget.hint.cashFlow", comment: "")
            }
            static var recentRecords: String {
                ls("widget.hint.recentRecords", comment: "")
            }
            static var budgets: String {
                ls("widget.hint.budgets", comment: "")
            }
            static var exchangeRate: String {
                ls("widget.hint.exchangeRate", comment: "")
            }
            static var scheduledPayments: String {
                ls("widget.hint.scheduledPayments", comment: "")
            }
            static var spendingAnalysis: String {
                ls("widget.hint.spendingAnalysis", comment: "")
            }
            static var incomeAnalysis: String {
                ls("widget.hint.incomeAnalysis", comment: "")
            }
        }
    }

    // MARK: - Widget Types

    enum WidgetType {
        static var trend: String { ls("widgetType.trend", comment: "") }
        static var topSpending: String { ls("widgetType.topSpending", comment: "") }
        static var topSubcategories: String {
            ls("widgetType.topSubcategories", comment: "")
        }
        static var cashFlow: String { ls("widgetType.cashFlow", comment: "") }
        static var categoriesPie: String {
            ls("widgetType.categoriesPie", comment: "")
        }
        static var subcategoriesPie: String {
            ls("widgetType.subcategoriesPie", comment: "")
        }
        static var latestRecords: String {
            ls("widgetType.latestRecords", comment: "")
        }
        static var expensesByNeed: String {
            ls("widgetType.expensesByNeed", comment: "")
        }
        static var expensesByTag: String {
            ls("widgetType.expensesByTag", comment: "")
        }
        static var exchangeRate: String {
            ls("widgetType.exchangeRate", comment: "")
        }
        static var budgets: String {
            ls("widgetType.budgets", comment: "")
        }
        static var scheduledPayments: String {
            ls("widgetType.scheduledPayments", comment: "")
        }
        static var weekdayBar: String {
            ls("widgetType.weekdayBar", comment: "")
        }
    }

    // MARK: - Budgets

    enum Budgets {
        enum Widget {
            static var selectFavorites: String {
                ls("budgets.widget.selectFavorites", comment: "")
            }
            static var noFavoritesTitle: String {
                ls("budgets.widget.noFavorites.title", comment: "")
            }
            static var noFavoritesMessage: String {
                ls("budgets.widget.noFavorites.message", comment: "")
            }
        }

        static var emptyTitle: String { ls("budgets.empty.title", comment: "") }
        static var emptyMessage: String { ls("budgets.empty.message", comment: "") }

        // Shared expenses
        static var includeSharedExpenses: String { ls("budgets.includeSharedExpenses", comment: "") }
        static var includeSharedExpensesHint: String { ls("budgets.includeSharedExpensesHint", comment: "") }

        // Alert notifications
        static var alertsTitle: String {
            ls("budgets.alerts.title", comment: "")
        }
        static var alertsEnable: String {
            ls("budgets.alerts.enable", comment: "")
        }
        static var alertsThresholds: String {
            ls("budgets.alerts.thresholds", comment: "")
        }
        /// "Presupuesto \"%@\" al 50%% — %@ de %@ gastados" (name, spent, limit)
        static func alertMessage50(_ name: String, _ spent: String, _ limit: String) -> String {
            String(format: ls("budgets.alerts.message.50", comment: ""), name, spent, limit)
        }

        /// "Presupuesto \"%@\" al 75%% — %@ de %@ gastados" (name, spent, limit)
        static func alertMessage75(_ name: String, _ spent: String, _ limit: String) -> String {
            String(format: ls("budgets.alerts.message.75", comment: ""), name, spent, limit)
        }

        /// "Cuidado: \"%@\" casi agotado — %@ de %@" (name, spent, limit)
        static func alertMessage90(_ name: String, _ spent: String, _ limit: String) -> String {
            String(format: ls("budgets.alerts.message.90", comment: ""), name, spent, limit)
        }

        /// "Presupuesto \"%@\" agotado — Gastaste %@ de %@" (name, spent, limit)
        static func alertMessage100(_ name: String, _ spent: String, _ limit: String) -> String {
            String(format: ls("budgets.alerts.message.100", comment: ""), name, spent, limit)
        }

        /// Hint when budget alerts are globally disabled
        static var alertsGlobalDisabledHint: String { ls("budgets.alerts.globalDisabledHint", comment: "") }

        /// Accessibility label for the period type segmented picker
        static var periodTypeLabel: String { ls("budgets.period.typeLabel", comment: "") }
        /// Placeholder for the custom alert threshold field (1–100)
        static var thresholdPlaceholder: String { ls("budgets.alerts.thresholdPlaceholder", comment: "") }
    }

    // MARK: - Budget Detail

    enum BudgetDetail {
        static var infoTitle: String { ls("budgets.detail.info", comment: "") }
        static var period: String { ls("budgets.detail.period", comment: "") }
        static var accounts: String { ls("budgets.detail.accounts", comment: "") }
        static var categories: String { ls("budgets.detail.categories", comment: "") }
        static var tags: String { ls("budgets.detail.tags", comment: "") }
        static var needs: String { ls("budgets.detail.needs", comment: "") }
        static var alerts: String { ls("budgets.detail.alerts", comment: "") }
        static var allAccounts: String { ls("budgets.detail.allAccounts", comment: "") }
        static var allCategories: String { ls("budgets.detail.allCategories", comment: "") }
        static var subcategories: String { ls("budgets.detail.subcategories", comment: "") }
        static var allSubcategories: String { ls("budgets.detail.allSubcategories", comment: "") }
        static var notFound: String { ls("budgets.detail.notFound", comment: "") }
        static var statusTitle: String { ls("budgets.detail.status", comment: "") }
        static var chartsTitle: String { ls("budgets.charts.title", comment: "") }
        static var chartsCompliance: String { ls("budgets.charts.compliance", comment: "") }
        static var chartsDailySpending: String { ls("budgets.charts.dailySpending", comment: "") }
        static var chartsCategoryBreakdown: String { ls("budgets.charts.categoryBreakdown", comment: "") }
        static var chartsNoData: String { ls("budgets.charts.noData", comment: "") }
    }

    // MARK: - Planning

    enum Planning {
        static var title: String { ls("planning.title", comment: "") }
        static var budgets: String { ls("planning.budgets", comment: "") }
        static var goals: String { ls("planning.goals", comment: "") }
        static var comingSoon: String { ls("planning.comingSoon", comment: "") }
        static var scheduledPayments: String {
            ls("planning.scheduledPayments", comment: "")
        }

        enum Scheduled {
            static var totalLabel: String { ls("planning.scheduled.totalLabel", comment: "") }
        }

        enum BudgetCharts {
            static var historyTitle: String { ls("planning.budgetCharts.historyTitle", comment: "") }
            static var historyHint: String { ls("planning.budgetCharts.historyHint", comment: "") }
            static var spendingTitle: String { ls("planning.budgetCharts.spendingTitle", comment: "") }
            static var spendingHint: String { ls("planning.budgetCharts.spendingHint", comment: "") }
            static var byCategoryTitle: String { ls("planning.budgetCharts.byCategoryTitle", comment: "") }
            static var byCategoryHint: String { ls("planning.budgetCharts.byCategoryHint", comment: "") }
            static func spentOf(_ spent: String, _ limit: String) -> String {
                String(format: ls("planning.budgetCharts.spentOf", comment: ""), spent, limit)
            }
        }
    }

    // MARK: - Profile
    // MARK: - Icon Picker

    enum IconPicker {
        static var title: String { ls("iconPicker.title", comment: "") }
        static var preview: String { ls("iconPicker.preview", comment: "") }
        static var shopping: String { ls("iconPicker.shopping", comment: "") }
        static var food: String { ls("iconPicker.food", comment: "") }
        static var transport: String {
            ls("iconPicker.transport", comment: "")
        }
        static var finance: String { ls("iconPicker.finance", comment: "") }
        static var home: String { ls("iconPicker.home", comment: "") }
        static var services: String { ls("iconPicker.services", comment: "") }
        static var entertainment: String {
            ls("iconPicker.entertainment", comment: "")
        }
        static var sports: String { ls("iconPicker.sports", comment: "") }
        static var health: String { ls("iconPicker.health", comment: "") }
        static var personalCare: String {
            ls("iconPicker.personalCare", comment: "")
        }
        static var education: String {
            ls("iconPicker.education", comment: "")
        }
        static var work: String { ls("iconPicker.work", comment: "") }
        static var pets: String { ls("iconPicker.pets", comment: "") }
        static var need: String { ls("iconPicker.need", comment: "") }
        static var tech: String { ls("iconPicker.tech", comment: "") }
        static var travel: String { ls("iconPicker.travel", comment: "") }
        static var communication: String {
            ls("iconPicker.communication", comment: "")
        }
        static var tools: String { ls("iconPicker.tools", comment: "") }
        static var security: String { ls("iconPicker.security", comment: "") }
        static var symbols: String { ls("iconPicker.symbols", comment: "") }
        static var direction: String {
            ls("iconPicker.direction", comment: "")
        }
        static var other: String { ls("iconPicker.other", comment: "") }
    }

    // MARK: - CashFlow View Type

    enum CashFlowViewType {
        static var total: String { ls("cashFlowViewType.total", comment: "") }
        static var byAccount: String {
            ls("cashFlowViewType.byAccount", comment: "")
        }
        static var byCurrency: String {
            ls("cashFlowViewType.byCurrency", comment: "")
        }
    }

    // MARK: - List View Type

    enum ListViewType {
        static var categories: String { ls("listViewType.categories", comment: "") }
        static var subcategories: String {
            ls("listViewType.subcategories", comment: "")
        }
    }

    // MARK: - Comparison Mode

    enum Comparison {
        static var month: String { ls("comparison.month", comment: "Month comparison") }
        static var year: String { ls("comparison.year", comment: "Year comparison") }
        static var monthShort: String { ls("comparison.monthShort", comment: "Short for previous period") }
        static var yearShort: String { ls("comparison.yearShort", comment: "Short for previous year") }
    }

    // MARK: - Validation

    enum Validation {
        static var enterAmountGreaterThanZero: String {
            ls("validation.enterAmountGreaterThanZero", comment: "")
        }
        static var selectSourceAccount: String {
            ls("validation.selectSourceAccount", comment: "")
        }
        static var selectDestinationAccount: String {
            ls("validation.selectDestinationAccount", comment: "")
        }
        static var accountsMustBeDifferent: String {
            ls("validation.accountsMustBeDifferent", comment: "")
        }
        static var selectAccount: String {
            ls("validation.selectAccount", comment: "")
        }
        static var selectSubcategory: String {
            ls("validation.selectSubcategory", comment: "")
        }
        static var completeFieldsFirst: String {
            ls("validation.completeFieldsFirst", comment: "")
        }
        static var futureDateTitle: String {
            ls("validation.futureDateTitle", comment: "")
        }
        static var futureDateMessage: String {
            ls("validation.futureDateMessage", comment: "")
        }
    }

    // MARK: - Transfer

    enum Transfer {
        static func transferTo(_ accountName: String) -> String {
            String(format: ls("transfer.transferTo", comment: ""), accountName)
        }
        static func transferFrom(_ accountName: String) -> String {
            String(format: ls("transfer.transferFrom", comment: ""), accountName)
        }
        static var categoryName: String {
            ls("transfer.categoryName", comment: "")
        }
    }

    enum More {
        static var toolsSection: String { ls("more.toolsSection", comment: "") }

        /// Enunciados cortos de las cards del dashboard "Más" (brand-voice).
        enum Subtitle {
            static var panel: String { ls("more.subtitle.panel", comment: "") }
            static var insights: String { ls("more.subtitle.insights", comment: "") }
            static var trends: String { ls("more.subtitle.trends", comment: "") }
            static var distribution: String { ls("more.subtitle.distribution", comment: "") }
            static var budgets: String { ls("more.subtitle.budgets", comment: "") }
            static var scheduledPayments: String { ls("more.subtitle.scheduledPayments", comment: "") }
            static var comparative: String { ls("more.subtitle.comparative", comment: "") }
            static var cashFlow: String { ls("more.subtitle.cashFlow", comment: "") }
            static var records: String { ls("more.subtitle.records", comment: "") }
            static var groups: String { ls("more.subtitle.groups", comment: "") }
            static var profile: String { ls("more.subtitle.profile", comment: "") }
        }

        /// Editor del dashboard "Más" (toolbar): reordenar secciones + tab bar.
        enum Editor {
            static var title: String { ls("more.editor.title", comment: "") }
            static var sectionsHeader: String { ls("more.editor.sectionsHeader", comment: "") }
            static var tabBarHint: String { ls("more.editor.tabBarHint", comment: "") }
        }
    }

    // MARK: - Auth (sign-in compartido — botones de provider)

    enum Auth {
        /// "Continuar con Google" — texto del `GoogleSignInButton` (brand guideline: acompaña
        /// SIEMPRE al logo G; compartido por Welcome y GroupsSignIn).
        static var googleButton: String { ls("auth.googleButton", comment: "") }
    }

    // MARK: - Welcome (Chooser pre-onboarding A4)

    enum Welcome {
        enum Chooser {
            static var title: String { ls("welcome.chooser.title", comment: "") }
            static var subtitle: String { ls("welcome.chooser.subtitle", comment: "") }
            static var optionNewTitle: String { ls("welcome.chooser.optionNew.title", comment: "") }
            static var optionNewBody: String { ls("welcome.chooser.optionNew.body", comment: "") }
            static var optionExistingTitle: String { ls("welcome.chooser.optionExisting.title", comment: "") }
            static var optionExistingBody: String { ls("welcome.chooser.optionExisting.body", comment: "") }
            static var optionInviteTitle: String { ls("welcome.chooser.optionInvite.title", comment: "") }
            static var optionInviteBody: String { ls("welcome.chooser.optionInvite.body", comment: "") }
        }

        /// Sub-chooser de "Ya tengo una cuenta" (2º nivel, H4).
        enum Existing {
            static var subtitle: String { ls("welcome.existing.subtitle", comment: "") }
            static var restoreTitle: String { ls("welcome.existing.restoreTitle", comment: "") }
            static var restoreBody: String { ls("welcome.existing.restoreBody", comment: "") }
            static var cloudTitle: String { ls("welcome.existing.cloudTitle", comment: "") }
            static var cloudBody: String { ls("welcome.existing.cloudBody", comment: "") }
            // Sesión 2: tercera card — sign-in con Google.
            static var googleTitle: String { ls("welcome.existing.googleTitle", comment: "") }
            static var googleBody: String { ls("welcome.existing.googleBody", comment: "") }
        }

        /// Pantalla de sign-in a cuenta del Modo Nube (H4).
        enum Cloud {
            static var title: String { ls("welcome.cloud.title", comment: "") }
            static var subtitle: String { ls("welcome.cloud.subtitle", comment: "") }
            // Sesión 2 Google: subtitle del intro con provider .google + nota §13 (ambos
            // providers) + pantalla R9 de provider-mismatch (sub-first, H4).
            static var subtitleGoogle: String { ls("welcome.cloud.subtitleGoogle", comment: "") }
            static var providerNote: String { ls("welcome.cloud.providerNote", comment: "") }
            static var providerMismatchTitle: String { ls("welcome.cloud.providerMismatchTitle", comment: "") }
            /// Body con el nombre VISIBLE del método conocido ("Apple"/"Google").
            static func providerMismatchBody(_ providerName: String) -> String {
                String(format: ls("welcome.cloud.providerMismatchBody", comment: ""), providerName)
            }
            static var providerMismatchBodyGeneric: String { ls("welcome.cloud.providerMismatchBodyGeneric", comment: "") }
            static var checking: String { ls("welcome.cloud.checking", comment: "") }
            static var adopting: String { ls("welcome.cloud.adopting", comment: "") }
            static var adoptingHint: String { ls("welcome.cloud.adoptingHint", comment: "") }
            static var notFoundTitle: String { ls("welcome.cloud.notFoundTitle", comment: "") }
            static var notFoundBody: String { ls("welcome.cloud.notFoundBody", comment: "") }
            static var blockedTitle: String { ls("welcome.cloud.blockedTitle", comment: "") }
            static var blockedBody: String { ls("welcome.cloud.blockedBody", comment: "") }
            static var errorTitle: String { ls("welcome.cloud.errorTitle", comment: "") }
            static var errorBody: String { ls("welcome.cloud.errorBody", comment: "") }
            static var retry: String { ls("welcome.cloud.retry", comment: "") }
            static var waitingTitle: String { ls("welcome.cloud.waitingTitle", comment: "") }
            static var waitingBody: String { ls("welcome.cloud.waitingBody", comment: "") }
            static var continueToApp: String { ls("welcome.cloud.continueToApp", comment: "") }
            // M1 — sesión secundaria (confirmación explícita antes de armar).
            static var secondaryConfirmTitle: String { ls("welcome.cloud.secondaryConfirmTitle", comment: "") }
            static var secondaryConfirmBody: String { ls("welcome.cloud.secondaryConfirmBody", comment: "") }
            static var secondaryConfirmCta: String { ls("welcome.cloud.secondaryConfirmCta", comment: "") }
            static var secondaryHydrationBanner: String { ls("welcome.cloud.secondaryHydrationBanner", comment: "") }
        }

        enum Restore {
            static var searching: String { ls("welcome.restore.searching", comment: "") }
            static var searchingTip: String { ls("welcome.restore.searchingTip", comment: "") }
            enum Progress {
                static var connecting: String { ls("welcome.restore.progress.connecting", comment: "") }
                static var importing: String { ls("welcome.restore.progress.importing", comment: "") }
                static var completed: String { ls("welcome.restore.progress.completed", comment: "") }
                static var partial: String { ls("welcome.restore.progress.partial", comment: "") }
            }
            enum Wiped {
                static var title: String { ls("welcome.restore.wiped.title", comment: "") }
                static var body: String { ls("welcome.restore.wiped.body", comment: "") }
            }
            static func foundTitle(_ name: String) -> String {
                String(format: ls("welcome.restore.foundTitle", comment: ""), name)
            }
            static var foundTitleAnonymous: String { ls("welcome.restore.foundTitleAnonymous", comment: "") }
            static var foundBody: String { ls("welcome.restore.foundBody", comment: "") }
            static func foundAccounts(_ count: Int) -> String {
                String(format: ls("welcome.restore.foundAccounts", comment: ""), count)
            }
            static func foundTransactions(_ count: Int) -> String {
                String(format: ls("welcome.restore.foundTransactions", comment: ""), count)
            }
            static func foundBudgets(_ count: Int) -> String {
                String(format: ls("welcome.restore.foundBudgets", comment: ""), count)
            }
            static func foundGroups(_ count: Int) -> String {
                String(format: ls("welcome.restore.foundGroups", comment: ""), count)
            }
            static var continueAction: String { ls("welcome.restore.continue", comment: "") }
            static var notFoundTitle: String { ls("welcome.restore.notFoundTitle", comment: "") }
            static var notFoundBody: String { ls("welcome.restore.notFoundBody", comment: "") }
            static var startFresh: String { ls("welcome.restore.startFresh", comment: "") }
            static var retry: String { ls("welcome.restore.retry", comment: "") }
            static var errorTitle: String { ls("welcome.restore.errorTitle", comment: "") }
            static var errorBody: String { ls("welcome.restore.errorBody", comment: "") }
            static var iCloudDisabledTitle: String { ls("welcome.restore.iCloudDisabledTitle", comment: "") }
            static var iCloudDisabledBody: String { ls("welcome.restore.iCloudDisabledBody", comment: "") }
            static var openSettings: String { ls("welcome.restore.openSettings", comment: "") }
            static var startFreshConfirmTitle: String { ls("welcome.restore.startFreshConfirm.title", comment: "") }
            static var startFreshConfirmBody: String { ls("welcome.restore.startFreshConfirm.body", comment: "") }
            static var startFreshConfirmConfirm: String { ls("welcome.restore.startFreshConfirm.confirm", comment: "") }
            static var startFreshConfirmCancel: String { ls("welcome.restore.startFreshConfirm.cancel", comment: "") }
        }

        enum Invite {
            static var title: String { ls("welcome.invite.title", comment: "") }
            static var body: String { ls("welcome.invite.body", comment: "") }
            static var placeholder: String { ls("welcome.invite.placeholder", comment: "") }
            static var invalidLink: String { ls("welcome.invite.invalidLink", comment: "") }
            static var join: String { ls("welcome.invite.join", comment: "") }
            static var back: String { ls("welcome.invite.back", comment: "") }
        }

        // MARK: - Hero (A4 v3.1: pantalla de presentación pre-Chooser)

        enum Hero {
            static var title: String { ls("welcome.hero.title", comment: "") }
            static var titleAccent: String { ls("welcome.hero.titleAccent", comment: "") }
            static var subtitle: String { ls("welcome.hero.subtitle", comment: "") }
            static var cta: String { ls("welcome.hero.cta", comment: "") }
            static var trust: String { ls("welcome.hero.trust", comment: "") }

            // 8 cards animadas (Sprint 2): capture/assistant/groups/budgets/multiAndCurrencies/import/icloud/more.
            static var captureTitle: String { ls("welcome.hero.cards.capture.title", comment: "") }
            static var captureBody: String { ls("welcome.hero.cards.capture.body", comment: "") }
            static var assistantTitle: String { ls("welcome.hero.cards.assistant.title", comment: "") }
            static var assistantBody: String { ls("welcome.hero.cards.assistant.body", comment: "") }
            static var groupsTitle: String { ls("welcome.hero.cards.groups.title", comment: "") }
            static var groupsBody: String { ls("welcome.hero.cards.groups.body", comment: "") }
            static var budgetsTitle: String { ls("welcome.hero.cards.budgets.title", comment: "") }
            static var budgetsBody: String { ls("welcome.hero.cards.budgets.body", comment: "") }
            static var multiAndCurrenciesTitle: String { ls("welcome.hero.cards.multiAndCurrencies.title", comment: "") }
            static var multiAndCurrenciesBody: String { ls("welcome.hero.cards.multiAndCurrencies.body", comment: "") }
            static var importTitle: String { ls("welcome.hero.cards.import.title", comment: "") }
            static var importBody: String { ls("welcome.hero.cards.import.body", comment: "") }
            static var icloudTitle: String { ls("welcome.hero.cards.icloud.title", comment: "") }
            static var icloudBody: String { ls("welcome.hero.cards.icloud.body", comment: "") }
            static var moreTitle: String { ls("welcome.hero.cards.more.title", comment: "") }
            static var moreBody: String { ls("welcome.hero.cards.more.body", comment: "") }
        }

        // MARK: - DetectedData (A4 v3.1: alert post-Hero cuando iCloud tiene data residual)

        enum DetectedData {
            static var title: String { ls("welcome.detectedData.title", comment: "") }
            static var message: String { ls("welcome.detectedData.message", comment: "") }
            static var loadMyData: String { ls("welcome.detectedData.loadMyData", comment: "") }
            static var startFresh: String { ls("welcome.detectedData.startFresh", comment: "") }
        }

        // MARK: - OfferRestore (Parte F: oferta cargar-datos al abrir un link siendo returning)

        enum OfferRestore {
            static var title: String { ls("welcome.offerRestore.title", comment: "") }
            static var message: String { ls("welcome.offerRestore.message", comment: "") }
            static var loadData: String { ls("welcome.offerRestore.loadData", comment: "") }
            static var startFresh: String { ls("welcome.offerRestore.startFresh", comment: "") }
        }

        // MARK: - FreshStart (segunda barrera: alert al tap "Soy nuevo" si hay data residual)

        enum FreshStart {
            static var alertTitle: String { ls("welcome.freshStart.alertTitle", comment: "") }
            static var alertMessage: String { ls("welcome.freshStart.alertMessage", comment: "") }
            static var alertConfirm: String { ls("welcome.freshStart.alertConfirm", comment: "") }
        }
    }

    // MARK: - Onboarding

    enum Onboarding {
        static var welcomeTitle: String {
            ls("onboarding.welcomeTitle", comment: "")
        }
        static var welcomeSubtitle: String {
            ls("onboarding.welcomeSubtitle", comment: "")
        }
        static var nameLabel: String {
            ls("onboarding.nameLabel", comment: "")
        }
        static var namePlaceholder: String {
            ls("onboarding.namePlaceholder", comment: "")
        }
        static var currencyTitle: String {
            ls("onboarding.currencyTitle", comment: "")
        }
        static var currencySubtitle: String {
            ls("onboarding.currencySubtitle", comment: "")
        }
        static var secondaryTitle: String {
            ls("onboarding.secondaryTitle", comment: "")
        }
        static var secondarySubtitle: String {
            ls("onboarding.secondarySubtitle", comment: "")
        }
        static func secondaryHint(_ count: Int, _ max: Int) -> String {
            String(format: ls("onboarding.secondaryHint", comment: ""), count, max)
        }
        static var periodTitle: String {
            ls("onboarding.periodTitle", comment: "")
        }
        static var periodSubtitle: String {
            ls("onboarding.periodSubtitle", comment: "")
        }
        static var finish: String {
            ls("onboarding.finish", comment: "")
        }
        static var startUsingYala: String {
            ls("onboarding.startUsingYala", comment: "")
        }
        static var categoriesTitle: String {
            ls("onboarding.categoriesTitle", comment: "")
        }
        static var categoriesSubtitle: String {
            ls("onboarding.categoriesSubtitle", comment: "")
        }
        static var categoriesYes: String {
            ls("onboarding.categoriesYes", comment: "")
        }
        static var categoriesNo: String {
            ls("onboarding.categoriesNo", comment: "")
        }
        static var categoriesRecommended: String {
            ls("onboarding.categoriesRecommended", comment: "")
        }
        static var categoriesInfo: String {
            ls("onboarding.categoriesInfo", comment: "")
        }
        static var notificationsTitle: String {
            ls("onboarding.notificationsTitle", comment: "")
        }
        static var notificationsSubtitle: String {
            ls("onboarding.notificationsSubtitle", comment: "")
        }
        static var notificationsSkip: String {
            ls("onboarding.notificationsSkip", comment: "")
        }
        static var notificationsSelectAll: String {
            ls("onboarding.notificationsSelectAll", comment: "")
        }
        static var notificationsDeselectAll: String {
            ls("onboarding.notificationsDeselectAll", comment: "")
        }
        static var recommended: String {
            ls("onboarding.recommended", comment: "")
        }
        static var languageTitle: String {
            ls("onboarding.languageTitle", comment: "")
        }
        static var languageSubtitle: String {
            ls("onboarding.languageSubtitle", comment: "")
        }
        // Expenses Only Mode step
        static var expensesOnlyTitle: String {
            ls("onboarding.expensesOnlyTitle", comment: "")
        }
        static var expensesOnlySubtitle: String {
            ls("onboarding.expensesOnlySubtitle", comment: "")
        }
        static var expensesOnlyOptionAll: String {
            ls("onboarding.expensesOnlyOptionAll", comment: "")
        }
        static var expensesOnlyOptionExpenses: String {
            ls("onboarding.expensesOnlyOptionExpenses", comment: "")
        }
        static var expensesOnlyDescAll: String {
            ls("onboarding.expensesOnlyDescAll", comment: "")
        }
        static var expensesOnlyDescExpenses: String {
            ls("onboarding.expensesOnlyDescExpenses", comment: "")
        }
        // Usage mode: 3 options (Solo gastos, Día a día, Control total)
        static var usageModeExpensesOnly: String { ls("onboarding.usageMode.expensesOnly", comment: "") }
        static var usageModeExpensesOnlyQuote: String { ls("onboarding.usageMode.expensesOnly.quote", comment: "") }
        static var usageModeExpensesOnlyDesc: String { ls("onboarding.usageMode.expensesOnly.desc", comment: "") }
        static var usageModeDayToDay: String { ls("onboarding.usageMode.dayToDay", comment: "") }
        static var usageModeDayToDayQuote: String { ls("onboarding.usageMode.dayToDay.quote", comment: "") }
        static var usageModeDayToDayDesc: String { ls("onboarding.usageMode.dayToDay.desc", comment: "") }
        static var usageModeFullControl: String { ls("onboarding.usageMode.fullControl", comment: "") }
        static var usageModeFullControlQuote: String { ls("onboarding.usageMode.fullControl.quote", comment: "") }
        static var usageModeFullControlDesc: String { ls("onboarding.usageMode.fullControl.desc", comment: "") }
        static var privacyTitle: String { ls("onboarding.privacyTitle", comment: "") }
        static var privacySubtitle: String { ls("onboarding.privacySubtitle", comment: "") }
        static var privacyLocal: String { ls("onboarding.privacyLocal", comment: "") }
        static var privacyNoTracking: String { ls("onboarding.privacyNoTracking", comment: "") }
        static var privacyIcloud: String { ls("onboarding.privacyIcloud", comment: "") }
        static var privacyNoSharing: String { ls("onboarding.privacyNoSharing", comment: "") }
        static var categoriesDefault: String { ls("onboarding.categoriesDefault", comment: "") }
        static var categoriesCustom: String { ls("onboarding.categoriesCustom", comment: "") }
        static var privacyTutorialsHint: String { ls("onboarding.privacyTutorialsHint", comment: "") }
        static var tutorialsTitle: String { ls("onboarding.tutorialsTitle", comment: "") }
        static var tutorialsSubtitle: String { ls("onboarding.tutorialsSubtitle", comment: "") }
        static var tutorialsExplore: String { ls("onboarding.tutorialsExplore", comment: "") }
        static var tutorialsSettingsHint: String { ls("onboarding.tutorialsSettingsHint", comment: "") }

        // Account Setup step
        static var accountTitle: String { ls("onboarding.accountTitle", comment: "") }
        static var accountSubtitle: String { ls("onboarding.accountSubtitle", comment: "") }
        static var accountTypeLabel: String { ls("onboarding.accountTypeLabel", comment: "") }
        static var accountNameLabel: String { ls("onboarding.accountNameLabel", comment: "") }
        static var accountNamePlaceholder: String { ls("onboarding.accountNamePlaceholder", comment: "") }
        static var accountCurrencyLabel: String { ls("onboarding.accountCurrencyLabel", comment: "") }
        static var accountBalanceLabel: String { ls("onboarding.accountBalanceLabel", comment: "") }
        static var accountBalanceHint: String { ls("onboarding.accountBalanceHint", comment: "") }
        static var accountBalanceSkipHint: String { ls("onboarding.accountBalanceSkipHint", comment: "") }
        static var accountBalanceHintGeneral: String { ls("onboarding.accountBalanceHintGeneral", comment: "") }
        static var accountBalanceHintCash: String { ls("onboarding.accountBalanceHintCash", comment: "") }
        static var accountBalanceHintChecking: String { ls("onboarding.accountBalanceHintChecking", comment: "") }
        static var accountBalanceHintSavings: String { ls("onboarding.accountBalanceHintSavings", comment: "") }
        static var accountBalanceLearnMore: String { ls("onboarding.accountBalanceLearnMore", comment: "") }
        static var balanceGuideHint: String { ls("onboarding.balanceGuideHint", comment: "") }
        static var balanceManualOption: String { ls("onboarding.balanceManualOption", comment: "") }
        static var balanceManualHint: String { ls("onboarding.balanceManualHint", comment: "") }
        static var balanceGuidedIncompleteHint: String { ls("onboarding.balanceGuidedIncompleteHint", comment: "") }
        static var privacyLocalShort: String { ls("onboarding.privacyLocalShort", comment: "") }
        static var privacyNoTrackingShort: String { ls("onboarding.privacyNoTrackingShort", comment: "") }
        static var privacyIcloudShort: String { ls("onboarding.privacyIcloudShort", comment: "") }
        static var privacyNoSharingShort: String { ls("onboarding.privacyNoSharingShort", comment: "") }
        static var accountBalanceGuideTitle: String { ls("onboarding.accountBalanceGuideTitle", comment: "") }
        static var accountBalanceGuideIntro: String { ls("onboarding.accountBalanceGuideIntro", comment: "") }
        static var accountBalanceGuideGeneral: String { ls("onboarding.accountBalanceGuideGeneral", comment: "") }
        static var accountBalanceGuideCash: String { ls("onboarding.accountBalanceGuideCash", comment: "") }
        static var accountBalanceGuideChecking: String { ls("onboarding.accountBalanceGuideChecking", comment: "") }
        static var accountBalanceGuideSavings: String { ls("onboarding.accountBalanceGuideSavings", comment: "") }
        static var accountBalanceGuideClosing: String { ls("onboarding.accountBalanceGuideClosing", comment: "") }
        static var accountBalanceHintCreditCard: String { ls("onboarding.accountBalanceHintCreditCard", comment: "") }
        // Balance Calculator Sheet — instruction + mode toggle
        static var calcInstruction: String { ls("onboarding.calc.instruction", comment: "") }
        static var calcDirectSpending: String { ls("onboarding.calc.directSpending", comment: "") }
        static var calcDirectSpendingHint: String { ls("onboarding.calc.directSpendingHint", comment: "") }
        static var calcSwitchToDirect: String { ls("onboarding.calc.switchToDirect", comment: "") }
        static var calcSwitchToDetailed: String { ls("onboarding.calc.switchToDetailed", comment: "") }
        // Balance Calculator Sheet — field hints
        static var calcBankAccountsHint: String { ls("onboarding.calc.bankAccountsHint", comment: "") }
        static var calcSavingsHint: String { ls("onboarding.calc.savingsHint", comment: "") }
        static var calcCashHint: String { ls("onboarding.calc.cashHint", comment: "") }
        static var calcCreditCardSpendingHint: String { ls("onboarding.calc.creditCardSpendingHint", comment: "") }
        static var calcCreditLineHint: String { ls("onboarding.calc.creditLineHint", comment: "") }
        static var calcAvailableCreditHint: String { ls("onboarding.calc.availableCreditHint", comment: "") }
        // Balance Calculator Sheet
        static var calcTitle: String { ls("onboarding.calc.title", comment: "") }
        static var calcIntro: String { ls("onboarding.calc.intro", comment: "") }
        static var calcBankAccounts: String { ls("onboarding.calc.bankAccounts", comment: "") }
        static var calcSavings: String { ls("onboarding.calc.savings", comment: "") }
        static var calcCash: String { ls("onboarding.calc.cash", comment: "") }
        static var calcCreditCardSpending: String { ls("onboarding.calc.creditCardSpending", comment: "") }
        static var calcOptional: String { ls("onboarding.calc.optional", comment: "") }
        static var calcAvailable: String { ls("onboarding.calc.available", comment: "") }
        static var calcBalance: String { ls("onboarding.calc.balance", comment: "") }
        static var calcTipCashFlow: String { ls("onboarding.calc.tipCashFlow", comment: "") }
        static var calcTipPatrimonial: String { ls("onboarding.calc.tipPatrimonial", comment: "") }
        static var calcUseBalance: String { ls("onboarding.calc.useBalance", comment: "") }
        static var calcAdjustLater: String { ls("onboarding.calc.adjustLater", comment: "") }
        // Credit card calculator
        static var calcCreditCardTitle: String { ls("onboarding.calc.creditCard.title", comment: "") }
        static var calcCreditLine: String { ls("onboarding.calc.creditLine", comment: "") }
        static var calcAvailableCredit: String { ls("onboarding.calc.availableCredit", comment: "") }
        static var calcCurrentSpending: String { ls("onboarding.calc.currentSpending", comment: "") }
        static var calcYourBalance: String { ls("onboarding.calc.yourBalance", comment: "") }
        static var calcCreditCardTip: String { ls("onboarding.calc.creditCard.tip", comment: "") }
        // Simple account explanations (cash/checking/savings)
        // Shared expenses (patrimonial only)
        static var calcSharedExpenses: String { ls("onboarding.calc.sharedExpenses", comment: "") }
        static var calcOthersOweMe: String { ls("onboarding.calc.othersOweMe", comment: "") }
        static var calcIOwe: String { ls("onboarding.calc.iOwe", comment: "") }
        static var calcCashExplanation: String { ls("onboarding.calc.cashExplanation", comment: "") }
        static var calcCheckingExplanation: String { ls("onboarding.calc.checkingExplanation", comment: "") }
        static var calcSavingsExplanation: String { ls("onboarding.calc.savingsExplanation", comment: "") }
        static var calcBalanceLabelChecking: String { ls("onboarding.calc.balanceLabelChecking", comment: "") }
        static var calcBalanceLabelSavings: String { ls("onboarding.calc.balanceLabelSavings", comment: "") }
        static var calcBalanceLabelCash: String { ls("onboarding.calc.balanceLabelCash", comment: "") }
        static var accountImportTip: String { ls("onboarding.accountImportTip", comment: "") }
        static var accountMoreTip: String { ls("onboarding.accountMoreTip", comment: "") }

        // Purpose step (binary: solo gastos vs control)
        static var purposeTitle: String { ls("onboarding.purpose.title", comment: "") }
        static var purposeExpenses: String { ls("onboarding.purpose.expenses", comment: "") }
        static var purposeExpensesDesc: String { ls("onboarding.purpose.expensesDesc", comment: "") }
        static var purposeControl: String { ls("onboarding.purpose.control", comment: "") }
        static var purposeControlDesc: String { ls("onboarding.purpose.controlDesc", comment: "") }
        static var purposeGroups: String { ls("onboarding.purpose.groups", comment: "") }
        static var purposeGroupsDesc: String { ls("onboarding.purpose.groupsDesc", comment: "") }
        // Accounts step (binary: una cuenta vs varias)
        static var accountsTitle: String { ls("onboarding.accounts.title", comment: "") }
        static var accountsSingle: String { ls("onboarding.accounts.single", comment: "") }
        static var accountsSingleDesc: String { ls("onboarding.accounts.singleDesc", comment: "") }
        static var accountsMultiple: String { ls("onboarding.accounts.multiple", comment: "") }
        static var accountsMultipleDesc: String { ls("onboarding.accounts.multipleDesc", comment: "") }
        // Account type step (fullControl only)
        static var accountTypeTitle: String { ls("onboarding.accountType.title", comment: "") }
        static var accountTypeSubtitle: String { ls("onboarding.accountType.subtitle", comment: "") }
        static var accountTypeCheckingHint: String { ls("onboarding.accountType.checkingHint", comment: "") }
        static var accountTypeSavingsHint: String { ls("onboarding.accountType.savingsHint", comment: "") }
        static var accountTypeCreditHint: String { ls("onboarding.accountType.creditHint", comment: "") }
        static var accountTypeCashHint: String { ls("onboarding.accountType.cashHint", comment: "") }
        // Name hint
        static var nameHint: String { ls("onboarding.nameHint", comment: "") }
        // Categories subcategory view
        static var categoriesViewSubs: String { ls("onboarding.categories.viewSubs", comment: "") }
        // (v1 goal/style/accountGuided keys removed — unused in v2)
        // Currency + Name step (adaptive by account organization)
        static var currencyNameTitleSingle: String { ls("onboarding.currencyName.titleSingle", comment: "") }
        static var currencyNameSubtitleSingle: String { ls("onboarding.currencyName.subtitleSingle", comment: "") }
        static var currencyNameTitleSeparate: String { ls("onboarding.currencyName.titleSeparate", comment: "") }
        static var currencyNameSubtitleSeparate: String { ls("onboarding.currencyName.subtitleSeparate", comment: "") }
        // Currency step (Solo Grupos: solo moneda, sin cuenta)
        static var currencyNameTitleGroups: String { ls("onboarding.currencyName.titleGroups", comment: "") }
        static var currencyNameSubtitleGroups: String { ls("onboarding.currencyName.subtitleGroups", comment: "") }
        // Balance step
        static var balanceTitle: String { ls("onboarding.balance.title", comment: "") }
        static var balanceSubtitle: String { ls("onboarding.balance.subtitle", comment: "") }
        // Confirmation step
        static var confirmTitle: String { ls("onboarding.confirm.title", comment: "") }
        static var confirmAccountLabel: String { ls("onboarding.confirm.accountLabel", comment: "") }
        static var confirmCurrencyLabel: String { ls("onboarding.confirm.currencyLabel", comment: "") }
        static var confirmBalanceLabel: String { ls("onboarding.confirm.balanceLabel", comment: "") }
        static var confirmModeLabel: String { ls("onboarding.confirm.modeLabel", comment: "") }
        static var confirmMotivationExpenses: String { ls("onboarding.confirm.motivationExpenses", comment: "") }
        static var confirmMotivationDayToDay: String { ls("onboarding.confirm.motivationDayToDay", comment: "") }
        static var confirmMotivationFullControl: String { ls("onboarding.confirm.motivationFullControl", comment: "") }
        static var confirmMotivationGroups: String { ls("onboarding.confirm.motivationGroups", comment: "") }

        // Quick Budget step
        static var budgetTitle: String { ls("onboarding.budgetTitle", comment: "") }
        static var budgetSubtitle: String { ls("onboarding.budgetSubtitle", comment: "") }
        static var budgetYes: String { ls("onboarding.budgetYes", comment: "") }
        static var budgetNo: String { ls("onboarding.budgetNo", comment: "") }
        static var budgetCategoryLabel: String { ls("onboarding.budgetCategoryLabel", comment: "") }
        static var budgetAmountLabel: String { ls("onboarding.budgetAmountLabel", comment: "") }
        static var budgetAmountPlaceholder: String { ls("onboarding.budgetAmountPlaceholder", comment: "") }
        static var budgetMoreTip: String { ls("onboarding.budgetMoreTip", comment: "") }
        static var budgetPreviewLabel: String { ls("onboarding.budgetPreviewLabel", comment: "") }
    }

    // MARK: - Bulk Edit

    enum BulkEdit {
        static var currencyWarning: String {
            ls("bulkEdit.currencyWarning", comment: "")
        }
        static func editCount(_ count: Int) -> String {
            String(format: ls("bulkEdit.editCount", comment: ""), count)
        }
        static var successMessage: String {
            ls("bulkEdit.successMessage", comment: "")
        }
        static var commonTags: String {
            ls("bulkEdit.commonTags", comment: "")
        }
        static var partialTags: String {
            ls("bulkEdit.partialTags", comment: "")
        }
        static var availableTags: String {
            ls("bulkEdit.availableTags", comment: "")
        }
        static var cannotEditTransferSubcategory: String {
            ls("bulkEdit.cannotEditTransferSubcategory", comment: "")
        }
        static var cannotEditTransferAmountCrossCurrency: String {
            ls("bulkEdit.cannotEditTransferAmountCrossCurrency", comment: "")
        }
        static var cannotEditTransferAccount: String {
            ls("bulkEdit.cannotEditTransferAccount", comment: "")
        }
    }

    // MARK: - Voice Language

    enum VoiceLanguage {
        static var system: String {
            ls("voiceLanguage.system", comment: "")
        }
        static var spanish: String {
            ls("voiceLanguage.spanish", comment: "")
        }
        static var english: String {
            ls("voiceLanguage.english", comment: "")
        }
    }

    // MARK: - Inbox

    enum Inbox {
        static var title: String {
            ls("inbox.title", comment: "")
        }
        // A0-Bridge V2.0 (P1-3): CTA desde TX bridgeada read-only con draft pendiente
        static var openInbox: String { ls("inbox.openInbox", comment: "") }

        // A0-Bridge V2.0 (P1-4): sheets finalización drafts especializados
        enum GroupExpenseDraft {
            static var title: String { ls("inbox.groupExpenseDraft.title", comment: "") }
            static var assignSubcategory: String { ls("inbox.groupExpenseDraft.assignSubcategory", comment: "") }
            /// Banner explicativo (asignar categoría). Formato: %@ = nombre del grupo.
            static var banner: String { ls("inbox.groupExpenseDraft.banner", comment: "") }
        }

        enum GroupSettlementDraft {
            static var title: String { ls("inbox.groupSettlementDraft.title", comment: "") }
            static var assignAccount: String { ls("inbox.groupSettlementDraft.assignAccount", comment: "") }
            /// Banner explicativo (liquidación). Formato: %@ = nombre del grupo.
            static var banner: String { ls("inbox.groupSettlementDraft.banner", comment: "") }
        }

        // M6: sheet finalización Caso A pendiente cuenta.
        enum GroupExpenseAccountDraft {
            static var title: String { ls("inbox.groupExpenseAccountDraft.title", comment: "") }
            static var assignAccount: String { ls("inbox.groupExpenseAccountDraft.assignAccount", comment: "") }
            /// Banner explicativo (asignar cuenta). Formato: %@ = nombre del grupo.
            static var banner: String { ls("inbox.groupExpenseAccountDraft.banner", comment: "") }
        }

        // Enfoque B: sheet finalización Caso A cuando faltan cuenta + subcategoría (match falla).
        enum GroupExpenseAccountSubcategoryDraft {
            static var title: String { ls("inbox.groupExpenseAccountSubcategoryDraft.title", comment: "") }
            /// Banner explicativo (asignar cuenta + subcategoría). Formato: %@ = nombre del grupo.
            static var banner: String { ls("inbox.groupExpenseAccountSubcategoryDraft.banner", comment: "") }
        }

        enum GroupDraft {
            static var finalize: String { ls("inbox.groupDraft.finalize", comment: "") }
            static var fromGroup: String { ls("inbox.groupDraft.fromGroup", comment: "") }
        }
        static var pending: String {
            ls("inbox.pending", comment: "")
        }
        static var archived: String {
            ls("inbox.archived", comment: "")
        }
        static var noDescription: String {
            ls("inbox.noDescription", comment: "")
        }
        static var noAmount: String {
            ls("inbox.noAmount", comment: "")
        }
        static var missingLabel: String {
            ls("inbox.missingLabel", comment: "")
        }
        static var needsAccount: String {
            ls("inbox.needsAccount", comment: "")
        }
        static var needsSubcategory: String {
            ls("inbox.needsSubcategory", comment: "")
        }
        static var approve: String {
            ls("inbox.approve", comment: "")
        }
        static var delete: String {
            ls("inbox.delete", comment: "")
        }
        static var noPending: String {
            ls("inbox.noPending", comment: "")
        }
        static var noPendingDescription: String {
            ls("inbox.noPendingDescription", comment: "")
        }
        static var bulkHint: String {
            ls("inbox.bulkHint", comment: "")
        }
        static var newTag: String {
            ls("inbox.newTag", comment: "")
        }
        static var noArchived: String {
            ls("inbox.noArchived", comment: "")
        }
        static var noArchivedDescription: String {
            ls("inbox.noArchivedDescription", comment: "")
        }
        static func selectedCount(_ count: Int) -> String {
            String(format: ls("inbox.selectedCount", comment: ""), count)
        }
        static var editDraft: String {
            ls("inbox.editDraft", comment: "")
        }
        static var cannotApprove: String {
            ls("inbox.cannotApprove", comment: "")
        }
        static var sourceVoice: String {
            ls("inbox.sourceVoice", comment: "")
        }
        static var sourceEmail: String {
            ls("inbox.sourceEmail", comment: "")
        }
        static var sourceScreenshot: String {
            ls("inbox.sourceScreenshot", comment: "")
        }
        static var sourceScreenshotList: String {
            ls("inbox.sourceScreenshotList", comment: "")
        }
        static var sourceReceipt: String {
            ls("inbox.sourceReceipt", comment: "")
        }
        static var sourceScheduledPayment: String {
            ls("inbox.sourceScheduledPayment", comment: "")
        }
        static var sourceSubscription: String {
            ls("inbox.sourceSubscription", comment: "")
        }
        static var sourceApplePay: String {
            ls("inbox.sourceApplePay", comment: "")
        }
        static var sourceAutomation: String {
            ls("inbox.sourceAutomation", comment: "")
        }
        static var sourceSiri: String {
            ls("inbox.sourceSiri", comment: "")
        }
        static var sourceGroupExpense: String {
            ls("inbox.sourceGroupExpense", comment: "")
        }
        static var sourceGroupSettlement: String {
            ls("inbox.sourceGroupSettlement", comment: "")
        }
        static var sourceGroupScheduledExpense: String {
            ls("inbox.sourceGroupScheduledExpense", comment: "")
        }
        static var sourceManual: String {
            ls("inbox.sourceManual", comment: "")
        }
        /// "Esta transacción se elimina solo desde el grupo origen."
        static var groupDraftCannotDelete: String {
            ls("inbox.groupDraftCannotDelete", comment: "")
        }
        static var errorNoAccount: String {
            ls("inbox.errorNoAccount", comment: "")
        }
        static var errorNoAmount: String {
            ls("inbox.errorNoAmount", comment: "")
        }
        static var errorNoSubcategory: String {
            ls("inbox.errorNoSubcategory", comment: "")
        }
        static var errorArchivedAccount: String {
            ls("inbox.errorArchivedAccount", comment: "")
        }
        static var errorFutureDate: String {
            ls("inbox.errorFutureDate", comment: "")
        }
        static var errorGroupExpenseGone: String {
            ls("inbox.errorGroupExpenseGone", comment: "")
        }
        static var duplicateWarningTitle: String {
            ls("inbox.duplicateWarningTitle", comment: "")
        }
        static var duplicateWarningMessage: String {
            ls("inbox.duplicateWarningMessage", comment: "")
        }
        static var createAnyway: String {
            ls("inbox.createAnyway", comment: "")
        }
        static func deleteConfirmMessage(_ count: Int) -> String {
            String(format: ls("inbox.deleteConfirmMessage", comment: ""), count)
        }
        static func approveableCount(_ count: Int, _ total: Int) -> String {
            String(format: ls("inbox.approveableCount", comment: ""), count, total)
        }
        static var saveLater: String {
            ls("inbox.saveLater", comment: "")
        }
        static var convertToShared: String {
            ls("inbox.convertToShared", comment: "")
        }
        static var deleteTitle: String {
            ls("inbox.deleteTitle", comment: "")
        }
        static var deleteMessage: String {
            ls("inbox.deleteMessage", comment: "")
        }
        static var reject: String {
            ls("inbox.reject", comment: "")
        }
        static var approveAll: String {
            ls("inbox.approveAll", comment: "")
        }
        static var returnToPending: String {
            ls("inbox.returnToPending", comment: "")
        }
        static var discardChangesTitle: String {
            ls("inbox.discardChangesTitle", comment: "")
        }
        static var discardChanges: String {
            ls("inbox.discardChanges", comment: "")
        }
        static var keepEditing: String {
            ls("inbox.keepEditing", comment: "")
        }
        static var discardChangesMessage: String {
            ls("inbox.discardChangesMessage", comment: "")
        }
        static var approveSuccess: String {
            ls("inbox.approveSuccess", comment: "")
        }
        static var approveNext: String {
            ls("inbox.approveNext", comment: "")
        }
        static var transactionCreated: String {
            ls("inbox.transactionCreated", comment: "")
        }
        static var transactionsCreated: String {
            ls("inbox.transactionsCreated", comment: "")
        }
        static var viewInRecords: String {
            ls("inbox.viewInRecords", comment: "")
        }
        static var backToInbox: String {
            ls("inbox.backToInbox", comment: "")
        }

        // MARK: Alert Modal

        enum Alert {
            enum Title {
                static var scheduled: String {
                    ls("inbox.alert.title.scheduled", comment: "")
                }
                static var subscriptions: String {
                    ls("inbox.alert.title.subscriptions", comment: "")
                }
                static var automations: String {
                    ls("inbox.alert.title.automations", comment: "")
                }
                static var mixed: String {
                    ls("inbox.alert.title.mixed", comment: "")
                }
            }

            enum Message {
                static func scheduled(_ count: Int) -> String {
                    String(format: ls("inbox.alert.message.scheduled", comment: ""), count)
                }
                static func subscriptions(_ count: Int) -> String {
                    String(format: ls("inbox.alert.message.subscriptions", comment: ""), count)
                }
                static func automations(_ count: Int) -> String {
                    String(format: ls("inbox.alert.message.automations", comment: ""), count)
                }

                enum Mixed {
                    static func scheduled(_ count: Int) -> String {
                        String(format: ls("inbox.alert.message.mixed.scheduled", comment: ""), count)
                    }
                    static func subscriptions(_ count: Int) -> String {
                        String(format: ls("inbox.alert.message.mixed.subscriptions", comment: ""), count)
                    }
                    static func automations(_ count: Int) -> String {
                        String(format: ls("inbox.alert.message.mixed.automations", comment: ""), count)
                    }
                    static var connector: String {
                        ls("inbox.alert.message.mixed.connector", comment: "")
                    }
                }
            }
        }

        static func pendingBadge(_ count: Int) -> String {
            String(format: ls("inbox.pendingBadge", comment: ""), count)
        }
        static var subtitleAllDone: String {
            ls("inbox.subtitleAllDone", comment: "")
        }
        static var subtitleOnePending: String {
            ls("inbox.subtitleOnePending", comment: "")
        }
        static func subtitleMultiplePending(_ count: Int) -> String {
            String(format: ls("inbox.subtitleMultiplePending", comment: ""), count)
        }
    }

    // MARK: - Voice Input

    enum Voice {
        static var title: String {
            ls("voice.title", comment: "")
        }
        static var recording: String {
            ls("voice.recording", comment: "")
        }
        static var recorded: String {
            ls("voice.recorded", comment: "")
        }
        static var pleaseWait: String {
            ls("voice.pleaseWait", comment: "")
        }
        static var tapToRecord: String {
            ls("voice.tapToRecord", comment: "")
        }
        static var youCanSay: String {
            ls("voice.youCanSay", comment: "")
        }
        static var hintTypeExample: String {
            ls("voice.hintTypeExample", comment: "")
        }
        static var hintAmountExample: String {
            ls("voice.hintAmountExample", comment: "")
        }
        static var hintSubcategoryExample: String {
            ls("voice.hintSubcategoryExample", comment: "")
        }
        static var hintMerchantExample: String {
            ls("voice.hintMerchantExample", comment: "")
        }
        static var hintTagExample: String {
            ls("voice.hintTagExample", comment: "")
        }
        static var hintDateExample: String {
            ls("voice.hintDateExample", comment: "")
        }
        static var exampleLabel: String {
            ls("voice.exampleLabel", comment: "")
        }
        static var example1: String {
            ls("voice.example1", comment: "")
        }
        static var example2: String {
            ls("voice.example2", comment: "")
        }
        static var example3: String {
            ls("voice.example3", comment: "")
        }
        static var processingAudio: String {
            ls("voice.processingAudio", comment: "")
        }
        static var analyzing: String {
            ls("voice.analyzing", comment: "")
        }
        static var parsing: String {
            ls("voice.parsing", comment: "")
        }
        static var saving: String {
            ls("voice.saving", comment: "")
        }
        static var errorNoAmount: String {
            ls("voice.errorNoAmount", comment: "")
        }
        static var errorNoApiKey: String {
            ls("voice.errorNoApiKey", comment: "")
        }
        static var errorNoConnection: String {
            ls("voice.errorNoConnection", comment: "")
        }
        static var errorMicPermission: String {
            ls("voice.errorMicPermission", comment: "")
        }
        static var errorSaveFailed: String {
            ls("voice.errorSaveFailed", comment: "")
        }
        static var openSettings: String {
            ls("voice.openSettings", comment: "")
        }
        static var tryImage: String {
            ls("voice.tryImage", comment: "")
        }
    }

    // MARK: - Image Input

    enum Image {
        static var title: String {
            ls("image.title", comment: "")
        }
        static var selectTitle: String {
            ls("image.selectTitle", comment: "")
        }
        static var selectSubtitle: String {
            ls("image.selectSubtitle", comment: "")
        }
        static var selectButton: String {
            ls("image.selectButton", comment: "")
        }
        static var processing: String {
            ls("image.processing", comment: "")
        }
        static var processingSubtitle: String {
            ls("image.processingSubtitle", comment: "")
        }
        static var errorTitle: String {
            ls("image.errorTitle", comment: "")
        }
        static var errorLoad: String {
            ls("image.errorLoad", comment: "")
        }
        static var errorNoData: String {
            ls("image.errorNoData", comment: "")
        }
        static var errorUnrecognized: String {
            ls("image.errorUnrecognized", comment: "")
        }
        static var errorGeneric: String {
            ls("image.errorGeneric", comment: "")
        }
        static var errorPhotoPermission: String {
            ls("image.errorPhotoPermission", comment: "")
        }
        static var errorCorrupted: String {
            ls("image.errorCorrupted", comment: "")
        }
        static var errorSaveFailed: String {
            ls("image.errorSaveFailed", comment: "")
        }
        static var errorNoApiKey: String {
            ls("image.errorNoApiKey", comment: "")
        }
        static var errorNoConnection: String {
            ls("image.errorNoConnection", comment: "")
        }
        static var openSettings: String {
            ls("image.openSettings", comment: "")
        }
        static var transactionDetected: String {
            ls("image.transactionDetected", comment: "")
        }
        static var transactionsDetectedCount: String {
            ls("image.transactionsDetectedCount", comment: "")
        }
        static var reviewDraft: String {
            ls("image.reviewDraft", comment: "")
        }
        static var transactionsDetected: String {
            ls("image.transactionsDetected", comment: "")
        }
        static var goToInbox: String {
            ls("image.goToInbox", comment: "")
        }
        static func transactionsDetectedMessage(_ count: Int) -> String {
            String(format: ls("image.transactionsDetectedMessage", comment: ""), count)
        }
        static func analyzingIn(_ seconds: Int) -> String {
            String(format: ls("image.analyzingIn", comment: ""), seconds)
        }
        static func imagesSelected(_ count: Int) -> String {
            String(format: ls("image.imagesSelected", comment: ""), count)
        }
        static var youCanUpload: String {
            ls("image.youCanUpload", comment: "")
        }
        static var hintReceipts: String {
            ls("image.hintReceipts", comment: "")
        }
        static var hintBankScreenshots: String {
            ls("image.hintBankScreenshots", comment: "")
        }
        static var hintRestaurantTickets: String {
            ls("image.hintRestaurantTickets", comment: "")
        }
        static var hintStatements: String {
            ls("image.hintStatements", comment: "")
        }
        static var hintPaymentProofs: String {
            ls("image.hintPaymentProofs", comment: "")
        }
        static var hintMultiple: String {
            ls("image.hintMultiple", comment: "")
        }
        static var exampleLabel: String {
            ls("image.exampleLabel", comment: "")
        }
        static var example1: String {
            ls("image.example1", comment: "")
        }
        static var example2: String {
            ls("image.example2", comment: "")
        }
        static var example3: String {
            ls("image.example3", comment: "")
        }
    }

    // MARK: - Face ID protection guide

    enum FaceIDGuide {
        static var title: String { ls("faceIDGuide.title", comment: "") }
        static var subtitle: String { ls("faceIDGuide.subtitle", comment: "") }
        static var step1Title: String { ls("faceIDGuide.step1Title", comment: "") }
        static var step1Detail: String { ls("faceIDGuide.step1Detail", comment: "") }
        static var step2Title: String { ls("faceIDGuide.step2Title", comment: "") }
        static var step2Detail: String { ls("faceIDGuide.step2Detail", comment: "") }
        static var step3Title: String { ls("faceIDGuide.step3Title", comment: "") }
        static var step3Detail: String { ls("faceIDGuide.step3Detail", comment: "") }
    }

    // MARK: - Subscription
    enum Subscription {
        static var title: String { ls("subscription.title", comment: "") }
        static var paywallTitle: String { ls("subscription.paywallTitle", comment: "") }
        static var paywallSubtitle: String { ls("subscription.paywallSubtitle", comment: "") }
        static var subscribe: String { ls("subscription.subscribe", comment: "") }
        static var processing: String { ls("subscription.processing", comment: "") }
        static var restore: String { ls("subscription.restore", comment: "") }
        static var planMonthly: String { ls("subscription.planMonthly", comment: "") }
        static var planYearly: String { ls("subscription.planYearly", comment: "") }
        static var perYear: String { ls("subscription.perYear", comment: "") }
        static func perMonth(_ price: String) -> String {
            String(format: ls("subscription.perMonth", comment: ""), price)
        }
        static func saveBadge(_ percent: Int) -> String {
            String(format: ls("subscription.saveBadge", comment: ""), percent)
        }
        static var featureVoice: String { ls("subscription.feature.voice", comment: "") }
        static var featureImage: String { ls("subscription.feature.image", comment: "") }
        static var featureReports: String { ls("subscription.feature.reports", comment: "") }
        static var featureCurrencies: String { ls("subscription.feature.currencies", comment: "") }
        static var featureThemes: String { ls("subscription.feature.themes", comment: "") }
        static var featureExport: String { ls("subscription.feature.export", comment: "") }
        static var featureAIAssistant: String { ls("subscription.feature.aiAssistant", comment: "") }
        static var legalFooter: String { ls("subscription.legalFooter", comment: "") }
        static var termsOfUseLink: String { ls("subscription.termsOfUseLink", comment: "") }
        static var privacyPolicyLink: String { ls("subscription.privacyPolicyLink", comment: "") }
        static var errorTitle: String { ls("subscription.errorTitle", comment: "") }
        static var activeTitle: String { ls("subscription.activeTitle", comment: "") }
        static var activeSubtitle: String { ls("subscription.activeSubtitle", comment: "") }
        static var currentPlan: String { ls("subscription.currentPlan", comment: "") }
        static var renewsOn: String { ls("subscription.renewsOn", comment: "") }
        static var manageInAppStore: String { ls("subscription.manageInAppStore", comment: "") }
        static var startFreeTrial: String { ls("subscription.startFreeTrial", comment: "") }
        static func trialThenPrice(_ days: String, _ price: String) -> String {
            String(format: ls("subscription.trialThenPrice", comment: ""), days, price)
        }
    }

    // MARK: - Trial Offer
    enum TrialOffer {
        static var title: String { ls("subscription.trialOffer.title", comment: "") }
        static var subtitle: String { ls("subscription.trialOffer.subtitle", comment: "") }
        static var startTrial: String { ls("subscription.trialOffer.startTrial", comment: "") }
        static var maybeLater: String { ls("subscription.trialOffer.maybeLater", comment: "") }
    }

    enum Tutorials {
        static var subtitle: String { ls("tutorials.subtitle", comment: "") }
        static var stepsCount: String { ls("tutorials.stepsCount", comment: "") }
        static var next: String { ls("tutorials.next", comment: "") }
        static var previous: String { ls("tutorials.previous", comment: "") }
        static var done: String { ls("tutorials.done", comment: "") }
        static var start: String { ls("tutorials.start", comment: "") }
        static var understood: String { ls("tutorials.understood", comment: "") }
        static var nextTutorial: String { ls("tutorials.nextTutorial", comment: "") }
        static func stepLabel(_ number: Int) -> String { String(format: ls("tutorials.stepLabel %d", comment: ""), number) }

        // Categories
        static var categoryGettingStarted: String { ls("tutorials.category.gettingStarted", comment: "") }
        static var categoryDailyUse: String { ls("tutorials.category.dailyUse", comment: "") }
        static var categoryPersonalization: String { ls("tutorials.category.personalization", comment: "") }
        static var categoryAdvanced: String { ls("tutorials.category.advanced", comment: "") }
        static var categoryPowerUser: String { ls("tutorials.category.powerUser", comment: "") }

        // 1. createAccount (3 steps)
        static var createAccountTitle: String { ls("tutorials.createAccount.title", comment: "") }
        static var createAccountIntroTitle: String { ls("tutorials.createAccount.intro.title", comment: "") }
        static var createAccountIntroDesc: String { ls("tutorials.createAccount.intro.desc", comment: "") }
        static var createAccountStep0Title: String { ls("tutorials.createAccount.step0.title", comment: "") }
        static var createAccountStep1Title: String { ls("tutorials.createAccount.step1.title", comment: "") }
        static var createAccountStep2Title: String { ls("tutorials.createAccount.step2.title", comment: "") }
        static var createAccountCompletionTitle: String { ls("tutorials.createAccount.completion.title", comment: "") }
        static var createAccountCompletionDesc: String { ls("tutorials.createAccount.completion.desc", comment: "") }

        // 2. createCategories (4 steps)
        static var createCategoriesTitle: String { ls("tutorials.createCategories.title", comment: "") }
        static var createCategoriesIntroTitle: String { ls("tutorials.createCategories.intro.title", comment: "") }
        static var createCategoriesIntroDesc: String { ls("tutorials.createCategories.intro.desc", comment: "") }
        static var createCategoriesStep0Title: String { ls("tutorials.createCategories.step0.title", comment: "") }
        static var createCategoriesStep1Title: String { ls("tutorials.createCategories.step1.title", comment: "") }
        static var createCategoriesStep2Title: String { ls("tutorials.createCategories.step2.title", comment: "") }
        static var createCategoriesStep3Title: String { ls("tutorials.createCategories.step3.title", comment: "") }
        static var createCategoriesCompletionTitle: String { ls("tutorials.createCategories.completion.title", comment: "") }
        static var createCategoriesCompletionDesc: String { ls("tutorials.createCategories.completion.desc", comment: "") }

        // 3. createTags (2 steps)
        static var createTagsTitle: String { ls("tutorials.createTags.title", comment: "") }
        static var createTagsIntroTitle: String { ls("tutorials.createTags.intro.title", comment: "") }
        static var createTagsIntroDesc: String { ls("tutorials.createTags.intro.desc", comment: "") }
        static var createTagsStep0Title: String { ls("tutorials.createTags.step0.title", comment: "") }
        static var createTagsStep1Title: String { ls("tutorials.createTags.step1.title", comment: "") }
        static var createTagsCompletionTitle: String { ls("tutorials.createTags.completion.title", comment: "") }
        static var createTagsCompletionDesc: String { ls("tutorials.createTags.completion.desc", comment: "") }

        // 4. createRecord (4 steps)
        static var createRecordTitle: String { ls("tutorials.createRecord.title", comment: "") }
        static var createRecordIntroTitle: String { ls("tutorials.createRecord.intro.title", comment: "") }
        static var createRecordIntroDesc: String { ls("tutorials.createRecord.intro.desc", comment: "") }
        static var createRecordStep0Title: String { ls("tutorials.createRecord.step0.title", comment: "") }
        static var createRecordStep1Title: String { ls("tutorials.createRecord.step1.title", comment: "") }
        static var createRecordStep2Title: String { ls("tutorials.createRecord.step2.title", comment: "") }
        static var createRecordStep3Title: String { ls("tutorials.createRecord.step3.title", comment: "") }
        static var createRecordCompletionTitle: String { ls("tutorials.createRecord.completion.title", comment: "") }
        static var createRecordCompletionDesc: String { ls("tutorials.createRecord.completion.desc", comment: "") }

        // 5. importData (2 steps)
        static var importDataTitle: String { ls("tutorials.importData.title", comment: "") }
        static var importDataIntroTitle: String { ls("tutorials.importData.intro.title", comment: "") }
        static var importDataIntroDesc: String { ls("tutorials.importData.intro.desc", comment: "") }
        static var importDataStep0Title: String { ls("tutorials.importData.step0.title", comment: "") }
        static var importDataStep1Title: String { ls("tutorials.importData.step1.title", comment: "") }
        static var importDataCompletionTitle: String { ls("tutorials.importData.completion.title", comment: "") }
        static var importDataCompletionDesc: String { ls("tutorials.importData.completion.desc", comment: "") }

        // 6. createBudgets (4 steps)
        static var createBudgetsTitle: String { ls("tutorials.createBudgets.title", comment: "") }
        static var createBudgetsIntroTitle: String { ls("tutorials.createBudgets.intro.title", comment: "") }
        static var createBudgetsIntroDesc: String { ls("tutorials.createBudgets.intro.desc", comment: "") }
        static var createBudgetsStep0Title: String { ls("tutorials.createBudgets.step0.title", comment: "") }
        static var createBudgetsStep1Title: String { ls("tutorials.createBudgets.step1.title", comment: "") }
        static var createBudgetsStep2Title: String { ls("tutorials.createBudgets.step2.title", comment: "") }
        static var createBudgetsStep3Title: String { ls("tutorials.createBudgets.step3.title", comment: "") }
        static var createBudgetsCompletionTitle: String { ls("tutorials.createBudgets.completion.title", comment: "") }
        static var createBudgetsCompletionDesc: String { ls("tutorials.createBudgets.completion.desc", comment: "") }

        // 7. createScheduledPayments (5 steps)
        static var createScheduledPaymentsTitle: String { ls("tutorials.createScheduledPayments.title", comment: "") }
        static var createScheduledPaymentsIntroTitle: String { ls("tutorials.createScheduledPayments.intro.title", comment: "") }
        static var createScheduledPaymentsIntroDesc: String { ls("tutorials.createScheduledPayments.intro.desc", comment: "") }
        static var createScheduledPaymentsStep0Title: String { ls("tutorials.createScheduledPayments.step0.title", comment: "") }
        static var createScheduledPaymentsStep1Title: String { ls("tutorials.createScheduledPayments.step1.title", comment: "") }
        static var createScheduledPaymentsStep2Title: String { ls("tutorials.createScheduledPayments.step2.title", comment: "") }
        static var createScheduledPaymentsStep3Title: String { ls("tutorials.createScheduledPayments.step3.title", comment: "") }
        static var createScheduledPaymentsStep4Title: String { ls("tutorials.createScheduledPayments.step4.title", comment: "") }
        static var createScheduledPaymentsCompletionTitle: String { ls("tutorials.createScheduledPayments.completion.title", comment: "") }
        static var createScheduledPaymentsCompletionDesc: String { ls("tutorials.createScheduledPayments.completion.desc", comment: "") }

        // 8. createFavorites (2 steps)
        static var createFavoritesTitle: String { ls("tutorials.createFavorites.title", comment: "") }
        static var createFavoritesIntroTitle: String { ls("tutorials.createFavorites.intro.title", comment: "") }
        static var createFavoritesIntroDesc: String { ls("tutorials.createFavorites.intro.desc", comment: "") }
        static var createFavoritesStep0Title: String { ls("tutorials.createFavorites.step0.title", comment: "") }
        static var createFavoritesStep1Title: String { ls("tutorials.createFavorites.step1.title", comment: "") }
        static var createFavoritesCompletionTitle: String { ls("tutorials.createFavorites.completion.title", comment: "") }
        static var createFavoritesCompletionDesc: String { ls("tutorials.createFavorites.completion.desc", comment: "") }

        // 9. editPanel (3 steps)
        static var editPanelTitle: String { ls("tutorials.editPanel.title", comment: "") }
        static var editPanelIntroTitle: String { ls("tutorials.editPanel.intro.title", comment: "") }
        static var editPanelIntroDesc: String { ls("tutorials.editPanel.intro.desc", comment: "") }
        static var editPanelStep0Title: String { ls("tutorials.editPanel.step0.title", comment: "") }
        static var editPanelStep1Title: String { ls("tutorials.editPanel.step1.title", comment: "") }
        static var editPanelStep2Title: String { ls("tutorials.editPanel.step2.title", comment: "") }
        static var editPanelCompletionTitle: String { ls("tutorials.editPanel.completion.title", comment: "") }
        static var editPanelCompletionDesc: String { ls("tutorials.editPanel.completion.desc", comment: "") }

        // 10. panelFiltering (5 steps)
        static var panelFilteringTitle: String { ls("tutorials.panelFiltering.title", comment: "") }
        static var panelFilteringIntroTitle: String { ls("tutorials.panelFiltering.intro.title", comment: "") }
        static var panelFilteringIntroDesc: String { ls("tutorials.panelFiltering.intro.desc", comment: "") }
        static var panelFilteringStep0Title: String { ls("tutorials.panelFiltering.step0.title", comment: "") }
        static var panelFilteringStep1Title: String { ls("tutorials.panelFiltering.step1.title", comment: "") }
        static var panelFilteringStep2Title: String { ls("tutorials.panelFiltering.step2.title", comment: "") }
        static var panelFilteringStep3Title: String { ls("tutorials.panelFiltering.step3.title", comment: "") }
        static var panelFilteringStep4Title: String { ls("tutorials.panelFiltering.step4.title", comment: "") }
        static var panelFilteringCompletionTitle: String { ls("tutorials.panelFiltering.completion.title", comment: "") }
        static var panelFilteringCompletionDesc: String { ls("tutorials.panelFiltering.completion.desc", comment: "") }

        // 11. inboxApproval (4 steps)
        static var inboxApprovalTitle: String { ls("tutorials.inboxApproval.title", comment: "") }
        static var inboxApprovalIntroTitle: String { ls("tutorials.inboxApproval.intro.title", comment: "") }
        static var inboxApprovalIntroDesc: String { ls("tutorials.inboxApproval.intro.desc", comment: "") }
        static var inboxApprovalStep0Title: String { ls("tutorials.inboxApproval.step0.title", comment: "") }
        static var inboxApprovalStep1Title: String { ls("tutorials.inboxApproval.step1.title", comment: "") }
        static var inboxApprovalStep2Title: String { ls("tutorials.inboxApproval.step2.title", comment: "") }
        static var inboxApprovalStep3Title: String { ls("tutorials.inboxApproval.step3.title", comment: "") }
        static var inboxApprovalCompletionTitle: String { ls("tutorials.inboxApproval.completion.title", comment: "") }
        static var inboxApprovalCompletionDesc: String { ls("tutorials.inboxApproval.completion.desc", comment: "") }

        // 12. applePay (4 steps)
        static var applePayTitle: String { ls("tutorials.applePay.title", comment: "") }
        static var applePayIntroTitle: String { ls("tutorials.applePay.intro.title", comment: "") }
        static var applePayIntroDesc: String { ls("tutorials.applePay.intro.desc", comment: "") }
        static var applePayStep0Title: String { ls("tutorials.applePay.step0.title", comment: "") }
        static var applePayStep1Title: String { ls("tutorials.applePay.step1.title", comment: "") }
        static var applePayStep2Title: String { ls("tutorials.applePay.step2.title", comment: "") }
        static var applePayStep3Title: String { ls("tutorials.applePay.step3.title", comment: "") }
        // Step Descriptions
        static var createAccountStep0Desc: String { ls("tutorials.createAccount.step0.desc", comment: "") }
        static var createAccountStep1Desc: String { ls("tutorials.createAccount.step1.desc", comment: "") }
        static var createAccountStep2Desc: String { ls("tutorials.createAccount.step2.desc", comment: "") }
        static var createCategoriesStep0Desc: String { ls("tutorials.createCategories.step0.desc", comment: "") }
        static var createCategoriesStep1Desc: String { ls("tutorials.createCategories.step1.desc", comment: "") }
        static var createCategoriesStep2Desc: String { ls("tutorials.createCategories.step2.desc", comment: "") }
        static var createCategoriesStep3Desc: String { ls("tutorials.createCategories.step3.desc", comment: "") }
        static var createTagsStep0Desc: String { ls("tutorials.createTags.step0.desc", comment: "") }
        static var createTagsStep1Desc: String { ls("tutorials.createTags.step1.desc", comment: "") }
        static var createRecordStep0Desc: String { ls("tutorials.createRecord.step0.desc", comment: "") }
        static var createRecordStep1Desc: String { ls("tutorials.createRecord.step1.desc", comment: "") }
        static var createRecordStep2Desc: String { ls("tutorials.createRecord.step2.desc", comment: "") }
        static var createRecordStep3Desc: String { ls("tutorials.createRecord.step3.desc", comment: "") }
        static var importDataStep0Desc: String { ls("tutorials.importData.step0.desc", comment: "") }
        static var importDataStep1Desc: String { ls("tutorials.importData.step1.desc", comment: "") }
        static var createBudgetsStep0Desc: String { ls("tutorials.createBudgets.step0.desc", comment: "") }
        static var createBudgetsStep1Desc: String { ls("tutorials.createBudgets.step1.desc", comment: "") }
        static var createBudgetsStep2Desc: String { ls("tutorials.createBudgets.step2.desc", comment: "") }
        static var createBudgetsStep3Desc: String { ls("tutorials.createBudgets.step3.desc", comment: "") }
        static var createScheduledPaymentsStep0Desc: String { ls("tutorials.createScheduledPayments.step0.desc", comment: "") }
        static var createScheduledPaymentsStep1Desc: String { ls("tutorials.createScheduledPayments.step1.desc", comment: "") }
        static var createScheduledPaymentsStep2Desc: String { ls("tutorials.createScheduledPayments.step2.desc", comment: "") }
        static var createScheduledPaymentsStep3Desc: String { ls("tutorials.createScheduledPayments.step3.desc", comment: "") }
        static var createScheduledPaymentsStep4Desc: String { ls("tutorials.createScheduledPayments.step4.desc", comment: "") }
        static var createFavoritesStep0Desc: String { ls("tutorials.createFavorites.step0.desc", comment: "") }
        static var createFavoritesStep1Desc: String { ls("tutorials.createFavorites.step1.desc", comment: "") }
        static var editPanelStep0Desc: String { ls("tutorials.editPanel.step0.desc", comment: "") }
        static var editPanelStep1Desc: String { ls("tutorials.editPanel.step1.desc", comment: "") }
        static var editPanelStep2Desc: String { ls("tutorials.editPanel.step2.desc", comment: "") }
        static var panelFilteringStep0Desc: String { ls("tutorials.panelFiltering.step0.desc", comment: "") }
        static var panelFilteringStep1Desc: String { ls("tutorials.panelFiltering.step1.desc", comment: "") }
        static var panelFilteringStep2Desc: String { ls("tutorials.panelFiltering.step2.desc", comment: "") }
        static var panelFilteringStep3Desc: String { ls("tutorials.panelFiltering.step3.desc", comment: "") }
        static var panelFilteringStep4Desc: String { ls("tutorials.panelFiltering.step4.desc", comment: "") }
        static var inboxApprovalStep0Desc: String { ls("tutorials.inboxApproval.step0.desc", comment: "") }
        static var inboxApprovalStep1Desc: String { ls("tutorials.inboxApproval.step1.desc", comment: "") }
        static var inboxApprovalStep2Desc: String { ls("tutorials.inboxApproval.step2.desc", comment: "") }
        static var inboxApprovalStep3Desc: String { ls("tutorials.inboxApproval.step3.desc", comment: "") }
        static var applePayStep0Desc: String { ls("tutorials.applePay.step0.desc", comment: "") }
        static var applePayStep1Desc: String { ls("tutorials.applePay.step1.desc", comment: "") }
        static var applePayStep2Desc: String { ls("tutorials.applePay.step2.desc", comment: "") }
        static var applePayStep3Desc: String { ls("tutorials.applePay.step3.desc", comment: "") }
        static var applePayCompletionTitle: String { ls("tutorials.applePay.completion.title", comment: "") }
        static var applePayCompletionDesc: String { ls("tutorials.applePay.completion.desc", comment: "") }
    }

    enum FAQ {
        static var subtitle: String { ls("faq.subtitle", comment: "") }
        static var sectionGeneral: String { ls("faq.section.general", comment: "") }
        static var sectionData: String { ls("faq.section.data", comment: "") }
        static var sectionPro: String { ls("faq.section.pro", comment: "") }
        static var whatIsYalaQ: String { ls("faq.whatIsYala.q", comment: "") }
        static var whatIsYalaA: String { ls("faq.whatIsYala.a", comment: "") }
        static var howToRecordQ: String { ls("faq.howToRecord.q", comment: "") }
        static var howToRecordA: String { ls("faq.howToRecord.a", comment: "") }
        static var multiCurrencyQ: String { ls("faq.multiCurrency.q", comment: "") }
        static var multiCurrencyA: String { ls("faq.multiCurrency.a", comment: "") }
        static var changeCategoryQ: String { ls("faq.changeCategory.q", comment: "") }
        static var changeCategoryA: String { ls("faq.changeCategory.a", comment: "") }
        static var importDataQ: String { ls("faq.importData.q", comment: "") }
        static var importDataA: String { ls("faq.importData.a", comment: "") }
        static var exportDataQ: String { ls("faq.exportData.q", comment: "") }
        static var exportDataA: String { ls("faq.exportData.a", comment: "") }
        static var deleteDataQ: String { ls("faq.deleteData.q", comment: "") }
        static var deleteDataA: String { ls("faq.deleteData.a", comment: "") }
        static var whatIsProQ: String { ls("faq.whatIsPro.q", comment: "") }
        static var whatIsProA: String { ls("faq.whatIsPro.a", comment: "") }
        static var cancelSubQ: String { ls("faq.cancelSub.q", comment: "") }
        static var cancelSubA: String { ls("faq.cancelSub.a", comment: "") }
    }

    // MARK: - Notifications

    enum Notifications {
        static var title: String { ls("notifications.title", comment: "") }
        static var addNew: String { ls("notifications.addNew", comment: "") }
        static var edit: String { ls("notifications.edit", comment: "") }
        static var delete: String { ls("notifications.delete", comment: "") }
        static var deleteConfirm: String { ls("notifications.deleteConfirm", comment: "") }
        static var permissionRequired: String { ls("notifications.permissionRequired", comment: "") }
        static var permissionMessage: String { ls("notifications.permissionMessage", comment: "") }
        static var openSettings: String { ls("notifications.openSettings", comment: "") }

        // Form fields
        static var name: String { ls("notifications.name", comment: "") }
        static var namePlaceholder: String { ls("notifications.namePlaceholder", comment: "") }
        static var text: String { ls("notifications.text", comment: "") }
        static var textPlaceholder: String { ls("notifications.textPlaceholder", comment: "") }
        static var time: String { ls("notifications.time", comment: "") }
        static var active: String { ls("notifications.active", comment: "") }

        // Report data types
        static var dataBalance: String { ls("notifications.data.balance", comment: "") }
        static var dataExpenses: String { ls("notifications.data.expenses", comment: "") }
        static var dataIncome: String { ls("notifications.data.income", comment: "") }
        static var dataTopCategory: String { ls("notifications.data.topCategory", comment: "") }
        static var selectData: String { ls("notifications.selectData", comment: "") }

        // Day preferences
        static var daySunday: String { ls("notifications.day.sunday", comment: "") }
        static var dayMonday: String { ls("notifications.day.monday", comment: "") }
        static var dayLastOfMonth: String { ls("notifications.day.lastOfMonth", comment: "") }
        static var dayFirstOfMonth: String { ls("notifications.day.firstOfMonth", comment: "") }
        static var selectDay: String { ls("notifications.selectDay", comment: "") }
        static var allDays: String { ls("notifications.allDays", comment: "") }
        static var selectWeekdays: String { ls("notifications.selectWeekdays", comment: "") }

        // Default notification names (Brand Voice friendly)
        static var endOfDayName: String { ls("notifications.endOfDay.name", comment: "") }
        static var endOfDayText: String { ls("notifications.endOfDay.text", comment: "") }
        static var lunchTimeName: String { ls("notifications.lunchTime.name", comment: "") }
        static var lunchTimeText: String { ls("notifications.lunchTime.text", comment: "") }

        // Reports
        static var dailyReportName: String { ls("notifications.dailyReport.name", comment: "") }
        static var weeklyReportName: String { ls("notifications.weeklyReport.name", comment: "") }
        static var monthlyReportName: String { ls("notifications.monthlyReport.name", comment: "") }

        // Report hints (shown in list)
        static func dailyReportHint(_ time: String, _ data: String) -> String {
            String(format: ls("notifications.dailyReport.hint", comment: ""), time, data)
        }
        static func weeklyReportHint(_ data: String, _ day: String) -> String {
            String(format: ls("notifications.weeklyReport.hint", comment: ""), data, day)
        }
        static func monthlyReportHint(_ data: String, _ day: String) -> String {
            String(format: ls("notifications.monthlyReport.hint", comment: ""), data, day)
        }

        // System notifications
        static var scheduledPaymentsName: String { ls("notifications.scheduledPayments.name", comment: "") }
        static var scheduledPaymentsHint: String { ls("notifications.scheduledPayments.hint", comment: "") }

        // Groups
        static var groupsName: String { ls("notifications.groups.name", comment: "") }
        static var groupsHint: String { ls("notifications.groups.hint", comment: "") }

        enum Group {
            static func newExpense(_ member: String, _ desc: String, _ myShare: String) -> String {
                String(format: ls("notifications.groups.newExpense", comment: ""), member, desc, myShare)
            }
            static func newExpenseNoDesc(_ member: String, _ myShare: String) -> String {
                String(format: ls("notifications.groups.newExpenseNoDesc", comment: ""), member, myShare)
            }
            static func modifiedExpense(_ member: String, _ desc: String, _ myShare: String) -> String {
                String(format: ls("notifications.groups.modifiedExpense", comment: ""), member, desc, myShare)
            }
            static func settlement(_ member: String, _ amount: String) -> String {
                String(format: ls("notifications.groups.settlement", comment: ""), member, amount)
            }
            static func newMember(_ member: String) -> String {
                String(format: ls("notifications.groups.newMember", comment: ""), member)
            }
            static func multipleChanges(_ count: Int) -> String {
                String(format: ls("notifications.groups.multipleChanges", comment: ""), count)
            }
            static var fallbackGroup: String { ls("notifications.groups.fallbackGroup", comment: "") }
            static var fallbackMember: String { ls("notifications.groups.fallbackMember", comment: "") }
        }


        // Empty state
        static var emptyTitle: String { ls("notifications.empty.title", comment: "") }
        static var emptyMessage: String { ls("notifications.empty.message", comment: "") }

        // Test notification
        static var testNotification: String { ls("notifications.testNotification", comment: "") }

        // Test report samples (by period)
        static var testBalanceDaily: String { ls("notifications.testReport.balance.daily", comment: "") }
        static var testBalanceWeekly: String { ls("notifications.testReport.balance.weekly", comment: "") }
        static var testBalanceMonthly: String { ls("notifications.testReport.balance.monthly", comment: "") }
        static var testExpensesDaily: String { ls("notifications.testReport.expenses.daily", comment: "") }
        static var testExpensesWeekly: String { ls("notifications.testReport.expenses.weekly", comment: "") }
        static var testExpensesMonthly: String { ls("notifications.testReport.expenses.monthly", comment: "") }
        static var testIncomeDaily: String { ls("notifications.testReport.income.daily", comment: "") }
        static var testIncomeWeekly: String { ls("notifications.testReport.income.weekly", comment: "") }
        static var testIncomeMonthly: String { ls("notifications.testReport.income.monthly", comment: "") }
        static var testTopCategoryDaily: String { ls("notifications.testReport.topCategory.daily", comment: "") }
        static var testTopCategoryWeekly: String { ls("notifications.testReport.topCategory.weekly", comment: "") }
        static var testTopCategoryMonthly: String { ls("notifications.testReport.topCategory.monthly", comment: "") }
        static var testScheduledPayment: String { ls("notifications.testReport.scheduledPayment", comment: "") }

        // Section headers
        static var sectionReminders: String { ls("notifications.section.reminders", comment: "") }
        static var sectionReports: String { ls("notifications.section.reports", comment: "") }
        static var sectionSystem: String { ls("notifications.section.system", comment: "") }
        static var sectionCustom: String { ls("notifications.section.custom", comment: "") }

        // Budget alerts
        static var budgetAlertsTitle: String { ls("notifications.budgetAlerts.title", comment: "") }
        static var budgetAlertsHint: String { ls("notifications.budgetAlerts.hint", comment: "") }

        // MARK: - Scheduled Payment Notifications (personalized)

        enum ScheduledPayment {
            /// "Hoy vence: %@ por %@" (name, amount)
            static func dueToday(_ name: String, _ amount: String) -> String {
                String(format: ls("notifications.scheduledPayment.dueToday", comment: ""), name, amount)
            }

            /// "En %d día(s) vence: %@ por %@" (days, name, amount)
            static func dueSoon(_ days: Int, _ name: String, _ amount: String) -> String {
                String(format: ls("notifications.scheduledPayment.dueSoon", comment: ""), days, name, amount)
            }

            /// "Pago vencido: %@ por %@" (name, amount)
            static func overdue(_ name: String, _ amount: String) -> String {
                String(format: ls("notifications.scheduledPayment.overdue", comment: ""), name, amount)
            }

            /// "Hoy recibes: %@ de %@" (amount, name)
            static func dueTodayIncome(_ amount: String, _ name: String) -> String {
                String(format: ls("notifications.scheduledPayment.dueToday.income", comment: ""), amount, name)
            }

            /// "En %d día(s) recibes: %@ de %@" (days, amount, name)
            static func dueSoonIncome(_ days: Int, _ amount: String, _ name: String) -> String {
                String(format: ls("notifications.scheduledPayment.dueSoon.income", comment: ""), days, amount, name)
            }

            /// "Ingreso pendiente: %@ de %@" (amount, name)
            static func overdueIncome(_ amount: String, _ name: String) -> String {
                String(format: ls("notifications.scheduledPayment.overdue.income", comment: ""), amount, name)
            }
        }

        // MARK: - Report Notifications (with real data)

        /// Dynamic report text: "notifications.report.{dataType}.{period}" with one format argument
        static func reportData(_ dataType: ReportDataType, period: String, value: String) -> String {
            String(format: ls("notifications.report.\(dataType.rawValue).\(period)", comment: ""), value)
        }

        // Empty state messages
        static var emptyExpensesDaily: String { ls("notifications.report.empty.expenses.daily", comment: "") }
        static var emptyExpensesWeekly: String { ls("notifications.report.empty.expenses.weekly", comment: "") }
        static var emptyExpensesMonthly: String { ls("notifications.report.empty.expenses.monthly", comment: "") }
        static var emptyIncome: String { ls("notifications.report.empty.income", comment: "") }
        static var emptyTopCategory: String { ls("notifications.report.empty.topCategory", comment: "") }
    }

    // MARK: - Notification Primer

    enum NotificationPrimer {
        static var title: String { ls("notificationPrimer.title", comment: "") }
        static var benefit1: String { ls("notificationPrimer.benefit1", comment: "") }
        static var benefit2: String { ls("notificationPrimer.benefit2", comment: "") }
        static var benefit3: String { ls("notificationPrimer.benefit3", comment: "") }
        static var accept: String { ls("notificationPrimer.accept", comment: "") }
        static var reject: String { ls("notificationPrimer.reject", comment: "") }
        static var hint: String { ls("notificationPrimer.hint", comment: "") }
    }

    // MARK: - What's New

    enum WhatsNew {
        static var title: String { ls("whatsNew.title", comment: "") }
        static func subtitle(_ version: String) -> String {
            String(format: ls("whatsNew.subtitle", comment: ""), version)
        }
        static var continueButton: String { ls("whatsNew.continue", comment: "") }

        // v1.1 features
        static var v11ResumenTitle: String { ls("whatsNew.v11.resumen.title", comment: "") }
        static var v11ResumenDescription: String { ls("whatsNew.v11.resumen.description", comment: "") }
        static var v11BudgetDetailTitle: String { ls("whatsNew.v11.budgetDetail.title", comment: "") }
        static var v11BudgetDetailDescription: String { ls("whatsNew.v11.budgetDetail.description", comment: "") }
        static var v11ExcludeTitle: String { ls("whatsNew.v11.exclude.title", comment: "") }
        static var v11ExcludeDescription: String { ls("whatsNew.v11.exclude.description", comment: "") }

        // v1.2 features
        static var v12CashFlowTitle: String { ls("whatsNew.v12.cashFlow.title", comment: "") }
        static var v12CashFlowDescription: String { ls("whatsNew.v12.cashFlow.description", comment: "") }
        static var v12ComparativeTitle: String { ls("whatsNew.v12.comparative.title", comment: "") }
        static var v12ComparativeDescription: String { ls("whatsNew.v12.comparative.description", comment: "") }
        static var v12ThemesTitle: String { ls("whatsNew.v12.themes.title", comment: "") }
        static var v12ThemesDescription: String { ls("whatsNew.v12.themes.description", comment: "") }
        static var v12ScheduledTitle: String { ls("whatsNew.v12.scheduled.title", comment: "") }
        static var v12ScheduledDescription: String { ls("whatsNew.v12.scheduled.description", comment: "") }
        static var v12MoreForYouTitle: String { ls("whatsNew.v12.moreForYou.title", comment: "") }
        static var v12MoreForYouDescription: String { ls("whatsNew.v12.moreForYou.description", comment: "") }

        // v2.0 features
        static var v20GroupsTitle: String { ls("whatsNew.v20.groups.title", comment: "") }
        static var v20GroupsDescription: String { ls("whatsNew.v20.groups.description", comment: "") }
        static var v20AITitle: String { ls("whatsNew.v20.ai.title", comment: "") }
        static var v20AIDescription: String { ls("whatsNew.v20.ai.description", comment: "") }
        static var v20RedesignTitle: String { ls("whatsNew.v20.redesign.title", comment: "") }
        static var v20RedesignDescription: String { ls("whatsNew.v20.redesign.description", comment: "") }
    }

    // MARK: - App Update

    enum AppUpdate {
        static var title: String { ls("appUpdate.title", comment: "") }
        static func message(_ version: String) -> String {
            String(format: ls("appUpdate.message", comment: ""), version)
        }
        static var updateButton: String { ls("appUpdate.updateButton", comment: "") }
        static var dismissButton: String { ls("appUpdate.dismissButton", comment: "") }
    }

    // MARK: - Weekday

    enum Weekday {
        static var shortSunday: String { ls("weekday.short.sunday", comment: "") }
        static var shortMonday: String { ls("weekday.short.monday", comment: "") }
        static var shortTuesday: String { ls("weekday.short.tuesday", comment: "") }
        static var shortWednesday: String { ls("weekday.short.wednesday", comment: "") }
        static var shortThursday: String { ls("weekday.short.thursday", comment: "") }
        static var shortFriday: String { ls("weekday.short.friday", comment: "") }
        static var shortSaturday: String { ls("weekday.short.saturday", comment: "") }
    }

    // MARK: - iCloud Sync

    enum iCloud {
        static var title: String { ls("icloud.title", comment: "") }
        static var description: String { ls("icloud.description", comment: "") }
        static var privacyNote: String { ls("icloud.privacyNote", comment: "") }
        static var statusSynced: String { ls("icloud.statusSynced", comment: "") }
        static var statusSyncing: String { ls("icloud.statusSyncing", comment: "") }
        static var statusNoAccount: String { ls("icloud.statusNoAccount", comment: "") }
        static var statusError: String { ls("icloud.statusError", comment: "") }
        static func lastSync(_ time: String) -> String {
            String(format: ls("icloud.lastSync", comment: ""), time)
        }
        static var noAccountWarning: String { ls("icloud.noAccountWarning", comment: "") }
        static var syncingData: String { ls("icloud.syncingData", comment: "") }
        static var syncingDescription: String { ls("icloud.syncingDescription", comment: "") }
        static var syncingSkip: String { ls("icloud.syncing.skip", comment: "") }
        static var dataFoundTitle: String { ls("icloud.dataFoundTitle", comment: "") }
        static var dataFoundMessage: String { ls("icloud.dataFoundMessage", comment: "") }
        static var dataFoundAction: String { ls("icloud.dataFoundAction", comment: "") }
        static var remoteOnboardingCompleted: String { ls("icloud.remoteOnboardingCompleted", comment: "") }
        static var remoteRestoreCompleted: String { ls("icloud.remoteRestoreCompleted", comment: "") }
        enum SyncIndicator {
            static var failed: String { ls("icloud.syncIndicator.failed", comment: "") }
            static func stalled(_ days: Int) -> String {
                String(format: ls("icloud.syncIndicator.stalled", comment: ""), days)
            }
            static var hint: String { ls("icloud.syncIndicator.hint", comment: "") }
        }
        enum Detail {
            static func upToDate(_ relative: String) -> String {
                String(format: ls("icloud.detail.upToDate", comment: ""), relative)
            }
            static var errorTitle: String { ls("icloud.detail.errorTitle", comment: "") }
            static var errorMessage: String { ls("icloud.detail.errorMessage", comment: "") }
            static func stalledTitle(_ days: Int) -> String {
                String(format: ls("icloud.detail.stalledTitle", comment: ""), days)
            }
            static var stalledMessage: String { ls("icloud.detail.stalledMessage", comment: "") }
            static func technicalCode(_ code: String) -> String {
                String(format: ls("icloud.detail.technicalCode", comment: ""), code)
            }
            enum CTA {
                static var retry: String { ls("icloud.detail.cta.retry", comment: "") }
                static var diagnose: String { ls("icloud.detail.cta.diagnose", comment: "") }
                static var viewTechnical: String { ls("icloud.detail.cta.viewTechnical", comment: "") }
            }
        }
        static var remoteWipeTitle: String { ls("icloud.remoteWipe.title", comment: "") }
        static var remoteWipeMessage: String { ls("icloud.remoteWipe.message", comment: "") }
        static var remoteWipeConfirm: String { ls("icloud.remoteWipe.confirm", comment: "") }
        static var remoteWipeCancel: String { ls("icloud.remoteWipe.cancel", comment: "") }
        static var forceSyncButton: String { ls("icloud.forceSync.button", comment: "") }
        static var forceSyncDescription: String { ls("icloud.forceSync.description", comment: "") }
        static var forceSyncOfflineNote: String { ls("icloud.forceSync.offlineNote", comment: "") }
        static var mismatchTitle: String { ls("icloud.mismatch.title", comment: "") }
        static var mismatchMessage: String { ls("icloud.mismatch.message", comment: "") }
        static var mismatchAction: String { ls("icloud.mismatch.action", comment: "") }
    }

    // MARK: - Modo Nube (I14): almacenamiento / migración / consentimiento

    enum Storage {
        static var title: String { ls("storage.title", comment: "") }
        static var waitingForLeader: String { ls("storage.waitingForLeader", comment: "") }

        enum Status {
            static var icloudTitle: String { ls("storage.status.icloudTitle", comment: "") }
            static var icloudBody: String { ls("storage.status.icloudBody", comment: "") }
            static var cloudTitle: String { ls("storage.status.cloudTitle", comment: "") }
            static var cloudBody: String { ls("storage.status.cloudBody", comment: "") }
        }

        enum Migrate {
            static var title: String { ls("storage.migrate.title", comment: "") }
            static var body: String { ls("storage.migrate.body", comment: "") }
            static var button: String { ls("storage.migrate.button", comment: "") }
            static var previewButton: String { ls("storage.migrate.previewButton", comment: "") }
            /// "%1$lld movimientos · %2$lld categorías · %3$lld cuentas · %4$lld presupuestos".
            static func previewResult(_ tx: Int, _ cat: Int, _ acc: Int, _ budgets: Int) -> String {
                String(format: ls("storage.migrate.previewResult", comment: ""), tx, cat, acc, budgets)
            }
        }

        enum Adopt {
            static var title: String { ls("storage.adopt.title", comment: "") }
            static var body: String { ls("storage.adopt.body", comment: "") }
            static var button: String { ls("storage.adopt.button", comment: "") }
        }

        enum Revert {
            static var title: String { ls("storage.revert.title", comment: "") }
            static var body: String { ls("storage.revert.body", comment: "") }
            static var button: String { ls("storage.revert.button", comment: "") }
            static var ineligible: String { ls("storage.revert.ineligible", comment: "") }
        }

        enum Sync {
            static var title: String { ls("storage.sync.title", comment: "") }
            static var upToDate: String { ls("storage.sync.upToDate", comment: "") }
            static func needsSignIn(_ count: Int) -> String {
                String(format: ls("storage.sync.needsSignIn", comment: ""), count)
            }
            static var signInButton: String { ls("storage.sync.signInButton", comment: "") }
        }

        enum Progress {
            static var migrating: String { ls("storage.progress.migrating", comment: "") }
            static var reverting: String { ls("storage.progress.reverting", comment: "") }
            static var resume: String { ls("storage.progress.resume", comment: "") }
            static var retry: String { ls("storage.progress.retry", comment: "") }
        }

        enum Relaunch {
            static var title: String { ls("storage.relaunch.title", comment: "") }
            static var body: String { ls("storage.relaunch.body", comment: "") }
            /// Cover terminal con auto-exit en background (sign-out/entrada secundaria):
            /// basta ir al inicio — la app se cierra sola. `body` (compartido con la
            /// relaunchCard de migración/reversa, que NO auto-exita) queda intacto.
            static var bodyAutoExit: String { ls("storage.relaunch.bodyAutoExit", comment: "") }
        }

        enum Failed {
            static var migration: String { ls("storage.failed.migration", comment: "") }
            static var reverse: String { ls("storage.failed.reverse", comment: "") }
        }

        enum Confirm {
            static var migrateTitle: String { ls("storage.confirm.migrateTitle", comment: "") }
            static var migrateBody: String { ls("storage.confirm.migrateBody", comment: "") }
            static var migrateContinue: String { ls("storage.confirm.migrateContinue", comment: "") }
            static var migrate2Title: String { ls("storage.confirm.migrate2Title", comment: "") }
            static var migrate2Body: String { ls("storage.confirm.migrate2Body", comment: "") }
            static var migrate2Confirm: String { ls("storage.confirm.migrate2Confirm", comment: "") }
            static var revertTitle: String { ls("storage.confirm.revertTitle", comment: "") }
            static var revertBody: String { ls("storage.confirm.revertBody", comment: "") }
            static var revertContinue: String { ls("storage.confirm.revertContinue", comment: "") }
            static var revert2Title: String { ls("storage.confirm.revert2Title", comment: "") }
            static var revert2Body: String { ls("storage.confirm.revert2Body", comment: "") }
            static var revert2Confirm: String { ls("storage.confirm.revert2Confirm", comment: "") }
        }

        enum Errors {
            static var title: String { ls("storage.errors.title", comment: "") }
            static var generic: String { ls("storage.errors.generic", comment: "") }
            static var signIn: String { ls("storage.errors.signIn", comment: "") }
        }

        enum Consent {
            static var title: String { ls("storage.consent.title", comment: "") }
            static var point1: String { ls("storage.consent.point1", comment: "") }
            static var point2: String { ls("storage.consent.point2", comment: "") }
            static var point3: String { ls("storage.consent.point3", comment: "") }
            static var point4: String { ls("storage.consent.point4", comment: "") }
            static var point5: String { ls("storage.consent.point5", comment: "") }
            static var point6: String { ls("storage.consent.point6", comment: "") }
            static var point7: String { ls("storage.consent.point7", comment: "") }
            static var accept: String { ls("storage.consent.accept", comment: "") }
            static var privacyLink: String { ls("storage.consent.privacyLink", comment: "") }
        }
    }

    // MARK: - Shortcut Notifications

    enum Shortcut {
        /// Dialog del intent Siri cuando algunos items no se entendieron.
        /// La key lleva los placeholders en el CONTENIDO (`%1$lld de %2$lld`), no en el
        /// nombre — por eso requiere `String(format:)` con `Int64` y no `String(localized:)`.
        static func successPartial(_ recorded: Int, _ total: Int) -> String {
            String(format: ls("shortcut.siriNatural.success.partial", comment: ""), Int64(recorded), Int64(total))
        }

        enum Notification {
            static var title: String { ls("shortcut.notification.title", comment: "") }
            static var expense: String { ls("shortcut.notification.expense", comment: "") }
            static var income: String { ls("shortcut.notification.income", comment: "") }
            static var errorTitle: String { ls("shortcut.notification.errorTitle", comment: "") }
            static var errorBody: String { ls("shortcut.notification.errorBody", comment: "") }
            static func body(_ type: String, _ amount: String, _ note: String) -> String {
                String(format: ls("shortcut.notification.body", comment: ""), type, amount, note)
            }
        }
    }

    // MARK: - Tips

    enum Tips {
        static var subtitle: String { ls("tips.subtitle", comment: "") }

        enum Section {
            static var quickEntry: String { ls("tips.section.quickEntry", comment: "") }
            static var organize: String { ls("tips.section.organize", comment: "") }
            static var advanced: String { ls("tips.section.advanced", comment: "") }
        }

        enum Voice {
            static var title: String { ls("tips.voice.title", comment: "") }
            static var detail: String { ls("tips.voice.detail", comment: "") }
        }

        enum Favorites {
            static var title: String { ls("tips.favorites.title", comment: "") }
            static var detail: String { ls("tips.favorites.detail", comment: "") }
        }

        enum Budgets {
            static var title: String { ls("tips.budgets.title", comment: "") }
            static var detail: String { ls("tips.budgets.detail", comment: "") }
        }

        enum Tags {
            static var title: String { ls("tips.tags.title", comment: "") }
            static var detail: String { ls("tips.tags.detail", comment: "") }
        }

        enum Filters {
            static var title: String { ls("tips.filters.title", comment: "") }
            static var detail: String { ls("tips.filters.detail", comment: "") }
        }

        enum Export {
            static var title: String { ls("tips.export.title", comment: "") }
            static var detail: String { ls("tips.export.detail", comment: "") }
        }

        enum Siri {
            static var title: String { ls("tips.siri.title", comment: "") }
            static var detail: String { ls("tips.siri.detail", comment: "") }
            static var close: String { ls("tips.siri.close", comment: "") }
        }
    }

    // MARK: - TipKit

    enum TipKit {
        static var skip: String { ls("tipkit.skip", comment: "") }
        static var next: String { ls("tipkit.next", comment: "") }
        static var done: String { ls("tipkit.done", comment: "") }
        // TipKit standalone tips
        static var comparison: String { ls("tipkit.comparison.title", comment: "") }
        static var comparisonMessage: String { ls("tipkit.comparison.message", comment: "") }
        // AI Charts tips
        static var aiChartsPro: String { ls("tipkit.aiCharts.pro.title", comment: "") }
        static var aiChartsProMessage: String { ls("tipkit.aiCharts.pro.message", comment: "") }
        static var aiChartsFree: String { ls("tipkit.aiCharts.free.title", comment: "") }
        static var aiChartsFreeMessage: String { ls("tipkit.aiCharts.free.message", comment: "") }
        // Grupo D: Settings
        static var settingsAccounts: String { ls("tipkit.settings.accounts.title", comment: "") }
        static var settingsAccountsMessage: String { ls("tipkit.settings.accounts.message", comment: "") }
        static var settingsCategories: String { ls("tipkit.settings.categories.title", comment: "") }
        static var settingsCategoriesMessage: String { ls("tipkit.settings.categories.message", comment: "") }
        static var settingsTags: String { ls("tipkit.settings.tags.title", comment: "") }
        static var settingsTagsMessage: String { ls("tipkit.settings.tags.message", comment: "") }
        static var settingsBudgets: String { ls("tipkit.settings.budgets.title", comment: "") }
        static var settingsBudgetsMessage: String { ls("tipkit.settings.budgets.message", comment: "") }
        static var settingsPlanned: String { ls("tipkit.settings.planned.title", comment: "") }
        static var settingsPlannedMessage: String { ls("tipkit.settings.planned.message", comment: "") }
        static var settingsPersonalization: String { ls("tipkit.settings.personalization.title", comment: "") }
        static var settingsPersonalizationMessage: String { ls("tipkit.settings.personalization.message", comment: "") }
        static var settingsAppIcon: String { ls("tipkit.settingsAppIcon.title", comment: "") }
        static var settingsAppIconMessage: String { ls("tipkit.settingsAppIcon.message", comment: "") }
        static var settingsTheme: String { ls("tipkit.settingsTheme.title", comment: "") }
        static var settingsThemeMessage: String { ls("tipkit.settingsTheme.message", comment: "") }
        static var settingsTutorials: String { ls("tipkit.settings.tutorials.title", comment: "") }
        static var settingsTutorialsMessage: String { ls("tipkit.settings.tutorials.message", comment: "") }
        // Cash Flow Setup Tour
        static var cfSetupBanner: String { ls("tipkit.cfSetup.banner.title", comment: "") }
        static var cfSetupBannerMessage: String { ls("tipkit.cfSetup.banner.message", comment: "") }
        static var cfSetupLine: String { ls("tipkit.cfSetup.line.title", comment: "") }
        static var cfSetupLineMessage: String { ls("tipkit.cfSetup.line.message", comment: "") }
        static var cfSetupStarting: String { ls("tipkit.cfSetup.starting.title", comment: "") }
        static var cfSetupStartingMessage: String { ls("tipkit.cfSetup.starting.message", comment: "") }
        static var cfSetupCreate: String { ls("tipkit.cfSetup.create.title", comment: "") }
        static var cfSetupCreateMessage: String { ls("tipkit.cfSetup.create.message", comment: "") }
        // Cash Flow Table Tour
        static var cfTableCell: String { ls("tipkit.cfTable.cell.title", comment: "") }
        static var cfTableCellMessage: String { ls("tipkit.cfTable.cell.message", comment: "") }
        static var cfTableAvailable: String { ls("tipkit.cfTable.available.title", comment: "") }
        static var cfTableAvailableMessage: String { ls("tipkit.cfTable.available.message", comment: "") }
        static var cfTableAdd: String { ls("tipkit.cfTable.add.title", comment: "") }
        static var cfTableAddMessage: String { ls("tipkit.cfTable.add.message", comment: "") }

        // Pro Tour (post-subscription)
        static var proVoiceInputTitle: String { ls("tipkit.pro.voiceInput.title", comment: "") }
        static var proVoiceInputMessage: String { ls("tipkit.pro.voiceInput.message", comment: "") }
        static var proImageInputTitle: String { ls("tipkit.pro.imageInput.title", comment: "") }
        static var proImageInputMessage: String { ls("tipkit.pro.imageInput.message", comment: "") }
        static var proSmartInsightsTitle: String { ls("tipkit.pro.smartInsights.title", comment: "") }
        static var proSmartInsightsMessage: String { ls("tipkit.pro.smartInsights.message", comment: "") }
        static var proExportExtendedTitle: String { ls("tipkit.pro.exportExtended.title", comment: "") }
        static var proExportExtendedMessage: String { ls("tipkit.pro.exportExtended.message", comment: "") }
        static var proPremiumIconsTitle: String { ls("tipkit.pro.premiumIcons.title", comment: "") }
        static var proPremiumIconsMessage: String { ls("tipkit.pro.premiumIcons.message", comment: "") }
        static var proProThemesTitle: String { ls("tipkit.pro.proThemes.title", comment: "") }
        static var proProThemesMessage: String { ls("tipkit.pro.proThemes.message", comment: "") }
        static var proFabTitle: String { ls("tipkit.pro.fab.title", comment: "") }
        static var proFabMessage: String { ls("tipkit.pro.fab.message", comment: "") }
        static var proChatFabTitle: String { ls("tipkit.pro.chatFab.title", comment: "") }
        static var proChatFabMessage: String { ls("tipkit.pro.chatFab.message", comment: "") }
        static var proAiSummaryTitle: String { ls("tipkit.pro.aiSummary.title", comment: "") }
        static var proAiSummaryMessage: String { ls("tipkit.pro.aiSummary.message", comment: "") }
    }

    // MARK: - Dev Seed (DEBUG only)

    enum DevSeed {
        // Accounts
        static var accountMain: String { ls("devseed.accountMain", comment: "") }
        static var accountSavings: String { ls("devseed.accountSavings", comment: "") }
        // Tags
        static var tagWork: String { ls("devseed.tagWork", comment: "") }
        static var tagVacation: String { ls("devseed.tagVacation", comment: "") }
        static var tagShared: String { ls("devseed.tagShared", comment: "") }
        static var tagUrgent: String { ls("devseed.tagUrgent", comment: "") }
        static var tagFixed: String { ls("devseed.tagFixed", comment: "") }
        // Budgets
        static var budgetEatingOut: String { ls("devseed.budgetEatingOut", comment: "") }
        static var budgetMobility: String { ls("devseed.budgetMobility", comment: "") }
        static var budgetFriendsOutings: String { ls("devseed.budgetFriendsOutings", comment: "") }
        static var budgetPersonalCare: String { ls("devseed.budgetPersonalCare", comment: "") }
        static var budgetHomeEssentials: String { ls("devseed.budgetHomeEssentials", comment: "") }
        static var budgetPet: String { ls("devseed.budgetPet", comment: "") }
        // Scheduled Payments
        static var spGym: String { ls("devseed.spGym", comment: "") }
        static var spRent: String { ls("devseed.spRent", comment: "") }
        static var spPhone: String { ls("devseed.spPhone", comment: "") }
        static var spInsurance: String { ls("devseed.spInsurance", comment: "") }
        static var spInternet: String { ls("devseed.spInternet", comment: "") }
        // Notes — Fixed monthly
        static var noteSalary: String { ls("devseed.noteSalary", comment: "") }
        static var noteGymMonthly: String { ls("devseed.noteGymMonthly", comment: "") }
        static var noteRent: String { ls("devseed.noteRent", comment: "") }
        static var notePhonePlan: String { ls("devseed.notePhonePlan", comment: "") }
        static var noteElectricity: String { ls("devseed.noteElectricity", comment: "") }
        static var noteWater: String { ls("devseed.noteWater", comment: "") }
        static var noteElectricityWater: String { ls("devseed.noteElectricityWater", comment: "") }
        static var noteInternetFiber: String { ls("devseed.noteInternetFiber", comment: "") }
        static var noteInsuranceMonthly: String { ls("devseed.noteInsuranceMonthly", comment: "") }
        // Notes — Supermarket
        static var noteSupermarket1: String { ls("devseed.noteSupermarket1", comment: "") }
        static var noteSupermarket2: String { ls("devseed.noteSupermarket2", comment: "") }
        static var noteSupermarket3: String { ls("devseed.noteSupermarket3", comment: "") }
        static var noteSupermarket4: String { ls("devseed.noteSupermarket4", comment: "") }
        static var noteSupermarket5: String { ls("devseed.noteSupermarket5", comment: "") }
        // Notes — Restaurant
        static var noteLunch: String { ls("devseed.noteLunch", comment: "") }
        static var noteDinner: String { ls("devseed.noteDinner", comment: "") }
        static var noteBrunch: String { ls("devseed.noteBrunch", comment: "") }
        static var noteMealWithFriends: String { ls("devseed.noteMealWithFriends", comment: "") }
        // Notes — Delivery
        static var noteDelivery1: String { ls("devseed.noteDelivery1", comment: "") }
        static var noteDelivery2: String { ls("devseed.noteDelivery2", comment: "") }
        static var noteDeliveryFood: String { ls("devseed.noteDeliveryFood", comment: "") }
        // Notes — Transport
        static var noteTaxi: String { ls("devseed.noteTaxi", comment: "") }
        static var noteBus: String { ls("devseed.noteBus", comment: "") }
        // Notes — Travel
        static var noteHotel: String { ls("devseed.noteHotel", comment: "") }
        static var noteFlight: String { ls("devseed.noteFlight", comment: "") }
        static var noteTour: String { ls("devseed.noteTour", comment: "") }
        static var noteExcursion: String { ls("devseed.noteExcursion", comment: "") }
        // Notes — Fuel
        static var noteGasStation: String { ls("devseed.noteGasStation", comment: "") }
        static var noteGasoline: String { ls("devseed.noteGasoline", comment: "") }
        static var noteFuel: String { ls("devseed.noteFuel", comment: "") }
        // Notes — Maintenance
        static var noteRepair: String { ls("devseed.noteRepair", comment: "") }
        static var noteCleaning: String { ls("devseed.noteCleaning", comment: "") }
        static var notePlumber: String { ls("devseed.notePlumber", comment: "") }
        static var noteElectrician: String { ls("devseed.noteElectrician", comment: "") }
        // Notes — Freelance
        static var noteFreelance: String { ls("devseed.noteFreelance", comment: "") }
        static var noteConsulting: String { ls("devseed.noteConsulting", comment: "") }
        static var noteSideProject: String { ls("devseed.noteSideProject", comment: "") }
        // Notes — Transfers
        static func noteTransferTo(_ account: String) -> String {
            String(format: ls("devseed.noteTransferTo", comment: ""), account)
        }
        static func noteTransferFrom(_ account: String) -> String {
            String(format: ls("devseed.noteTransferFrom", comment: ""), account)
        }
        // Step labels
        static var stepCategories: String { ls("devseed.stepCategories", comment: "") }
        static var stepAccounts: String { ls("devseed.stepAccounts", comment: "") }
        static var stepTags: String { ls("devseed.stepTags", comment: "") }
        static var stepExchangeRates: String { ls("devseed.stepExchangeRates", comment: "") }
        static var stepBudgets: String { ls("devseed.stepBudgets", comment: "") }
        static var stepScheduledPayments: String { ls("devseed.stepScheduledPayments", comment: "") }
        static var stepSavingBase: String { ls("devseed.stepSavingBase", comment: "") }
        static var stepTransactions: String { ls("devseed.stepTransactions", comment: "") }
        static var stepInitialBalances: String { ls("devseed.stepInitialBalances", comment: "") }
        static var stepSaving: String { ls("devseed.stepSaving", comment: "") }
        static var stepDone: String { ls("devseed.stepDone", comment: "") }
        static var stepDeleting: String { ls("devseed.stepDeleting", comment: "") }
        static var stepReloading: String { ls("devseed.stepReloading", comment: "") }
    }

    // MARK: - Yala AI Onboarding

    enum YalaAI {
        enum Onboarding {
            // Common (shared across steps)
            static var continueAction: String { ls("yalaAI.onboarding.continue", comment: "") }
            static var back: String { ls("yalaAI.onboarding.back", comment: "") }
            static var close: String { ls("yalaAI.onboarding.close", comment: "") }
            static var previewLabel: String { ls("yalaAI.onboarding.previewLabel", comment: "") }
            static func progressLabel(_ current: Int, _ total: Int) -> String {
                String(format: ls("yalaAI.onboarding.progressLabel", comment: ""), current, total)
            }

            // Step 1 — Hero with chat preview animation (3 scenarios)
            static var step1Title: String { ls("yalaAI.onboarding.step1.title", comment: "") }
            static var step1Subtitle: String { ls("yalaAI.onboarding.step1.subtitle", comment: "") }
            static var step1DemoScenario1User: String { ls("yalaAI.onboarding.step1.demoScenario1User", comment: "") }
            static var step1DemoScenario1Bot: String { ls("yalaAI.onboarding.step1.demoScenario1Bot", comment: "") }
            static var step1DemoScenario2User: String { ls("yalaAI.onboarding.step1.demoScenario2User", comment: "") }
            static var step1DemoScenario2Bot: String { ls("yalaAI.onboarding.step1.demoScenario2Bot", comment: "") }
            static var step1DemoScenario3User: String { ls("yalaAI.onboarding.step1.demoScenario3User", comment: "") }
            static var step1DemoScenario3Bot: String { ls("yalaAI.onboarding.step1.demoScenario3Bot", comment: "") }
            static var step1DemoAmountLabel: String { ls("yalaAI.onboarding.step1.demoAmountLabel", comment: "") }
            static var step1A11yLabel: String { ls("yalaAI.onboarding.step1.a11yLabel", comment: "") }

            // Step 2 — What you can do (3 cards)
            static var step2Title: String { ls("yalaAI.onboarding.step2.title", comment: "") }
            static var step2Subtitle: String { ls("yalaAI.onboarding.step2.subtitle", comment: "") }
            static var step2Card1Badge: String { ls("yalaAI.onboarding.step2.card1.badge", comment: "") }
            static var step2Card1Title: String { ls("yalaAI.onboarding.step2.card1.title", comment: "") }
            static var step2Card1Body: String { ls("yalaAI.onboarding.step2.card1.body", comment: "") }
            static var step2Card2Title: String { ls("yalaAI.onboarding.step2.card2.title", comment: "") }
            static var step2Card2Body: String { ls("yalaAI.onboarding.step2.card2.body", comment: "") }
            static var step2Card3Title: String { ls("yalaAI.onboarding.step2.card3.title", comment: "") }
            static var step2Card3Body: String { ls("yalaAI.onboarding.step2.card3.body", comment: "") }

            // Step 3 — Tone (3 options + quote in preview)
            static var step3Title: String { ls("yalaAI.onboarding.step3.title", comment: "") }
            static var step3Subtitle: String { ls("yalaAI.onboarding.step3.subtitle", comment: "") }
            static var step3ToneNormalDescription: String { ls("yalaAI.onboarding.step3.toneNormalDescription", comment: "") }
            static var step3ToneConsiderateDescription: String { ls("yalaAI.onboarding.step3.toneConsiderateDescription", comment: "") }
            static var step3ToneSarcasticDescription: String { ls("yalaAI.onboarding.step3.toneSarcasticDescription", comment: "") }
            static var step3ToneNormalQuote: String { ls("yalaAI.onboarding.step3.toneNormalQuote", comment: "") }
            static var step3ToneConsiderateQuote: String { ls("yalaAI.onboarding.step3.toneConsiderateQuote", comment: "") }
            static var step3ToneSarcasticQuote: String { ls("yalaAI.onboarding.step3.toneSarcasticQuote", comment: "") }

            // Step 4 — Focus / style (3 options + quote in preview)
            static var step4Title: String { ls("yalaAI.onboarding.step4.title", comment: "") }
            static var step4Subtitle: String { ls("yalaAI.onboarding.step4.subtitle", comment: "") }
            static var step4FocusBalancedDescription: String { ls("yalaAI.onboarding.step4.focusBalancedDescription", comment: "") }
            static var step4FocusSaverDescription: String { ls("yalaAI.onboarding.step4.focusSaverDescription", comment: "") }
            static var step4FocusCautiousDescription: String { ls("yalaAI.onboarding.step4.focusCautiousDescription", comment: "") }
            static var step4FocusBalancedQuote: String { ls("yalaAI.onboarding.step4.focusBalancedQuote", comment: "") }
            static var step4FocusSaverQuote: String { ls("yalaAI.onboarding.step4.focusSaverQuote", comment: "") }
            static var step4FocusCautiousQuote: String { ls("yalaAI.onboarding.step4.focusCautiousQuote", comment: "") }

            // Step 5 — Done
            static var step5Title: String { ls("yalaAI.onboarding.step5.title", comment: "") }
            static var step5Subtitle: String { ls("yalaAI.onboarding.step5.subtitle", comment: "") }
            static var step5Tip: String { ls("yalaAI.onboarding.step5.tip", comment: "") }
            static var step5CTA: String { ls("yalaAI.onboarding.step5.cta", comment: "") }
        }
    }

    // MARK: - Stats Records polish (stats-polish-panel-alignment)

    enum Stats {
        enum Records {
            static var motivationalOne: String {
                ls("stats.records.motivationalOne", comment: "Records hero motivational subtitle when filteredCount == 1")
            }
            static func motivationalMany(_ count: Int) -> String {
                String(format: ls("stats.records.motivationalMany %d", comment: "Records hero motivational subtitle when filteredCount >= 2 (use %d placeholder)"), count)
            }
        }
        enum Insights {
            static var motivationalOne: String {
                ls("stats.insights.motivationalOne", comment: "Insights hero motivational subtitle when transactionCount == 1")
            }
            static func motivationalMany(_ count: Int) -> String {
                String(format: ls("stats.insights.motivationalMany %d", comment: "Insights hero motivational subtitle when transactionCount >= 2 (use %d placeholder)"), count)
            }
            static var detailHeader: String {
                ls("stats.insights.detailHeader", comment: "Detail mode section header — generic 'Your numbers' (period shown as subtitle)")
            }
            static var aiCardTitle: String {
                ls("stats.insights.aiCardTitle", comment: "Pro Insights AI tappable card title")
            }
            static var aiCardSubtitle: String {
                ls("stats.insights.aiCardSubtitle", comment: "Pro Insights AI tappable card subtitle")
            }
            static func dailyAvgIn(_ period: String) -> String {
                String(format: ls("stats.insights.dailyAvgIn %@", comment: "Daily average context label (e.g., 'per day in this month')"), period)
            }
            static func needDailyFormat(_ amount: String) -> String {
                String(format: ls("stats.insights.need.dailyFormat %@", comment: "Need bucket daily average label (e.g., '≈ S/12/day')"), amount)
            }
            static var modeDetail: String {
                ls("stats.insights.modeDetail", comment: "Content mode pill label: detailed monthly figures view")
            }
        }
        enum Trends {
            static var comparisonTitle: String {
                ls("stats.trends.comparisonTitle", comment: "Title for the period comparison section (M/A selector to the right)")
            }
            static func insightTitleFree(_ period: String) -> String {
                String(format: ls("stats.trends.insightTitleFree %@", comment: "Trend Insight Card title for Free users (param: period name, e.g., 'mes')"), period)
            }
            static var insightTitlePro: String {
                ls("stats.trends.insightTitlePro", comment: "Trend Insight Card title for Pro users")
            }
            static var refineWithAI: String {
                ls("stats.trends.refineWithAI", comment: "CTA chip in Free trend insight card — opens upsell sheet")
            }
            static var generateAI: String {
                ls("stats.trends.generateAI", comment: "CTA in Pro pre-AI trend insight card — triggers AI generation")
            }
            static var regenerate: String {
                ls("stats.trends.regenerate", comment: "CTA in Pro post-AI trend insight card — regenerates AI analysis")
            }
            static var aiFootnote: String {
                ls("stats.trends.aiFootnote", comment: "Footer label in Pro post-AI trend insight card balancing the Regenerate chip — identitarian tag")
            }
            static var heroOnset: String {
                ls("stats.trends.heroOnset", comment: "Hero subtitle when no previous period comparable (first month / .allTime)")
            }
            static var heroStable: String {
                ls("stats.trends.heroStable", comment: "Hero subtitle when |balance variation| < 5% (no significant change)")
            }
            static func heroVarUp(_ percent: Int, _ previousPeriod: String) -> String {
                String(format: ls("stats.trends.heroVarUp %d %@", comment: "Hero subtitle when balance variation positive ≥5% (params: percent, previousPeriod label e.g. 'Abr 26')"), percent, previousPeriod)
            }
            static func heroVarDown(_ percent: Int, _ previousPeriod: String) -> String {
                String(format: ls("stats.trends.heroVarDown %d %@", comment: "Hero subtitle when balance variation negative ≥5% (params: percent, previousPeriod label e.g. 'Abr 26')"), percent, previousPeriod)
            }
            enum Insight {
                static func onset(_ period: String) -> String {
                    String(format: ls("stats.trends.insight.onset %@", comment: "Trend Insight: user has no previous period (first %@: period name)"), period)
                }
                static func varUpExpense(_ percent: Int, _ previousPeriod: String) -> String {
                    String(format: ls("stats.trends.insight.varUpExpense %d %@", comment: "Trend Insight: expense rose %d%% vs %@ (previous period label)"), percent, previousPeriod)
                }
                static func varDownExpense(_ percent: Int, _ previousPeriod: String) -> String {
                    String(format: ls("stats.trends.insight.varDownExpense %d %@", comment: "Trend Insight: expense fell %d%% vs %@ (previous period label)"), percent, previousPeriod)
                }
                static func varUpIncome(_ percent: Int, _ previousPeriod: String) -> String {
                    String(format: ls("stats.trends.insight.varUpIncome %d %@", comment: "Trend Insight: income rose %d%% vs %@ (previous period label)"), percent, previousPeriod)
                }
                static func varDownIncome(_ percent: Int, _ previousPeriod: String) -> String {
                    String(format: ls("stats.trends.insight.varDownIncome %d %@", comment: "Trend Insight: income fell %d%% vs %@ (previous period label)"), percent, previousPeriod)
                }
                static func varUpBalance(_ percent: Int, _ previousPeriod: String) -> String {
                    String(format: ls("stats.trends.insight.varUpBalance %d %@", comment: "Trend Insight: balance rose %d%% vs %@ (previous period label)"), percent, previousPeriod)
                }
                static func varDownBalance(_ percent: Int, _ previousPeriod: String) -> String {
                    String(format: ls("stats.trends.insight.varDownBalance %d %@", comment: "Trend Insight: balance fell %d%% vs %@ (previous period label)"), percent, previousPeriod)
                }
                static var stableExpense: String {
                    ls("stats.trends.insight.stableExpense", comment: "Trend Insight: expense holds stable (variation < 5%)")
                }
                static var stableIncome: String {
                    ls("stats.trends.insight.stableIncome", comment: "Trend Insight: income holds stable (variation < 5%)")
                }
                static var stableBalance: String {
                    ls("stats.trends.insight.stableBalance", comment: "Trend Insight: balance holds stable (variation < 5%)")
                }
            }
        }
        enum Distribution {
            static func heroSubtitle1(_ count: Int) -> String {
                String(format: ls("stats.distribution.heroSubtitle1 %d", comment: "Hero subtitle 1 dimension active (only categories)"), count)
            }
            static func heroSubtitle2(_ cats: Int, _ subs: Int) -> String {
                String(format: ls("stats.distribution.heroSubtitle2 %d %d", comment: "Hero subtitle 2 dimensions (categories + subcategories)"), cats, subs)
            }
            static func heroSubtitle3(_ cats: Int, _ subs: Int, _ tags: Int) -> String {
                String(format: ls("stats.distribution.heroSubtitle3 %d %d %d", comment: "Hero subtitle 3 dimensions (categories + subcategories + tags)"), cats, subs, tags)
            }
            static func insightTitleFree(_ period: String) -> String {
                String(format: ls("stats.distribution.insightTitleFree %@", comment: "Distribution Insight Card title for Free users (param: period name)"), period)
            }
            static var insightTitlePro: String {
                ls("stats.distribution.insightTitlePro", comment: "Distribution Insight Card title for Pro users")
            }
            static var aiFootnote: String {
                ls("stats.distribution.aiFootnote", comment: "Footer label in Pro post-AI distribution insight card")
            }
            static var modeCharts: String {
                ls("stats.distribution.modeCharts", comment: "Content mode pill label: charts view (pies + sankey + need bars)")
            }
            enum Insight {
                static func onset(_ period: String) -> String {
                    String(format: ls("stats.distribution.insight.onset %@", comment: "Distribution Insight: empty or no comparable data"), period)
                }
                static func newCategory(_ name: String, _ period: String) -> String {
                    String(format: ls("stats.distribution.insight.newCategory %@ %@", comment: "Distribution Insight: user tried a new category this period"), name, period)
                }
                static func concentrated(_ percent: Int, _ topCategory: String) -> String {
                    String(format: ls("stats.distribution.insight.concentrated %d %@", comment: "Distribution Insight: spending concentrated in top category (>=40%)"), percent, topCategory)
                }
                static func balanced(_ maxPercent: Int) -> String {
                    String(format: ls("stats.distribution.insight.balanced %d", comment: "Distribution Insight: spending balanced across categories"), maxPercent)
                }
                static func shiftedUp(_ percent: Int, _ category: String, _ previousLabel: String) -> String {
                    String(format: ls("stats.distribution.insight.shiftedUp %d %@ %@", comment: "Distribution Insight: top category rose %d%% vs %@"), percent, category, previousLabel)
                }
                static func shiftedDown(_ percent: Int, _ category: String, _ previousLabel: String) -> String {
                    String(format: ls("stats.distribution.insight.shiftedDown %d %@ %@", comment: "Distribution Insight: top category fell %d%% vs %@"), percent, category, previousLabel)
                }
                static func topSub(_ percent: Int, _ sub: String, _ parent: String) -> String {
                    String(format: ls("stats.distribution.insight.topSub %d %@ %@", comment: "Distribution Insight: top subcategory dominates within parent"), percent, sub, parent)
                }
            }
        }
        enum Sankey {
            static var subtitle: String {
                ls("stats.sankey.subtitle", comment: "Sankey widget internal subtitle (above the KPI total amount)")
            }
        }
    }

}

// MARK: - App Locale

/// Centralized locale configuration for date formatters and charts.
/// Lee de `LanguageManager.resolved.locale` para mantener un único punto de verdad
/// — evita divergencia entre formatters y strings.
enum AppLocale {
    /// The app's current locale for date formatting.
    /// Respects language override if set, otherwise uses system locale.
    static var current: Locale {
        LanguageManager.resolved.locale
    }

    /// Short identifier for SwiftUI .locale() modifiers
    static var identifier: String {
        current.identifier
    }

    /// Creates a configured DateFormatter with the app's locale
    static func dateFormatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = current
        formatter.dateFormat = dateFormat
        return formatter
    }
}
