Yala
# UI nocturna y CI: cuelgues de 10 min, cuarentena para la UI y CI de PR de 67 min
---
toca: .github/workflows/qa.yml,qa/cuarentena.json,qa/scripts/,YalaUITests/Flows/IAGuiadosUITests.swift,YalaUITests/Flows/FirstExpensePracticeAlertUITests.swift,YalaUITests/Flows/GroupExpenseSuccessUITests.swift,YalaUITests/Flows/TransactionFormDecided02UITests.swift,YalaUITests/Flows/VozFotoAvisos23UITests.swift,tickets/backlog/2026-11-25-ui-nocturna-cuelgues-cuarentena-ci.md,tickets/done/2026-11-25-ui-nocturna-cuelgues-cuarentena-ci.md
esfuerzo: high
cierre: cierra-sola
---

Este es uno de los tres lotes de la UI nocturna que salieron del análisis del 25-nov (PR #1173, artifact https://claude.ai/artifact/VEcRutGkQQF6KEALVKTsAA, datos en `docs/analisis/ci-ui-rojo-2026-11-25/`). Jürgen pidió encolarlos (25-nov 7:22 Lima). Este lote es de infraestructura de pruebas y CI.

## Qué se pide
Tres cards del tablero (2.3):
1. **tablero-cuelgues-de-10-min-en-la-ui-nocturna-5-p-nzbh**: desde el 22-nov, 5 XCUITest pasaron el tope de 10 min por prueba: IAGuiados (cuenta paso a paso), FirstExpensePracticeAlert, GroupExpenseSuccess, TransactionFormDecided02 (transferencia) y VozFotoAvisos23. Ninguno se repite, así que el patrón parece del runner. Lee el .xcresult de los cinco, encuentra el paso donde se queda (espera de app inactiva, alerta del sistema) y ponle remedio: bajar el tope por prueba, o un reintento propio del cuelgue que no pinte la tanda.
2. **tablero-cuarentena-tambien-para-la-ui-nocturna-u-h29j**: hoy `qa/cuarentena.json` solo lo leen los unit. Extiende la cuarentena al job `ui`: la prueba corre y su rojo se cuenta aparte, con dueño y fecha de salida, como en los unit. Lo hecho: una prueba en cuarentena falla, la tanda sale verde y el rojo sale listado aparte en el aviso. Deja el formato documentado: el lote de intermitentes (`ui-nocturna-intermitentes-esperas`) va después y puede poner pruebas en cuarentena.
3. **tablero-el-ci-de-un-pr-con-codigo-tarda-67-min-d-8gzy**: mide en qué paso se van los minutos (cola de macOS, build, unit) en los runs de PR de esta semana con `gh`, y aplica el recorte mayor si es seguro y cabe en `qa.yml`. Si no cabe, deja la causa documentada y una card con la propuesta. La meta es una mediana por debajo de 40 min.

No re-ejecutes runs completos solo para medir. Ticket: crea `tickets/backlog/2026-11-25-ui-nocturna-cuelgues-cuarentena-ci.md` y, al cerrar, muévelo a `tickets/done/`.

## Cómo se sabe que está bien
Los cuelgues tienen su causa y su remedio. La cuarentena de UI funciona con una prueba de ejemplo (en un run de rama o en un test del script). El tiempo del CI de PR está medido por paso y tiene su recorte o su propuesta.

## Presupuesto de pruebas de interfaz
- Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
- Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
- Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
- Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva); nada de bucles de 10 min ni comandos que se pasen del límite y queden en segundo plano a ciegas.
- Antes de compilar en iOS mira la carga: si otra sesión compila con xcodebuild en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.
- Simulador: el iPhone 14 por DeviceMCP. Un segundo simulador solo si estás en la Max. Pipeline serial: limpiar, compilar con `xcodebuild -jobs 2` sin simulador encendido, encender uno, probar y apagarlo. Al cerrar, apaga y borra los simuladores que usaste, tu DerivedData y las cachés de XcodeBuildMCP de worktrees retirados, sin preguntar.

## Qué NO hay que tocar
- Nada fuera de `toca:`. Nunca `Yala/` entero, `YalaUITests/` entero, `Yala/Resources` ni `tickets/` entero.
- Si el arreglo exige un archivo de la app o un helper compartido fuera de `toca:`, tócalo de forma mínima y anótalo en «Decidido sin consultar».

## Cómo entregar
- Un PR contra 2.3, sin firma de IA. Deja el auto-merge activado y cierra; no esperes al CI.
- **Entregable visual:** artifact público de Claude con cada prueba (antes rojo o intermitente, causa, arreglo, evidencia). El link va en «Qué salió».
- Mueve cada card del tablero que cierres a done, con `tablero mover <id> --a done --agente frank` y una nota de la causa.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones (resueltas en semi por Frank, 25-nov; ninguna es vital)

Medido antes de decidir: logs de las tandas de UI de las nocturnas del 22 al 25-nov (no suben `.xcresult`: no hay artefacto) y los tiempos por paso de los 63 runs de PR verdes con código del 19 al 25-nov.

1. **Causa de los cuelgues.** En los cinco, a partir de un toque la app deja de avisar que está quieta («App animations complete notification not received»): cada acción espera 60 s, a veces dos veces, y el caso agota los 10 min. Pasa en 11 casos distintos en 4 noches, siempre en formularios con teclado o chat, y nunca se repite. **`-retry-tests-on-failure` no reintenta un caso cortado por tiempo**: xcodebuild reinicia el runner y sigue con el resto, así que el caso queda rojo y pinta la tanda.
2. **Remedio: reintento propio del cuelgue, no bajar el tope.** Bajar los 10 min no evita el rojo (lo adelanta) y el caso verde más lento medido sin esperas va a 444 s. Un paso nuevo por tanda relanza una vez, en su propio xcodebuild, solo los casos cortados por tiempo (como mucho 3); si pasan, cuentan como «rescate de cuelgue» y la tanda no se pinta. Los cinco ficheros de prueba no se tocan: el fallo no es suyo.
3. **Cuarentena de UI: misma lista, mismo formato.** `qa/cuarentena.json`, leída de `origin/2.3`; un nombre que empieza por `YalaUITests/` vale para la UI. El rojo final de una prueba en cuarentena no pinta la tanda y sale aparte en el aviso, con dueño y días. Sin modo `bloquear` para la UI: es advisory.
4. **Veredicto en un script con banco** (`ci-ui-veredicto.sh` + test con logs de mentira), salidas `uiq_N` por tanda para el aviso.
5. **CI de PR: el recorte mayor es el build** (~29 min de 66 de mediana aunque la caché se restaura). Hipótesis: el checkout deja todas las fechas nuevas y Swift recompila todo. Se verifica en local con dos commits de 2.3; si se confirma, fechas por contenido tras el checkout en el job `build`. Si no, card con la propuesta. La cola de macOS (12,6 min de mediana, 50-110 de noche por la nocturna) queda documentada y propuesta, no se toca.
6. **La regla `ci-qa.md`** está fuera de `toca:`: se edita lo mínimo para documentar la cuarentena de UI y las fechas por contenido (anotado en «Decidido sin consultar»).
