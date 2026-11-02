---
id: groups-smoke-account-row-times-out-inside-the-suite
status: backlog
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
