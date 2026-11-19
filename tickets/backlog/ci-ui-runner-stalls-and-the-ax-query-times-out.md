---
id: ci-ui-runner-stalls-and-the-ax-query-times-out
status: backlog
priority: medium
area: "testing, ci"
created: 2026-11-17
updated: 2026-11-17
source: "sesión «Dejar 2.3 perfecta» (17-nov): batería de UI sobre 2.3 (run 44074738336) y nocturna del 16-nov (run 43929672868)"
---

# En el CI, a veces un caso de UI cae con «Timed out while evaluating UI query» y pasa al reintentar

## Medido

Un caso cae una vez con `Failed to get matching snapshots: Timed out while evaluating UI query` y pasa en el reintento.
Nunca el mismo caso dos veces seguidas:

- 16-nov, tanda 5: `CategoryQuickPick23UITests.test_moreOpensTheSheet_andCafeFindsRestaurants` (330 s).
- 16-nov, tanda 7: `AntExpensesAIProUITests.test_pro_seesWhatTheAIMerged_andATip_belowTheFreeCard`.
- 17-nov, tanda 4: `AjustesYProNecesariasLote10UITests.test_aiPrivacy_withoutPro_insightsRowIsMarkedPro_andOpensPro`
  (658 s). En su log: la app tardó 70 s en avisar de que estaba ociosa al arrancar («App event loop idle notification
  not received») y 340 s en mostrar `uitest_ready`; después tres consultas lentas y la que se agota.
- 17-nov, tanda 6: `AIConsentAlertUITests.test_voicePillWithoutConsent_showsTheNotice_withoutTheProviderName_andCancelCloses`
  (233 s).

En local (iPhone 17 Pro, iOS 27.2) los tres pasan.

## Por qué importa

Jürgen pidió 2.3 con las nueve tandas sin fallos, también sin reintento. Mientras el runner tenga estos atascos, una
tanda puede salir con un fallo reintentado sin que nada esté roto.

## Qué mirar

Si el atasco es del runner (carga de la máquina de GitHub en ese momento: mirar si coincide con el arranque de otras
tandas en la misma máquina) o de la app (algo que no la deja quedarse ociosa al arrancar). El instrumento: el vídeo del
`.xcresult` de la tanda, que hoy el CI no sube como artefacto.
