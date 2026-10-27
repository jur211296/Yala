---
name: reference-fechar-un-rojo-con-la-nocturna
description: Fechar cuándo se puso rojo un XCUITest sin bisecar a ciegas — la nocturna de qa.yml guarda el veredicto por caso de cada día.
metadata:
  type: reference
---

La nocturna de `.github/workflows/qa.yml` (evento `schedule`, rama `2.2`) corre la suite de UI en tandas y su log trae
la línea `Test Case … passed/failed` de cada caso. Con eso un rojo se fecha en minutos:

```bash
gh run list --workflow qa.yml --event schedule --limit 12 --json databaseId,headSha,createdAt
gh run view <id> --log | grep -E "Test Case .*<nombre_del_test>.*(passed|failed)"
```

El `headSha` del último verde y del primer rojo acotan la ventana para bisecar. Las tandas son «advisory» y la corrida
sale `success` aunque haya rojos: no mires la conclusión, mira el caso. Un día sin línea es que esa tanda no lo corrió
(tope de tiempo), no que pasara.

**Why:** el 2026-10-27 dio la ventana del bug de «Detalles» de Yala IA (verde 21-oct `df498b7cc`, rojo 23-oct
`43daa3354`) y destapó que dos rojos «de la base» dependían del día: verde un día, rojo el siguiente, sin commits de por medio en su área.
**How to apply:** antes de bisecar o de llamar flaky a un rojo, mira varias nocturnas. Si alterna con el calendario,
busca qué del escenario depende de la fecha (semilla, «Este mes») — ver [[feedback-regresion-aparente-se-mide-contra-la-base]].
