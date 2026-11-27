---
id: 2026-11-26-prueba-de-voz-no-monta-el-panel-de-escucha
status: backlog
priority: medium
area: "qa, voz"
created: 2026-11-26
updated: 2026-11-26
source: "gate del lote 5 de eficiencia (render del scroll), 26-nov-2026"
---

# `VoiceInputCurrencyExamplesUITests` cae en 2.3: tocar Voz no monta el panel de escucha

`test_voiceEntryOpensListeningRightAway` falla en el simulador (iPhone 17 Pro, iOS 27.2) con
«Tocar Voz no montó el panel de escucha (voice_listening_panel)» a los ~46 s: el menú del FAB abre y `fab_voice` se
toca, pero el panel no aparece en 30 s.

**Medido el 2026-11-26 en la Max:** 3 de 3 en rojo, dos con el lote 5 encima y una con `origin/2.3` en `f1911c7e4` sin
ningún cambio (los tres ficheros del lote devueltos a 2.3). Centinela del simulador en 0: corrida sola. No es del lote 5.

## Hecho cuando

- Se sabe desde qué commit cae (la nocturna de `qa.yml` lo fecha) y por qué: la app, el seam de voz o la prueba.
- La prueba vuelve a verde o va a la cuarentena con dueño y fecha.
