---
toca: YalaTests/, YalaUITests/, Yala.xcodeproj/, scripts/, docs/, qa/, CLAUDE.md
esfuerzo: high
release: no
---
Yala
# Dejar 2.2 completa en verde y subirla a TestFlight

Pedido de Jürgen, 10-nov 10:46 Lima (clave t1517u): una sesión deja mergeados en 2.2 todos los PR abiertos contra 2.2 (esperando el CI o arreglándolo) y luego sube la build a TestFlight, con prioridad sobre los lotes 2.3.

Modo semiautónomo. Trabajo completo: cierra con `/cerrar-total`. Commits y PR sin firma de IA.

## Contexto

La subida `subir-testflight-2-2-final-reintento` ya terminó: dejó en TestFlight la build 2.2 (8) y el PR 886 (auto-merge, a las 10:47 Lima el job `tests` seguía en curso). Esa build no incluye aún todo lo abierto contra 2.2, en especial el 863. Esta sesión no la sustituye en la cola: cierra lo que falte en 2.2 y sube la build siguiente.

Lista de PR abiertos contra `2.2` al encolar (10-nov ~10:47 Lima), medida con `gh pr list --base 2.2 --state open`. Vuelve a listarlos al arrancar, por si cambió algo.

1. [PR 863](https://github.com/jur211296/Yala/pull/863) — Grupos: limpia el borrador «Elige cuenta» y el «Préstamo a grupos» repetido. Auto-merge activo (MERGE). El 9-nov falló el job `tests` (pruebas de unirse a grupo, `Logic.step` / failedPhase). Jürgen relanzó los jobs fallidos a las 10:45 Lima; a las 10:47 el job `tests` seguía en curso. Empieza por este.
2. [PR 886](https://github.com/jur211296/Yala/pull/886) — TestFlight 2.2 (8), candidata para App Store (bump de build 7→8 y la regla de subida desde Mini o Max). Auto-merge activo (MERGE). A las 10:47 Lima, `tests` en curso; el resto de QA en verde.
3. [PR 881](https://github.com/jur211296/Yala/pull/881) — docs: la subida a TestFlight se puede hacer desde la Mini o desde la Max. Sin auto-merge. CI en verde (varios jobs de test en SKIPPED, propio de un cambio solo de docs). El 886 ya puede traer el mismo cambio de textos: si al actualizar está vacío o ya entró por el 886, anótalo y no dupliques.
4. [PR 874](https://github.com/jur211296/Yala/pull/874) — informe del QA físico de la 2.2 en el iPhone 14 (docs, sin código). Sin auto-merge. CI en verde.

El PR 613 («Conectar Gmail» mínimo) está abierto, pero su base es 2.3, no 2.2: no entra en esta ronda. Si aparece otro PR abierto contra 2.2, trátalo con las mismas reglas.

## Qué se pide

Para cada PR abierto contra 2.2, empezando por el 863 y siguiendo con el resto:

1. Ponte al día sobre `origin/2.2` (actualiza o rebase el PR).
2. ESPERA el CI. Aquí sí, por pedido explícito de Jürgen: no lo des por bueno ni lo mergees en rojo.
3. Si el CI falla: diagnostica. Si es flaky, relanza esa corrida una sola vez. Si es un fallo real, arréglalo en ese mismo PR, empuja y espera el CI otra vez.
4. Cuando esté verde, mergea (merge commit, no squash ni rebase, salvo que el PR ya tenga otro método acordado y en curso).
5. Un PR que no deba entrar en 2.2 —borrador, o que diga «NO mergear en 2.2», como el de Gmail mínimo (613) si apareciera con base 2.2— se salta y se anota en el cierre, con el motivo.

Cuando 2.2 tenga dentro todo lo que debía entrar y el CI de `origin/2.2` esté verde, sube a TestFlight la build siguiente (hoy la última publicada es la 8; será la 9 si no ha subido otra). Si el CI de 2.2 queda rojo tras un merge, arréglalo antes de subir.

La subida va desde la Mini o la Max: las dos sirven. Usa el mismo método que en la Mini: firma automática con `-allowProvisioningUpdates` y la llave de `asc`. No frenes por la ausencia de un certificado «Apple Distribution» en `security find-identity`. Archiva y exporta dentro del tmux de la sesión (por `ssh` directo el llavero no abre). Sube el número de build, archiva, sube a TestFlight con los dSYM a Sentry y deja las notas de prueba en español neutro latinoamericano. No envíes a revisión de App Store. Lleva el cambio del número de build también a 2.3 (PR propio o cherry-pick) si no choca.

En la Max, si otra sesión de otro proyecto ya usa un simulador, puedes abrir un segundo (tope 2) o usar el iPhone 14 conectado por DeviceMCP. En la Mini el tope es 1.

## Sobre el `toca:`

Jürgen (10-nov 12:50 Lima) pidió achicar el `toca:` para que esta sesión corra en paralelo con los lotes 2.3: trabajas sobre las ramas de los PR de 2.2 y los lotes 2.3 van en sus propias ramas, así que no se pisan. Si un arreglo de CI necesita tocar código de la app fuera de estas carpetas (por ejemplo `Yala/App/...` en el 863), hazlo igual dentro del PR de 2.2; anótalo en el cierre.

## Qué NO hay que tocar

- marketing/ ni 1.0.
- Los lotes de 2.3 que no sean el acompañamiento del número de build.
- No envíes la build a revisión de App Store.
- Commits y PR sin firma de IA.

## Cómo se sabe que está bien

- Entrega: el enlace de la build en TestFlight y la lista de PR mergeados o saltados (con el motivo de cada salto).
- 2.2 en verde con esos PR dentro; build nueva en TestFlight, lista para que Jürgen la pruebe.

## Cierre

Modo semiautónomo. Si está completo, cierra con `/cerrar-total`. Si aparece algo vital, pregúntalo y espera con la sesión viva. `BLOQUEANTE:` solo ante algo vital (fuerza mayor, seguridad, o un diseño que si no se define puede ser problemático). Lo menor y reversible lo decides tú.

En el resumen de cierre incluye, además del orden habitual (Necesita de ti, Cambiado, Encontrado):

- Decidido sin consultar (o «Nada»).
- Saltado o asumido sin preguntar (o «Nada»), con el motivo.

## Paso 0 (Frank, 2026-11-10, Max, semi)

- PR abiertos contra 2.2 al arrancar: 863, 881 y 874. El 886 ya estaba mergeado. El 613 (Gmail) sigue con base 2.3: fuera.
- 863: el rojo de `tests` no era flaky (cayó igual en las tres vueltas del reintento): el escáner «MUTACIÓN (e)» no conocía la semilla nueva `DevSeedGroupBridgeLeftovers.swift`. Se añade a la lista por el mismo criterio que las otras semillas (`#if DEBUG` entero, `isBackendGroup = true`). Además chocaba con 2.2 en los 16 catálogos y en el índice de la memoria: claves añadidas por los dos lados, se quedan las dos.
- 881: la redacción «Mini o Max» ya había entrado por el 886. No se duplica: el PR se rehace sobre 2.2 con solo el aviso del tmux al archivar.
- 874: solo docs; se pone al día con `update-branch` y se espera su CI.
- Build: la última 2.2 en App Store Connect es la 8 → se sube la 9.

## Resultado (2026-11-10 16:15 Lima)

- Mergeados en 2.2: 881 (aviso del tmux), 874 (informe del QA físico) y 863 (Grupos repetidos, por su auto-merge con el CI en verde). CI de 2.2 tras el último merge: verde.
- **Yala 2.2 (9)** subida desde la Max con firma automática. App, compartir y widgets en 2.2 (9). Procesada `VALID`, en pruebas internas. Notas «Qué probar» en es-MX.
- dSYM de app, compartir y widgets subidos a Sentry por el post-action del archivado. Falta el de `Sentry.framework` (terceros, no bloquea), igual que en la 8.
- Decisiones del 10-nov registradas a mano en `docs/DECISIONS.md`: `decisiones.py` no existe en la Max.
