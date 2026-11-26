Yala
# Subir a TestFlight la build 11 de 2.3 con todo lo mergeado, notas de prueba y la guía de novedades 2.3 al día
---
toca: Yala.xcodeproj/project.pbxproj,Cloudkit Schemas/,docs/qa/testflight-2-3-11/,docs/guias/novedades-2-3/,tickets/backlog/2026-11-25-testflight-2-3-build-11.md,tickets/done/2026-11-25-testflight-2-3-build-11.md
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: no
depende: Yala/barrido-qa-2-3-antes-de-build-11
---

Pedido de Jürgen (25-nov, 21:51 Lima): «Encola otra subida a TestFlight con barrido al final de la cola, dejé el iPhone 14 disponible desbloqueado». Va después del barrido de QA de la build 11, para llevar sus arreglos.

## Contexto
- En TestFlight está la 2.3 (10) (PR #1180). Receta de subida: `docs/qa/testflight-2-3-10/`, `docs/qa/testflight-2-3-9/` y sus tickets.
- Desde la build 10 entraron los lotes de Primeros pasos (que cada paso cuente bien, guías y avisos, pulido de textos y paywall), la oferta Pro con el mes gratis dentro de «¡Primeros pasos completos!» y el mazo centrado con «Hola, <nombre>», más los arreglos del barrido previo. Lista real con `git log` desde el commit de la build 10.

## Qué se pide
1. **La build tiene que llevar TODO lo desarrollado en 2.3.** Antes de archivar, comprueba: que el PR del barrido y los de los lotes anteriores están mergeados en 2.3; que no hay PR de app abiertos contra 2.3 (`gh pr list --base 2.3 --state open`); que no hay otra sesión de Yala viva ni encargo de Yala de app pendiente en la cola (`python3 ~/.claude/scripts/coordinador.py estado` y `mirar`). Un PR o encargo que toca solo `Web/`, `mcp/`, `docs/` o marketing no se espera. Si algo de app sigue abierto, espera a que entre con la sesión viva, revisando cada 10 minutos y escribiendo avance. Si un PR ya sin sesión está trabado por conflicto, arréglalo tú para que entre. Si algo no puede entrar por una causa que no puedes resolver, `BLOQUEANTE:` con link y motivo; no subas sin eso.
2. Sube el número de build al siguiente después del 10 (lo normal es 11; confirma en App Store Connect cuál es el último). La versión sigue en 2.3.
3. Antes de archivar, comprueba con `cktool` que los esquemas de Producción de iCloud tienen todos los campos del modelo de hoy. Si falta alguno, no lo des de alta tú: es `BLOQUEANTE:` para Jürgen (el alta en Producción la hace Dan con su OK).
4. Archiva y sube con firma en la nube con la clave `.p8` de App Store Connect, como la build 10. dSYM a Sentry y distribución al grupo interno, con el iPhone 14 de Jürgen como tester interno. No envíes a revisión de App Store. Si fallan credenciales o firma, no las inventes: `BLOQUEANTE:`.
5. Notas de prueba en español neutro latinoamericano, en lenguaje de usuario y sin ids ni nombres de ramas, en `docs/qa/testflight-2-3-11/`, con lo nuevo desde la build 10 y la lista de prueba que dejó el barrido.
6. **Pon al día la guía de novedades 2.3** siguiendo `docs/guias/novedades-2-3/README.md`: suma lo mergeado desde la última actualización, mueve a «listo» lo que llega en la build 11, saca capturas nuevas de lo que cambió y conserva los ids existentes para no perder las notas de Jürgen. Publica sobre la misma URL si se puede y deja el link en el README.
- Esta vez **no** se limpia la base de desarrollo ni se reinstala Yala Dev: Jürgen no lo pidió. Para capturas puedes usar el iPhone 14 por DeviceMCP (Jürgen lo dejó desbloqueado y disponible; si otra sesión lo usa, espera) o, en la Max, un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los que enciendas.
- Build iOS en pipeline serial; al arrancar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen (nunca las de un worktree vivo). No uses `-derivedDataPath /tmp/claude-*`.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash. Ninguna espera de más de 3 min sin escribir avance.

## Qué NO hay que tocar
- Solo lo de `toca:`: número de build, esquemas `.ckdb` si cambian, docs de esta subida, guía de novedades y ticket por archivo. Ningún arreglo de código de la app: los bugs van a cards 2.3.
- Nada de producción salvo la subida a TestFlight: ni Supabase, ni CloudKit de producción, ni D1, KV o Workers. No despliegues gateway, web ni conector.

## Cómo entregar
- Un PR contra 2.3 con el cambio de build y la guía al día, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Entrega final: artifact visual de Claude que facilite decidir; no Markdown, PDF ni documento de puro texto. Número de build, qué incluye, link de TestFlight o App Store Connect, notas de prueba y link de la guía de novedades. Enlázalo en «Qué salió».
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin subir lo incompleto.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada». Español neutro latinoamericano.

## Paso 0 — decisiones (resueltas en autónomo, nocturno)

1. **El PR de la oferta Pro y el mazo centrado entra antes de archivar.** Estaba en conflicto y sin sesión viva: se mezcla `2.3` en su rama (solo chocaba el índice de tickets) y se espera su CI con el auto-merge que ya tenía.
2. **Build 11**: App Store Connect tiene la 2.3 (10) como última.
3. **iCloud sin alta pendiente**: `yala` y `yala_dev` de Producción idénticos al repo. En `groups`/`groups_dev`, Producción no tiene `SplitMember.clientCapability(At)`, que el repo sí; ningún código los usa desde julio. No bloquea y no se re-exporta.
4. **La guía de novedades va a una URL nueva desde la Max**: las dos anteriores son de otra cuenta (solo lectura aquí) y la colección `notas` estaba vacía.
5. **Capturas de la guía**: las de los lotes 2 y 3 y del barrido de la oferta y el mazo, del mismo código que la build.
6. **Sin limpieza de dev ni reinstalación de Yala Dev** (no pedido).
