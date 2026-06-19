# Fixtures deprecadas

Scripts agent-device con **JSON inválido** (mismo patrón de corrupción: un `}` donde va `]`,
fusionando los objetos `find` + `type`). Detectados en la auditoría de QA (2026-06-01).

**No se reparan** (decisión D4): las suites determinísticas migran a **XCUITest**
(ver `qa/coverage-index.json` + plan QA autónomo). Las que quedan agénticas se cubren
vía `/device-qa`. Se conservan aquí solo como referencia histórica.
