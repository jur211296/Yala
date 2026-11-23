Yala
# Subir a TestFlight la build 7 de 2.3 y poner al día el artifact de novedades 2.3 para revisarla en el iPhone
---
toca: Yala.xcodeproj/project.pbxproj,docs/guias/novedades-2-3/,tickets/backlog/2026-11-23-subir-testflight-2-3-build-7.md,tickets/done/2026-11-23-subir-testflight-2-3-build-7.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/barrido-qa-2-3-antes-build-7, Yala/hacer-recurrente-pantalla-exito
---

Pedido de Jürgen (23-nov, 10:29 Lima): «lancemos un barrido qa y un testflight. Que el testflight además actualice el artifact que teníamos de todo lo nuevo en 2.3 para revisarlo en mi testflight». Va después del barrido de QA, para llevar sus arreglos.

## Qué se pide
1. **La build tiene que llevar TODO lo desarrollado en 2.3** (Jürgen, 23-nov 15:01: «quiero que tenga TODO lo desarrollado. Que espere y solucione lo que necesite»). Antes de archivar, comprueba: no hay PR abiertos contra 2.3 (`gh pr list --base 2.3 --state open`); no hay ninguna otra sesión de Yala viva ni encargo de Yala pendiente en la cola (`python3 ~/.claude/scripts/coordinador.py estado` y `mirar`); y no hay PR de 2.3 cerrados sin merge en las últimas 48 h con trabajo que no entró. Solo cuenta lo que cambia la app de iOS (o lo que la build lleva dentro): un PR o encargo que toca solo `Web/`, `mcp/`, `docs/` o marketing, como la mudanza de la web a Cloudflare, no se espera. Si algo de eso queda abierto, espera a que entre (con la sesión viva, revisando cada 10 minutos). Si un PR ya sin sesión está trabado por conflicto o CI, arréglalo tú para que entre. Si algo no puede entrar por una causa que no puedes resolver, sale como `BLOQUEANTE:` con link y motivo; no subas sin eso.
2. La base es `origin/2.3` al día, con todo lo anterior dentro y el CI en verde. Si el último run de 2.3 está rojo, encuentra la causa y arréglala en un PR propio contra 2.3 (o vuelve a correr el run si fue un corte o una cancelación); sube solo cuando esté verde. El tope de 45 minutos para un CI rojo ajeno no aplica a esta sesión: aquí se espera y se soluciona. Solo si el arreglo exige una decisión fuera de tu autoridad, `BLOQUEANTE:`.
3. Sube el número de build a 7 (la versión sigue en 2.3; hoy `CURRENT_PROJECT_VERSION = 6`). Archiva y sube igual que la build 6 (encargo «subir-testflight-2-3-build-6»), con los dSYM a Sentry, y distribúyela al grupo interno. No envíes a revisión de App Store: eso lo decide Jürgen.
4. Escribe las notas de prueba en español neutro latinoamericano, con lo nuevo desde la build 6, en lenguaje de usuario y sin ids ni nombres de ramas.
5. **Pon al día el artifact de novedades 2.3** (https://claude.ai/artifact/G74UBFLDowih9f2Rt5xaoS), siguiendo `docs/guias/novedades-2-3/README.md`: suma al inventario lo mergeado desde la última actualización, mueve a «listo» lo que ya llegó en la build 7, marca `nuevo_guia`/`cambio_guia`, saca capturas nuevas de lo que cambió y conserva los ids existentes para no perder las notas «me gusta / mejorar / bug» que Jürgen ya dejó. Antes de reconstruir, lee esas notas y señala en la guía cuáles quedaron resueltas. Publica sobre la misma URL si se puede; si no, una nueva, y deja el link en el README.
- Antes de usar un simulador para las capturas, verifica si el iPhone 14 (DeviceMCP, conectado a la Mini) está libre. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.

## Cómo entregar
- Un PR con el cambio de build y la guía al día, sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay un conflicto o el CI falla, arréglalo tú. Si el CI falla por algo ajeno, arréglalo también (ver punto 2); no cierres sin que la build y el PR estén dentro.
- En «Qué salió»: el número de build, el link de TestFlight o App Store Connect, las notas de prueba tal como quedaron y el link del artifact de novedades actualizado.
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión». Si fallan credenciales o firmas, no las inventes: `BLOQUEANTE:`.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones (resueltas en semi, sin pregunta vital)

- **Qué se espera antes de archivar:** solo el PR de «Hacer recurrente» con pantalla de éxito (iOS, en cola de auto-merge). El de la web a Cloudflare no se espera (solo `Web/`). Sin PR de 2.3 cerrados sin merge en 48 h. El encargo «pago planificado con logo propio» figura iniciado en la cola, pero su PR entró el 20-nov y no tiene sesión viva: no se espera.
- **Build 7:** la última de 2.3 en App Store Connect es la 6 (medido con `asc builds list`). Archivo en la Max, dentro del tmux de la sesión, con el método de la build 5 (`.asc/ExportOptions.plist`, destino upload, dSYM con el post-action de Sentry).
- **Guía de novedades:** la última versión era la de la 2.3 (2), del 16-nov. Entran los PR mergeados desde ese corte hasta la 2.3 (7): 130 candidatos, clasificados por PR; `build` de cada ítem = primera build de TestFlight que lo llevó. Los ids existentes no cambian.
- **Notas de Jürgen:** la colección `notas` del artifact está vacía (medido el 23-nov). Si dejó notas, quedaron en el navegador de su teléfono: no hay ninguna que marcar como resuelta.
- **Capturas:** en un simulador de la Max (no había ninguno encendido) con datos sembrados; el iPhone 14 está en la Mini y no hace falta.
- **Pase de estrés:** no aplica: este PR no toca UI.
