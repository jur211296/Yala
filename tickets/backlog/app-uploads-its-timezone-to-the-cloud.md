---
id: app-uploads-its-timezone-to-the-cloud
status: backlog
priority: medium
area: cloud
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-claude-mcp-numbers-match-the-app (decisión 4 del encargo)
---

# Que el conector de Claude sepa en qué zona horaria está el usuario

## Qué cambia para el usuario

Si alguien vive fuera de Lima y le pregunta a Claude «¿cuánto llevo gastado este mes?», hoy Claude decide qué día es
«hoy» y dónde empieza el mes con la hora de Lima, salvo que Claude le pase otra zona. Cerca de la medianoche del
último día del mes, eso puede meter o sacar un día entero de movimientos respecto a lo que enseña la app. Con este
ticket la cifra cuadra también en el borde.

## Estado

- El conector (`mcp/`) acepta `zona_horaria` como entrada y, si no llega, usa `America/Lima` y lo dice en `avisos`.
- La app calcula los periodos con `Calendar.current`, o sea con la zona del teléfono, y **no la sube**: no hay
  ninguna `PrefSyncKey` de zona (medido el 2026-09-26 en `PreferenceMergeLogic.swift`).
- El día de cada movimiento ya viaja (`local_day`), así que lo único que falta es «qué día es hoy» y dónde empieza
  cada periodo.

## Premisa corregida al abrir el ticket

El encargo pedía subir también `firstWeekday`. **Ya se sube**: `firstWeekday` es una `PrefSyncKey` de las de
«ints por presencia» (`PreferenceMergeLogic.swift:109`), así que viaja en cuanto el usuario la cambia en Ajustes; y
si no la cambia, la app usa lunes (`userConfiguredCalendar`), que es lo mismo que usa el conector. Que staging no
tenga la key significa solo que nadie la ha tocado. Este ticket se queda con la zona.

## Qué hay que hacer

- Añadir una `PrefSyncKey` con el identificador IANA de la zona del teléfono (`TimeZone.current.identifier`), que se
  actualice al abrir la app y al cambiar de zona (`NSSystemTimeZoneDidChange`). Toca código Swift de la app y el
  conteo de keys de `PrefSyncKey` (y sus tests de taxonomía).
- En `mcp/src/tools.ts`, leerla en `loadPrefs` y usarla cuando Claude no pase `zona_horaria`; el aviso de zona
  queda solo para cuando tampoco esté en las preferencias.
- Decidir qué pasa si el usuario tiene dos teléfonos en zonas distintas: el último que escribe gana (LWW normal de
  las preferencias) parece suficiente.

## Cómo se sabe que está bien

Un usuario de Modo Nube con el teléfono en Madrid pregunta por «este mes» sin decir zona y el conector usa
`Europe/Madrid`, sin aviso de zona.
