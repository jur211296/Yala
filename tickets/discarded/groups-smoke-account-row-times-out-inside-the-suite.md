---
id: groups-smoke-account-row-times-out-inside-the-suite
status: discarded
updated: 2026-11-02
priority: low
area: "groups, xcuitest"
created: 2026-11-02
source: gate de grupos-b-tarjeta-tu-parte (card 4), 2026-11-02
---

# `test_groupExpenseAccountRowFollowsThePayer` cae dentro de la suite y pasa aislado

**Medido el 2026-11-02**, iPhone 17 Pro, iOS 27.0, `Yala Dev`, centinela a 0 (sin otra corrida encima):

- `-only-testing:YalaUITests/SettlementAmountChangeNoticeUITests -only-testing:YalaUITests/GroupsSmokeUITests`:
  13 casos, 1 rojo — `GroupsSmokeUITests.swift:319`, «Pagaste tú y no apareció la fila de cuenta.» (espera de 5 s a
  `group_expense_account_row` tras tocar «Editar»).
- El mismo caso aislado, dos veces seguidas: verde las dos (32,6 s y 34,1 s).
- La misma pareja de suites, otra vez y con el simulador recién borrado: 13/13 verde. Es intermitente, no fijo.

El diff de aquella sesión no alcanza esa pantalla (componente nuevo sin cablear y strings añadidos), así que no se
persiguió. Inferido, sin medir: el plazo de 5 s es corto para el formulario de edición en iOS 27.0 cuando el caso corre
detrás de otros; la regla de `testing.md` sobre los plazos en el runner lento apunta al mismo sitio.

**Qué hacer:** fechar el rojo con la nocturna (`gh run view --log` de `qa.yml`) y, si se repite, ver en el vídeo del
`.xcresult` qué hay en pantalla a los 5 s antes de subir el plazo.

## Cierre (2026-11-02): no se confirma, no se toca el plazo

**Medido** con `gh run view --log` de las 15 nocturnas de `qa.yml` por `schedule` del 18-oct al 1-nov (todas
`success`): el caso corre en la tanda de UI que le toca y **pasa las 15 a la primera iteración** (`Iteration 1 of 3`,
~32 s; el 1-nov, 32,3 s), en el runner frío del CI, que es más lento que la Mini. Ningún `GroupsSmokeUITests.swift:319`
en ningún log. El único rojo sigue siendo el local del 2-nov, que pasó 13/13 al repetir con el simulador borrado.

Subir los 5 s sin un rojo que lo justifique taparía el siguiente fallo real de esa pantalla. Si vuelve a caer —en la
nocturna o en un gate solo en el simulador—, se reabre con el vídeo del `.xcresult` a los 5 s, como decía el plan.
