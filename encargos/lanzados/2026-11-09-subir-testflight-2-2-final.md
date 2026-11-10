---
toca: Yala.xcodeproj/, Yala/Resources/, YalaWidgets/Info.plist, YalaShare/Info.plist, scripts/
release: no
---
Yala
# Subir a TestFlight la build final de la 2.2, candidata para App Store

Pedido de Jürgen, 9-nov 20:14 Lima. Card «Build final de 2.2 a TestFlight». Base: `origin/2.2` en jur211296/Yala, ya con el lote de cierre 2.2 y la de Entrar con Google mergeados (verifícalo; si alguno no se mergeó, súbela igual con lo que hay y anótalo). Una sola sesión, un cierre. Sube el número de build, archiva y sube a TestFlight igual que en la subida 2.2 anterior, con los dSYM a Sentry. Deja las notas de prueba en español neutro latinoamericano. No envíes a revisión de App Store: eso lo decide Jürgen después de probarla. Lleva el cambio del número de build también a 2.3 (merge o cherry-pick) si no choca.

Mueve la card a done con evidencia (número de build, estado en App Store Connect). Commits sin firma de IA.

En la Max, si otra sesión de otro proyecto ya usa un simulador, puedes abrir un segundo (tope 2) o usar el iPhone 14 conectado por DeviceMCP.

## Cierre
Según el modo fijado al arrancar: en semiautónomo, si está completo, `/cerrar-total`; lo vital se pregunta y se espera con la sesión viva. En nocturno, lo vital va a checkpoint recuperable con card «Espera decisión» para Jürgen; si está completo, `/cerrar-total`.

## Paso 0 (Frank, 2026-11-09, Max, modo nocturno)

- **Parada: la sesión cayó en la Max y la subida se hace solo desde la Mini** (`CLAUDE.md`, sección Stack; `docs/FLUJO-RAMAS-Y-HOTFIX.md`). No es solo una norma: medido con `security find-identity -v -p codesigning`, la Max tiene únicamente «Apple Development», sin certificado de distribución; y `asc` aquí tiene la credencial «Yala» sin `keyId` y se cuelga al consultar. Archivar y subir desde aquí exigiría otra vía de firma no autorizada.
- **Base medida:** `origin/2.2` = `a43ae15ef`. Lleva 2.2 / build 7 en los 20 targets (`CURRENT_PROJECT_VERSION = 7`). El build siguiente se mide al subir con `asc builds list` en la Mini (en el 2.2 (7) el encargo traía la cuenta vieja).
- **Qué está dentro:** el lote de cierre 2.2 (PR 877) sí está mergeado. **Entrar con Google/Apple con iCloud privado propio NO**: su PR (878) es un checkpoint nocturno en borrador, sin mergear. El encargo dice subir igual y anotarlo.
- **No se tocó** `project.pbxproj`: el número de build se fija en la Mini al medir.
- **Para retomarlo en la Mini:** mismo procedimiento que el 2.2 (7): medir el último build, bump de `CURRENT_PROJECT_VERSION` en los 20 targets, archive `Yala` Release, preflight sobre el `.xcarchive` antes de exportar (el `ExportOptions.plist` sube en el acto), subida, dSYM con `scripts/sentry-subir-dsym.sh`, notas de prueba en español neutro, sin enviar a revisión. Después, llevar el bump a `2.3` si no choca.
