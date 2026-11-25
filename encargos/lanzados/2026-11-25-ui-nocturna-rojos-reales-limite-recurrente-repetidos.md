Yala
# UI nocturna: los tres rojos reales (Límite de tarjeta, Hacer recurrente y Quitar repetidos)
---
toca: YalaUITests/LimiteTarjeta/,YalaUITests/Flows/RecurrenteDesdeRegistroUITests.swift,YalaUITests/Flows/RecordsLote8BUITests.swift,tickets/backlog/2026-11-25-ui-nocturna-rojos-reales.md,tickets/done/2026-11-25-ui-nocturna-rojos-reales.md
esfuerzo: high
cierre: cierra-sola
---

Este es uno de los tres lotes de la UI nocturna que salieron del análisis del 25-nov (PR #1173, artifact https://claude.ai/artifact/VEcRutGkQQF6KEALVKTsAA, datos en `docs/analisis/ci-ui-rojo-2026-11-25/`). Jürgen pidió encolarlos (25-nov 7:22 Lima). Son rojos reales o probablemente reales: puede haber un bug de la app detrás.

## Qué se pide
Tres cards del tablero (2.3):
1. **tablero-limitetarjetauitests-en-rojo-las-3-noctu-esyx**: `LimiteTarjetaUITests.test_ponerCambiarYBorrarElLimite` falla 3 de 3 en las nocturnas del 23, 24 y 25-nov con «El campo no quedó vacío antes de escribir: «8»» / ««800»». La prueba nunca salió verde. Reprodúcela con la misma semilla y decide si el borrado del campo falla en la app (bug) o en la prueba (gesto de borrar). Después arréglala.
2. **tablero-hacer-recurrente-desaparece-del-detalle-3ojj**: `RecurrenteDesdeRegistroUITests`, con `test_detail_makeRecurring…` y `test_rowMenu_offersMakeRecurring…`, falla 3 de 3 en la tanda 13 sobre 15f0146 y estaba verde sobre 35d5ce4. Biseca 35d5ce4..15f0146 empezando por los commits de Recurrente y de la Bandeja. Si es un bug, el botón tiene que volver a salir para el usuario.
3. **tablero-recordslote8b-quitar-repetidos-ya-no-dic-lh2p**: `RecordsLote8BUITests.test_duplicates_removeRepeated_asksFirst_andLeavesOnePerGroup` falla 3 de 3 en la tanda 4 con «ninguna fila de un grupo de días distintos dice de qué día es». Entró el cambio del posible duplicado a ±1 día. Decide si cambió la app (bug) o si hay que actualizar la prueba.

Antes de arreglar, mira si la nocturna de anoche (25-nov) sigue en rojo. Cada arreglo nombra la causa en el commit. Ticket: crea `tickets/backlog/2026-11-25-ui-nocturna-rojos-reales.md` y, al cerrar, muévelo a `tickets/done/`.

## Cómo se sabe que está bien
Las tres pruebas pasan en local y la causa de cada una está nombrada. Si era un bug de la app, el usuario lo ve arreglado.

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

## Paso 0

- **¿Sigue rojo anoche?** La última nocturna con UI es la del 25-nov (run 45535770873 sobre 15f0146, 02:50Z). El
  schedule de las 11:16Z no corrió UI (sin cambios en `Yala/`). Se toma esa como «anoche».
- **Reproducir en local antes de tocar.** Cada prueba se corre sola, con `Yala Dev`, sobre esta rama (= 2.3 al día).
- **Bug o prueba:** se decide por el árbol y el vídeo/captura del fallo, no por el mensaje. Si es app, el arreglo va
  en el fichero mínimo de `Yala/` y se anota en «Decidido sin consultar».
- **Límite:** hipótesis inicial: `AmountInputHelper.filterAmountInput` reagrupa el texto en cada tecla («8,00» → «800»)
  y reescribe el binding; las teclas de borrar de `typeText` en ráfaga se pierden contra esa reescritura. A medir.
- **Bisección de Recurrente:** solo si no se reproduce la causa en el árbol de hoy; empezando por e751fa9a7.
- **Entrega:** un PR a 2.3 con auto-merge; sin esperar el CI (el encargo lo pide).
