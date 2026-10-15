---
id: notification-day-choice-capitalizes-every-word
status: backlog
priority: low
area: "notifications, copy, l10n"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 9 (presupuestos), visto fuera del lote"
---

# El resumen mensual ofrece «Primer Día Del Mes» y «Último Día Del Mes»

Medido el 2026-10-14 (iPhone 17 Pro, iOS 27.0, español): en Perfil › Notificaciones › Resumen mensual, la sección
«¿Cuándo recibirlo?» enseña «Primer Día Del Mes» y «Último Día Del Mes». `NotificationEditorSheet.dayPreferenceRow`
pinta `display.capitalized`, que pone mayúscula en cada palabra (la misma trampa que `month-year-titles-capitalize-every-word`).

## Hecho cuando

Las opciones salen con mayúscula solo en la primera letra («Primer día del mes») en los 16 idiomas, con
`capitalizingFirstLetter(locale: AppLocale.current)` o con el texto ya bien escrito en el catálogo.
