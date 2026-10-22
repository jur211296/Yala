---
id: synced-prefs-outside-prefsynckey
status: discarded
area: sync
priority: high
created: 2026-08-29
updated: 2026-08-29
source: docs/aprendizajes-tecnicos.md
---

# Cinco preferencias suben al canal y no vuelven nunca

## Qué pasa

Cinco claves están marcadas `synced: true` pero **no son casos de `PrefSyncKey`**, así que
suben a iKV/outbox y **no bajan jamás**. Es pérdida silenciosa en el canal que enciende el
Modo Nube: el usuario cambia la preferencia en un device y no aparece en el otro, sin error.

- `moreSectionOrder`
- `sankeyLabelMode`
- `panelHeroKPIsCustomized`
- `panelHeroKPIsHidden`
- `panelHeroKPIsOrder`

## La medición

Verificado el 2026-08-29 contra el árbol: `enum PrefSyncKey` (en
`Yala/Services/CloudSync/PreferenceMergeLogic.swift`) tiene **37 casos**, y las cinco de arriba
quedan fuera. Coincide exactamente con lo que el residual dejó anotado el 2026-08-11.

## Qué hay que decidir

Es una decisión, no una implementación: **o entran al enum, o bajan a `synced: false`**. Lo
que no puede quedarse es el estado actual, que promete sincronizar y no sincroniza.

## De dónde sale

Residual declarado ABIERTO en [docs/aprendizajes-tecnicos.md#cargar-una-preferencia-no-puede-escribirla--y-el-eco-de-eso-converta-al-receptor-en-autor-lww](../../docs/aprendizajes-tecnicos.md#cargar-una-preferencia-no-puede-escribirla--y-el-eco-de-eso-converta-al-receptor-en-autor-lww):
«**5 de las 37 keys `synced: true` NO son `PrefSyncKey`** (`moreSectionOrder`,
`sankeyLabelMode` y las tres de `panelHeroKPIs`) ⇒ **suben a iKV/outbox y no vuelven JAMÁS.**»
