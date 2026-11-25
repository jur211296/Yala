Yala
# Barrido QA y subida a TestFlight 2.3 con lo de hoy
---
toca: Yala.xcodeproj/project.pbxproj,docs/qa/barrido-2-3-antes-build-9/,docs/qa/testflight-2-3-9/,docs/guias/novedades-2-3/,YalaTests/BarridoQA23AntesBuild9/,tickets/backlog/2026-11-24-barrido-y-testflight-2-3-build-9.md,tickets/done/2026-11-24-barrido-y-testflight-2-3-build-9.md
esfuerzo: high
cierre: cierra-sola
depende: Yala/bandeja-casar-con-planificados, Yala/bugs-barrido-build-8
---

Pedido de Jürgen (24-nov, 19:32 Lima): «Mete otra sesión de test flight después de todo lo que tenemos en cola ahorita, para ver si cuando despierto tengo la nueva versión con todos los ajustes que hemos hecho hoy». Va al final de la cola de Yala, después de los cuatro lotes de la Bandeja sin duplicados y de los bugs del barrido de la build 8. Es un solo encargo: primero un barrido de QA rápido y después la subida. Regla dura: siempre hay barrido de QA justo antes de cada TestFlight.

## Contexto
- Hoy está en TestFlight la 2.3 (8) (encargo «subir-testflight-2-3-build-8», PR #1162; en `origin/2.3`, `CURRENT_PROJECT_VERSION = 8`). Esta sesión sube la **build 9**.
- Lo mergeado desde la build 8 incluye, entre otros: el conector de IA con ver la Bandeja y referencia (PR #1164), el paso 3 de Gmail en Correo del banco que busca solo y confirma con el enlace (PR #1163), el aviso de duplicado de la Bandeja a ±1 día (PR #1165), los lotes de la Bandeja sin duplicados entre fuentes (emparejador, unir al llegar, fila con fuentes, casar con planificados) y los bugs del barrido de la build 8. Lista real: `git log` desde el commit «chore(release): Yala 2.3 (8)».
- Listas base del barrido: `docs/qa/barrido-2-3-antes-build-8/` (y los barridos anteriores de `docs/qa/barrido-2-3-*`). Receta de subida: igual que la build 8 (`tickets/done/2026-11-24-subir-testflight-2-3-build-8.md`, `docs/qa/testflight-2-3-8/`).

## Qué se pide
1. **Al arrancar, y otra vez justo antes de compilar, pon al día 2.3** (`git fetch` + `git pull`/rebase sobre `origin/2.3`). Si el pull se frena por cambios locales que no son tuyos ni urgentes, `git stash` y sigue; anótalo. La build tiene que llevar todo lo mergeado en 2.3 hasta ese momento. Antes de archivar, comprueba con `gh pr list --base 2.3 --state open` que no queden PR de la app abiertos de las sesiones de hoy; si alguno sigue en auto-merge con el CI corriendo, espera a que entre (revisa cada 10 min, avisando avance). Un PR que toca solo `Web/`, `mcp/`, `gateway/`, `docs/` o marketing no se espera. Si uno ya sin sesión está trabado por conflicto o CI, arréglalo para que entre.
2. **Barrido de QA rápido** de la 2.3 con foco en lo mergeado desde la build 8: Bandeja (duplicados entre fuentes, unir, Separar, casar con planificados), Correo del banco paso 3 de Gmail, conector de IA y los arreglos del barrido de la build 8. Claro y oscuro, texto grande y girado en lo nuevo; las cifras de Panel, Flujo de caja y widget deben coincidir.
   - El QA de iPhone se hace en el **iPhone 14 real por DeviceMCP** (conectado a la Mini). Si está ocupado, espera avisando avance. En la Max puedes usar un segundo simulador además del de otra sesión (para iPad o Duo); en la Mini, uno solo.
   - Ante un fallo grave, primero lo mides contra la versión publicada. Si es **bloqueante para subir**: en modo nocturno no asumas respuestas; deja checkpoint recuperable y una card «Espera decisión» para Jürgen, y no subas. Si **no es bloqueante**: crea una card de bug de 2.3 (prioridad alta, cierre autónomo) y sube igual. Lo chico se arregla en este PR solo si el archivo no está en el `toca` de otra sesión viva o pendiente; anótalo en «Saltado o asumido sin preguntar».
   - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue. Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo. Ninguna espera de más de 3 min sin escribir avance. Antes de compilar mira la carga: si otra sesión compila con xcodebuild en la misma máquina, espera en tramos cortos con aviso.
3. **Subida**: con el CI de 2.3 en verde (si el último run está rojo, encuentra la causa y arréglala en un PR propio contra 2.3, o vuelve a correr el run si fue un corte), sube el número de build a 9 (versión sigue en 2.3), archiva y sube a TestFlight como la build 8, con firma en la nube con la clave `.p8` de App Store Connect, en la Mini o en la Max (las dos están habilitadas). dSYM a Sentry y distribución al grupo interno. No envíes a revisión de App Store. Si fallan credenciales o firmas, no las inventes: `BLOQUEANTE:`.
4. Notas de prueba en español neutro latinoamericano, con lo nuevo desde la build 8, en lenguaje de usuario, sin ids ni ramas, en `docs/qa/testflight-2-3-9/`. Pon al día la guía de novedades 2.3 (`docs/guias/novedades-2-3/README.md`) con lo que llegó en la build 9, conservando los ids existentes.
- DerivedData y cachés de XcodeBuildMCP: al arrancar y al cerrar borra el DerivedData de esta sesión y las cachés de worktrees que ya no existen, sin preguntar. Pipeline serial: build con `xcodebuild -jobs 2` sin simulador booteado, luego un simulador, pruebas y apagarlo. No uses `-derivedDataPath /tmp/claude-*`.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Qué NO hay que tocar
- Nada fuera del `toca` salvo arreglos chicos imprescindibles (anotados). No `Localizable.strings` (textos nuevos en su tabla propia de cada `.lproj`). No envíes a revisión de App Store ni despliegues gateway ni web.

## Cómo entregar
- Un PR contra 2.3, sin firma de IA en commits ni PR. Deja el auto merge activado y cierra sin esperar al CI.
- **Entregable visual:** artifact de Claude con el número de build subido, lo que incluye (lo mergeado desde la build 8), los hallazgos del barrido con capturas y la lista corta de qué probar en el iPhone. Link en «Qué salió».
- En «Qué salió»: el número de build subido, el link de TestFlight o App Store Connect, las notas de prueba tal como quedaron y el link del artifact.
- Cierre según el modo fijado al arrancar: en nocturno, si está completo, `/cerrar-total`; si queda algo vital, checkpoint sin mergear ni subir lo incompleto y card «Espera decisión». En semi, lo vital se pregunta con la sesión viva. Siempre con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada». Al cerrar, apaga y borra los simuladores que usaste.

## Paso 0 — decisiones (resueltas en autónomo, nocturno)

- **Base**: `origin/2.3` al arrancar (merge de la fila con fuentes de la Bandeja). Abierto con auto-merge y CI en
  curso: el lote 4 de la Bandeja (casar con planificados). Se espera a que entre antes de archivar y el barrido lo
  incluye.
- **Máquina y aparatos**: Mini. iPhone 14 por cable para el barrido (Yala Dev en `Debug-Dev`, semillas `-uitest-*`); el
  iPhone 17 Pro simulado solo para las pruebas de interfaz de lo nuevo. Un simulador a la vez.
- **Qué se barre**: lo mergeado desde la build 8 en la app (Bandeja: aviso ±1 día, unir al llegar y Separar, fila con
  fuentes, «¿Es el mismo gasto?», «Ya registrado», casar con planificados; Correo del banco paso 3 de Gmail; los cinco
  arreglos del barrido de la build 8) y las cifras Panel = Flujo de caja = widget. El conector de IA es solo servidor:
  en la app no hay nada que probar.
- **Fallo grave**: se mide contra la 2.3 (8). Bloqueante → checkpoint nocturno y no se sube. No bloqueante → card de
  bug 2.3 y se sube.
- **Subida**: build 9, versión 2.3, archivo en la Mini dentro del tmux de la sesión, firma automática con la llave de
  `asc`, como la build 8. dSYM a Sentry y grupo interno. Sin revisión de App Store.
- **Pase de estrés**: este PR no toca interfaz; se hace sobre lo nuevo de la Bandeja (texto al máximo, oscuro) dentro
  del barrido.
