---
id: 2026-11-27-foto-widget-por-etapas-rojo-en-la-suite-completa
status: done
priority: medium
area: "tests, widgets"
created: 2026-11-27
updated: 2026-11-27
source: "suite completa de YalaTests del gate del lote 6 de eficiencia (27-nov-2026, 00:48 Lima, simulador iPhone 17 Pro, iOS 27.2)"
---

# `FotoWidgetPorEtapasTests` sale rojo en la suite completa y verde a solas

## Qué se midió

- Suite completa (`-only-testing:YalaTests`, scheme `Yala Dev`, sobre `origin/2.3` en `09910cfa0`): 16.625 casos, 1 rojo:
  `FotoWidgetPorEtapasTests.unCambioDelEspejoAMitad_tiraLaFotoYPideOtra()`, en
  `YalaTests/CuelguesHeroWidget/FotoWidgetPorEtapasTests.swift:131`:
  `WidgetDataCache.debugStagedBuildsRestarted == restarted + 1` falló.
- La misma suite sola, tres veces seguidas: 4 de 4 verdes cada vez.
- El cambio que corría el gate no toca código de la app (solo un test nuevo y documentación).

## Hipótesis (sin medir)

El caso postea `.NSPersistentStoreRemoteChange` en `NotificationCenter.default` y exige exactamente UN reinicio de la foto.
Dentro de la suite completa, el `save()` de cualquier otro almacén también postea ese aviso en otro hilo y en carrera
(regla «Un test que afirma que algo SIGUE lleno no escucha `NotificationCenter.default`» de `.claude/rules/testing.md`):
un aviso de más reinicia la foto dos veces y el `== restarted + 1` cae.

## Plan

1. Reproducir: correr `FotoWidgetPorEtapasTests` detrás de una suite que guarde en otro almacén, o con un aviso extra
   posteado a mano entre `waitUntilStagedBuildStarts()` y el aviso del test.
2. Si se confirma: que `WidgetDataCache` reciba un centro de avisos inyectable y el test postee en uno propio, o que el
   caso afirme `>= restarted + 1` (lo que importa es que la foto vieja no se publique y la nueva sí).
3. Mismo repaso para el caso hermano `unGuardadoAMitad_*`, que cuenta reinicios igual.

## Cierre (2026-11-27)

Repetido: lo resolvió el PR 1204 (deuda de 2.3, «aislar()» en `FotoWidgetPorEtapasTests`). Cerrado por el lote 7 de eficiencia.
