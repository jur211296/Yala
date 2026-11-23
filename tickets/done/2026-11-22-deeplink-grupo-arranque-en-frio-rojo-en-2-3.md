---
id: 2026-11-22-deeplink-grupo-arranque-en-frio-rojo-en-2-3
status: backlog
priority: high
area: "grupos, deeplink, arranque"
created: 2026-11-22
updated: 2026-11-22
source: "gate del encargo «Captura por foto y atajo del banco, parte 2» (22-nov, sesión nocturna)"
---

# El enlace a un grupo en arranque en frío ya no abre su detalle (XCUITest rojo en 2.3)

`YalaUITests/Flows/GroupDetailDeeplinkColdLaunchUITests#test_groupDeepLink_survivesColdLaunch_routesToDetail` cae en
`2.3`: tras sembrar `grupos` y relanzar con `yala://groups/seeded-first`, `group_members_button` no aparece en 20 s.

## Medido

- **Rojo en la base `b27dcc084`** (merge de #1110), sin ningún cambio encima: worktree limpio, el mismo simulador,
  `Yala Dev`, 1 de 1. Mismo rojo dos veces en la rama del encargo parte 2, con el centinela en verde (sin corridas
  encima).
- **Verde en la nocturna del 21-nov** (`qa.yml`, run 44922850036, sobre `be48b1057`, merge de #1104): pasó en 66,8 s.
- Entre los dos entraron, por orden: #1105 (CI más rápido), #1106 (icono de subcategoría en «Elige los pagos»),
  #1107 (Reusar acepta gastos de grupo), #1109 (política sin «Conectar Gmail») y #1110 (el eco de lo guardado no
  recalcula la app, YALA-IOS-A).

## Inferido, sin medir

#1110 cambia cuándo la app se entera de lo que bajó o guardó; es el candidato más probable para un enlace que se drena
después del arranque. #1107 toca gastos de grupo. Bisecar con esos dos commits primero.

## Hecho cuando

El caso vuelve a verde en el simulador y en la nocturna, con la causa nombrada en el commit. Si el arreglo no es
inmediato, a la cuarentena (`qa/cuarentena.json`) con dueño y fecha.
