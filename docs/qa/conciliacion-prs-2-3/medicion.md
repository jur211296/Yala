# Medición de los PR abiertos contra 2.3 — 14-nov-2026, 16:51 Lima

Fuente de la tabla del README. Todo lo de aquí está **medido** sobre `origin/2.3` = `bf567d64c`.

## Estado de GitHub

- 18 PR abiertos contra 2.3. Fuera de alcance por encargo: 613 (Conectar Gmail, borrador), 977 y 978 (esta tarde,
  los cierran sus sesiones). Quedan 15.
- Los 15: **todos `CONFLICTING/DIRTY`** y **todos con auto-merge activado** salvo 882. Sus sesiones cerraron en modo
  cola, el PR quedó en cola y el primer merge vecino lo dejó en conflicto. La cola no avisa: llevaban de 1 a 8 días así.
- CI de la última corrida: `tests` y `coverage-index` en verde en todos menos **899** (`tests` en rojo).
- `git cherry origin/2.3 <rama>`: ningún commit de ningún PR está en 2.3.
- Fracción de líneas añadidas por cada PR que ya existen en 2.3: entre 0 % y 16 % → su código **no está** en 2.3.
- Sus cards del tablero: casi todas en `done` o `in qa`, porque el cierre en modo cola las movió al encolar.

## Conflictos por PR (`git merge-tree --write-tree origin/2.3 <rama>`)

| PR | Commits detrás de 2.3 | Ficheros en conflicto |
|---|---|---|
| 973 | 23 | DECISIONS.md, coverage-index.json |
| 962 | 62 | DECISIONS.md, TICKETS.md |
| 954 | 94 | ContentView.swift, WelcomeCoverContentLogic(+Tests), TICKETS, coverage-index, memoria |
| 943 | 127 | 16 Localizable.strings, coverage-index |
| 930 | 167 | TICKETS, coverage-index |
| 924 | 187 | swiftui-ds.md, 16 Localizable.strings, coverage-index |
| 922 | 191 | RecordsStandaloneView.swift, RecordsTabView.swift, TICKETS |
| 920 | 193 | l10n.md, 16 Localizable.strings, LocalizationParityTests.swift, coverage-index |
| 916 | 202 | 16 Localizable.strings, coverage-index |
| 912 | 212 | 16 Localizable.strings, coverage-index, memoria |
| 910 | 231 | swiftdata-cloudkit.md, 16 Localizable.strings, DECISIONS, coverage-index |
| 899 | 255 | mcp balances.ts, summary.ts, toolCore.ts, coverage-index |
| 894 | 270 | SettlementFormView.swift, l10n.md, TICKETS, coverage-index, memoria |
| 882 | 391 | CLAUDE.md |
| 818 | 529 | 4 Localizable.strings, mcp toolCore.ts, DECISIONS, TICKETS, coverage-index |

## Por qué ninguno se resolvió en esta sesión

Hasta los conflictos «solo de documentos» (973, 930) exigen traer al PR el código Swift que entró en 2.3 desde que
nació. El hook de pre-commit (`qa/scripts/precommit-gate.sh`) pide entonces el sello de `/gate`: build ×2, unit y
XCUITest del área, con simulador, y esta Max ya tenía viva la sesión de las tandas rojas de UI. Saltarse el hook no
es una opción. «Trivial y seguro» no se cumple en ninguno: todos los vigentes van a continuación.

## Relaciones medidas

- **962 ⊂ 973**: los tres commits de 962 son ancestros de la rama de 973, que lo mergeó dentro.
- **954 lo reemplaza 971** (mergeado hoy 15:52): mismo bug («Empezar» tras «¡Tu cuenta está lista!» vuelve a la
  bienvenida), misma causa (el respaldo del cover leía el onboarding capturado al presentar) y mismo arreglo (leerlo
  de disco en `WelcomeCoverContentLogic`). 971 además lo probó en el iPhone 14.
- **882 lo reemplaza `a4cf4abe6`** en 2.3: el `CLAUDE.md` ya dice que la subida a TestFlight se hace desde la Mini o la Max.
- **Cards «en curso» sin sesión viva:** la guía visual de usuario nuevo tiene sus dos PR mergeados el 7-nov; el
  onboarding 2.3 desde cero desembocó en el diseño oficial de `docs/onboarding-2-3/` (PR mergeado el 8-nov), ya construido.
