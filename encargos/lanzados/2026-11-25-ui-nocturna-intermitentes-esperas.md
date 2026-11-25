Yala
# UI nocturna: cuatro pruebas intermitentes (Restablecer del Panel, convertir a grupo, cambiar subcategoría y chip del año pasado)
---
toca: YalaUITests/Flows/PanelSectionsConfigResetUITests.swift,YalaUITests/Flows/PersonalToGroupConversionUITests.swift,YalaUITests/Flows/RecordsLote8UITests.swift,YalaUITests/Flows/UXAudit22Lote11y16UITests.swift,qa/cuarentena.json,tickets/backlog/2026-11-25-ui-nocturna-intermitentes.md,tickets/done/2026-11-25-ui-nocturna-intermitentes.md
esfuerzo: high
cierre: cierra-sola
depende: Yala/ui-nocturna-cuelgues-cuarentena-ci-pr
---

Este es uno de los tres lotes de la UI nocturna que salieron del análisis del 25-nov (PR #1173, artifact https://claude.ai/artifact/VEcRutGkQQF6KEALVKTsAA, datos en `docs/analisis/ci-ui-rojo-2026-11-25/`). Jürgen pidió encolarlos (25-nov 7:22 Lima). Son intermitentes: fallan y pasan sin cambios de código. Este lote va después del de cuarentena para la UI (`ui-nocturna-cuelgues-cuarentena-ci-pr`), porque los dos tocan `qa/cuarentena.json`.

## Qué se pide
Cuatro cards del tablero (2.3). Estabiliza cada prueba esperando el elemento concreto, no el contenedor ni un tiempo fijo, y revisando el estado que deja la prueba anterior. Si una no queda estable de inmediato, ponla en cuarentena con dueño y fecha de salida, con el formato que dejó el lote anterior.
1. **tablero-panelsectionsconfigresetuitests-intermit-6lx6**: `test_reset_asksFirst_cancelKeepsTheOrder_andConfirmRestoresIt` salió en rojo 4 noches de 27, con timeout al buscar la alerta de «Restablecer». Ya hubo un arreglo el 22-nov y volvió a fallar. Espera la alerta por su identificador y sin animación.
2. **tablero-personaltogroupconversionuitests-intermi-9zq1**: `test_convertingTheBus_toAGroup` y `test_cancellingTheReview_changesNothing` fallan con «El detalle no ofrece «Editar»». Revisa la espera del botón Editar en la hoja.
3. **tablero-recordslote8uitests-intermitente-el-menu-qvzz**: `test_changeSubcategory_marksTheCurrent_andUndoesFromTheNotice` dice que el menú contextual no está listo. Espera la opción, no el menú.
4. **tablero-uxaudit22lote11y16-el-chip-del-ano-pasad-sdlu**: `test_statistics_picksTheComparisonWithTheTwoChips`: el toque al chip llega antes de que Estadísticas termine de recalcular. Espera a que el chip esté quieto y se pueda elegir. Revisa también si el Resumen opción B del 24-nov cambió el tiempo de carga.

Corre cada prueba varias veces seguidas en local (por ejemplo 5) para dar evidencia de estabilidad. Ticket: crea `tickets/backlog/2026-11-25-ui-nocturna-intermitentes.md` y, al cerrar, muévelo a `tickets/done/`.

## Cómo se sabe que está bien
Las cuatro pruebas pasan en repeticiones locales seguidas, o quedan en cuarentena con dueño y fecha y el motivo anotado.

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

## Paso 0 — decisiones

> Resueltas en autónomo (modo semi, decisiones menores y reversibles): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (datos de `docs/analisis/ci-ui-rojo-2026-11-25/` y `git`):

- **Restablecer del Panel:** 3 de sus 4 rojos fueron el arrastre («El arrastre no subió Planificación…»), no la alerta. El último rojo (22-nov) corrió sobre un commit SIN el arreglo de ese día; las nocturnas del 23, 24 y 25-nov, ya con el arreglo, no lo tienen en rojo. El «volvió a fallar» del encargo no se sostiene con los datos.
- **Cambiar subcategoría:** rojos los días 10, 13 y 25-nov. El 10 y el 25 dicen «el menú no ofrece cambiar la categoría»: esos días la semilla `minimal` pone una transferencia arriba de Registros, y a una transferencia el menú no le ofrece cambiar categoría (`RecordContextActionLogic`: subcategoría de sistema). Misma causa que encontró hoy el lote hermano (rojos reales) en otras dos pruebas. No es un menú «no listo».
- **Convertir a grupo:** rojos el 22, 23 y 24-nov con «El detalle no ofrece «Editar»», ya con el arreglo del 22-nov puesto (toque con la fila quieta + segundo toque).
- **Chip del año pasado:** rojo 3/3 solo el 25-nov, primera nocturna con «Resumen opción B» y la memoria de páginas de Estadísticas (24-nov).

**D1 · ¿Dónde se reproduce?** → en el simulador iPhone 17 Pro de la Mini, con `sim-lock`, no en el iPhone 14 por Device MCP.
Por qué: el CI corre en simulador y el gate también lo necesita; un XCUITest en el teléfono no reproduce el runner. Alternativa descartada: iPhone 14 (otra plataforma, firma, y no es lo que falla).

**D2 · Cambiar subcategoría: ¿esperar el menú o cambiar de fila?** → elegir el primer GASTO de la lista (molde del lote hermano, por la etiqueta de accesibilidad) y subir a 10 s la espera de la hoja (rojo del 13-nov).
Por qué: la causa es el dato del día, no el tiempo; esperar más no lo arregla. Alternativa descartada: «espera la opción, no el menú», que ya era lo que hacía la prueba.

**D3 · Restablecer del Panel: ¿qué se toca si el rojo ya no está?** → endurecer solo la espera de la alerta (por su título, que es su identificador en XCUITest, y por su botón), sin seam nuevo de «sin animación».
Por qué: los botones de una `.alert` no llevan identificador al árbol (swiftui-ds.md) y apagar animaciones exige un argumento nuevo en la app, fuera de `toca:` y para un rojo que ya no aparece. Alternativa descartada: seam en la app.

**D4 · Convertir a grupo y chip del año pasado** → se decide tras reproducir en local; si no queda estable en las repeticiones, cuarentena con dueño `frank`, ticket de este lote, entrada 2026-11-25 y motivo, en el formato del PR de cuarentena para la UI.
Por qué: el encargo lo pide así y no hay que adivinar la causa sin verla.

**D5 · Si `qa/cuarentena.json` hace falta y el PR de cuarentena para la UI aún no entró** → rebase sobre `2.3` antes de tocarlo; si sigue sin entrar, se añade la entrada con el formato de su diff y el merge resuelve.
Por qué: el encargo declara `depende:` de ese PR y está en cola de auto-merge.
