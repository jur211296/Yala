# Subir TestFlight 2.2 (6) con todo lo mergeado hasta el barrido QA 2.2 (C)

Base: origin/2.2 en jur211296/Yala. Una sola sesión a la vez. Sube el build siguiente a TestFlight con el mismo procedimiento que la 2.2 (5), confirma que queda en «in qa» en App Store Connect y anota en el cierre qué trae para que Jürgen lo pruebe. Si la subida de dSYM a Sentry necesita un token en la Mini, anótalo como pendiente y no lo frenes. Card: «Subir TestFlight 2.2 (6) con lo mergeado hasta el barrido QA».

Termina con /cerrar-total.

## Paso 0 (Frank, 2026-11-03, Mini)

- **Número de build: 7, no 6.** Medido con `asc builds list --paginate` (109 builds): el 2.2 (6) ya existe — lo subió la sesión intermedia del 2-nov (VALID). El encargo dice «(6)» con la cuenta vieja; el número se mide al subir. `asc versions list`: 2.2 en `PREPARE_FOR_SUBMISSION`.
- **`origin/2.2` lleva 2.2 / 6** en los 20 targets. Este PR sube solo `CURRENT_PROJECT_VERSION` 6 → 7.
- **Qué entra:** todo lo mergeado a `2.2` desde 2.2 (6) (#749): #750–#765, hasta AnnotateKit en Yala Dev (#765). El barrido QA 2.2 (C) (#766) está en cola de auto-merge pero solo toca docs, memoria y el encargo: no cambia el binario, así que no se espera.
- **Gate:** el diff compilable es solo `project.pbxproj`. Como en los builds anteriores: archive `Yala` Release + build `Yala Dev` + `validate-coverage` + banco de versiones. Sin simulador.
- **Pase de estrés:** no aplica — esta sesión no cambia UI, solo empaqueta lo ya mergeado.
- **dSYM a Sentry:** si pide token en la Mini, queda como pendiente y no frena.

## Resultado (2026-11-03 23:25 Lima)

- **Yala 2.2 (7)** subido desde `b775ebdc6` (merge de #765) + bump 6 → 7. App, share y widgets en 2.2 (7). Upload `b5771577…` → `VALID`, `internalBuildState: IN_BETA_TESTING`. Asignado a la versión 2.2 de App Store, que sigue en `PREPARE_FOR_SUBMISSION`. Sin revisión, sin grupos, sin tocar textos ni capturas.
- **Gate:** archive `Yala` Release ✓, build `Yala Dev` ✓, `validate-coverage` ✓, banco de versiones (8 casos) ✓, preflight sobre el archive ✓. Sin simulador.
- **Ojo con el orden:** `.asc/ExportOptions.plist` tiene `destination = upload`, así que `-exportArchive` sube en el acto y el preflight corrió después de la subida (OK). La receta «export → preflight → upload» no se cumple con ese plist: o se corre el preflight sobre el `.xcarchive` antes de exportar, o el plist pasa a `export`.
- **dSYM a Sentry: pendiente.** No hay token con escritura en el Llavero (`sentry-yala`). Los dSYM de este archive están guardados en `~/Claude/entregas/subir-testflight-2-2-7/Yala-2.2-7-dSYMs.zip` (UUID de Yala `625D29AB-…`), porque recompilar da otro UUID. La export avisó además de que falta el dSYM de `Sentry.framework` (paquete binario de terceros; no bloquea).
- **Dentro, respecto a 2.2 (6):** #750–#765 — Grupos (autor del gasto, cabecera con neto y barra debes/te deben, admin en grupos migrados), fluidez (pestañas, listas, splash, duplicados), widgets (fondo con profundidad, porcentajes que suman 100 %, «Ya lo pagué» en Pagos, widget de Grupos en solo grupos), Estadísticas con textos IA automáticos para Pro, revisión de varios registros de foto y voz, venta en otra divisa, convertir a compartido desde voz e imagen, los retoques de Panel y Estadísticas de la prueba unslop-design (#761) y AnnotateKit (solo Yala Dev). El barrido QA 2.2 (C) (#766) es solo documentación y no cambia el binario.
