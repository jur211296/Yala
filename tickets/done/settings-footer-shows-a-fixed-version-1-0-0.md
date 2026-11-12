---
id: settings-footer-shows-a-fixed-version-1-0-0
status: done
area: settings
priority: low
created: 2026-10-13
updated: 2026-10-15
source: docs/ux/mapa-de-flujos-2.2.md (auditoría UX 2.2, fase 1)
---

# El pie de Ajustes dice «Versión 1.0.0 (Build 1)» en cualquier versión

**Clase:** bug de copy. Lo revisa el lote 16 de la auditoría UX 2.2.

## Qué pasa

El pie de la hoja de Ajustes pinta un texto fijo: `"settings.versionInfo" = "Versión 1.0.0 (Build 1)";`
(`Yala/Resources/es.lproj/Localizable.strings`), que `ProfileView` muestra tal cual con `Text(L10n.Settings.versionInfo)`.
Con la app en 2.1, quien manda una captura a soporte ve 1.0.0.

## Hecho cuando

El pie lee `CFBundleShortVersionString` y `CFBundleVersion` del bundle, en los 16 idiomas con su formato.

## Cerrado (2026-10-15)

Arreglado en el PR #509 (lote 16 de la auditoría UX 2.2): el pie lee `CFBundleShortVersionString` y `CFBundleVersion` (`AppVersionInfo.footer`), «Versión %1$@ (Build %2$@)» en los 16 idiomas. Tests: `SettingsLote16CopyTests` y `SettingsLote16UITests/test_versionFooter_isNotTheOldFixedText`.
