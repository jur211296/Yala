---
name: upload-ok-no-es-build-aceptado
description: En una subida a TestFlight, `asc builds upload` exit 0 y `altool --validate-app` OK no significan aceptado; el rechazo sale en `asc builds uploads list` (state FAILED, solo códigos)
metadata:
  type: feedback
---

**Tras `asc builds upload`, el veredicto se lee en `asc builds uploads list --app 6758253109`
(`state.state`), no en el exit code ni en `asc builds list`.** Un upload rechazado nunca aparece
como build: un sondeo que solo mira `asc builds list --version X` espera para siempre.

**Why:** 2026-10-26, primer TestFlight de 2.2. El build 1 subió con exit 0 y
`xcrun altool --validate-app` dio «VERIFY SUCCEEDED» sobre el mismo `.ipa`; ASC lo dejó `FAILED`
con 23 × ITMS-90626 (traducciones de frases de Siri con «Apple»/«Siri»). La API solo devuelve el
código; el texto llegó por el correo de Apple, que Jürgen pegó en la sesión. Desde esta sesión no se
puede leer `~/Library/Mail`. El número 1 quedó consumido: `asc builds next-build-number` lo cuenta.

**How to apply:** en cada subida, sondea `uploads list` hasta `COMPLETE` o `FAILED`. Con `FAILED`,
pide a Jürgen el correo de Apple (trae el texto de cada error) en vez de adivinar por el código, y
el siguiente build usa `next-build-number`. El test
`SiriPhrasesPortugueseTests.ningunaTraduccion_llevaMarcasQueAppStoreRechaza` ya cubre el caso de
las marcas. Relacionado: [[credencial-pendiente-se-aparca]].
