---
toca: Yala.xcodeproj/, Yala/Resources/, YalaWidgets/Info.plist, YalaShare/Info.plist, scripts/, CLAUDE.md, docs/FLUJO-RAMAS-Y-HOTFIX.md
release: no
depende: Yala/icloud-privado-opcion-b
---
Yala
# Subir a TestFlight la build final de la 2.2, candidata para App Store

Pedido de Jürgen, 9-nov 20:14 Lima; reencolado el 10-nov 6:03 para cualquier máquina. Anoche una sesión anterior de este mismo encargo cayó en la Max sin poder subir: lee su checkpoint en la card «Build final de 2.2 a TestFlight: la sesión cayó en la Max» y retoma desde ahí, y luego mueve esa card a done.

En la Mini o en la Max, usa el mismo método de firma y subida que en la Mini: firma automática con `-allowProvisioningUpdates` y la llave de `asc`. No frenes por la ausencia de un certificado «Apple Distribution» en `security find-identity`: la firma de distribución es automática, administrada en la nube con la llave de App Store Connect. `BLOQUEANTE:` solo si el archive, el export o la subida fallan de verdad.

En el mismo PR o lote, actualiza la regla «TestFlight solo desde la Mini» en `CLAUDE.md` (línea 11) y en `docs/FLUJO-RAMAS-Y-HOTFIX.md` (línea 35) para que diga que se sube desde la Mini o la Max. Decisión de Jürgen, 10-nov 2026 (clave t1514u): la Max quedó habilitada para subir a TestFlight, igual que la Mini.

 Card «Build final de 2.2 a TestFlight». Base: `origin/2.2` en jur211296/Yala, ya con el lote de cierre 2.2 y la de Entrar con Google mergeados (verifícalo; si alguno no se mergeó, súbela igual con lo que hay y anótalo). Una sola sesión, un cierre. Sube el número de build, archiva y sube a TestFlight igual que en la subida 2.2 anterior, con los dSYM a Sentry. Deja las notas de prueba en español neutro latinoamericano. No envíes a revisión de App Store: eso lo decide Jürgen después de probarla. Lleva el cambio del número de build también a 2.3 (merge o cherry-pick) si no choca.

Mueve la card a done con evidencia (número de build, estado en App Store Connect). Commits sin firma de IA.

En la Max, si otra sesión de otro proyecto ya usa un simulador, puedes abrir un segundo (tope 2) o usar el iPhone 14 conectado por DeviceMCP.

## Añadido por Frank (Jürgen, 10-nov 6:58 Lima; ajuste 10-nov 8:26 Lima)
La build debe incluir el merge de iCloud B en 2.2 (entrar con Google o Apple dejando el iCloud privado sin tocar; PR 878). La sesión de iCloud B puede cerrar dejando el PR 878 en cola de auto-merge, sin esperar el CI: eso es el proceso normal, y no significa que ya esté en 2.2. Antes de compilar, verifica que el PR 878 esté MERGED en `origin/2.2` con `gh pr view 878 --json state,autoMergeRequest`. Si está OPEN con auto-merge en cola, espera con un Monitor hasta 45 minutos a que GitHub lo mergee; luego haz `git fetch` y compila. `BLOQUEANTE:` solo si el CI falla, el auto-merge se cancela o pasan los 45 minutos.

## Cierre
Según el modo fijado al arrancar: en semiautónomo, si está completo, `/cerrar-total`; lo vital se pregunta y se espera con la sesión viva. En nocturno, lo vital va a checkpoint recuperable con card «Espera decisión» para Jürgen; si está completo, `/cerrar-total`.

## Paso 0 (Frank, 2026-11-10, Mini, semi)

- Base `origin/2.2` = merge de Entrar con Google o Apple con iCloud privado aparte (opción B), ya MERGED: entra en la build. El lote de cierre 2.2 también.
- Número de build medido con `asc builds list`: el último 2.2 era el 7 → se sube el 8.
- Checkpoint de la Max retomado: no había tocado el número de build; su PR en borrador queda obsoleto y se cierra.

## Resultado (2026-11-10 10:20 Lima)

- **Yala 2.2 (8)** subido desde la Mini con firma automática (`-allowProvisioningUpdates`). App, share y widgets en 2.2 (8). Upload `df84f7dc…` → `VALID`, `READY_FOR_BETA_TESTING`. Notas «Qué probar» en es-MX. Sin enviar a revisión.
- **Gate:** archive Release ✓, preflight sobre el archive antes de exportar ✓, build `Yala Dev` ✓, `validate-coverage` ✓, banco de versiones (8 casos) ✓.
- **dSYM:** subidos a Sentry por el post-action del archivado (app, share, widgets). Falta el de `Sentry.framework` (terceros, no bloquea).
- **2.3:** el número de build va en su propio PR, sin los textos de «Mini o Max» (ya hay otro PR de textos a 2.3).
