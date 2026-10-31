---
esfuerzo: medium
release: no
---
# El banner de deshacer vuelve abajo sin tapar el «+» ni la barra

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `banner-deshacer-abajo` · Sesión cola **S34** · al cerrar → **S34b** (`formularios-modelo-borrado-b`).

## Contexto
El banner pequeño para deshacer acciones se movió de abajo porque tapaba el «+» flotante, pero ahora queda en medio de la pantalla y se ve feo. Jürgen (2026-10-30) quiere devolverlo abajo, sin tapar el «+» (p. ej. encima del flotante o con el espacio correcto según la barra).

Cards:
- `tablero ver tablero-el-banner-de-deshacer-vuelve-abajo-hoy-f-d3qq`

## Qué se pide
1. Busca dónde se posiciona el banner de deshacer (git log del cambio que lo subió) y devuélvelo abajo, con el espacio correcto respecto al flotante y a la barra de pestañas.
2. Revisa todas las vistas donde sale (con y sin «+», con y sin barra) e iPad.
3. Capturas en simulador de cada vista en `capturas/`.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
El comportamiento del deshacer (solo posición). Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas antes/después en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos: el aviso es una `UIWindow` propia (`DraftDiscardUndoNotice`) que no sabe qué pantalla tiene debajo. El 28-oct (`09be65e92`) su hueco inferior pasó de 72 pt a 72 + la pila entera de Yala IA y «+» (164 pt) en TODAS las pantallas; donde no hay flotantes queda a media altura. Todos los flotantes («+», Yala IA, `CircularPlusFAB`, `ExpandableFAB`) van abajo a la derecha con el mismo margen (`Spacing.xl` a la derecha, `Spacing.xxl` abajo).

**D1 · ¿Dónde va?** → Abajo, a la altura a la que se veía antes del 28-oct: justo encima de la barra, en todas las pantallas y centrado a lo ancho. Jürgen aprobó la captura del Panel con esa altura.
Por qué: Jürgen, en vivo (2026-10-31): «no es necesario que no tape el "+", no importa, solo que regrese abajo donde habitualmente salen este tipo de avisos». Alternativa descartada: dejarle libre la columna del «+» (era mi primera propuesta; él la retiró).

**D2 · ¿Y la decisión A del 22-oct (aviso por encima de los flotantes)?** → Queda revocada por esa frase. El caso `TransactionFormDecided02UITests.test_afterThreeRecords_thePlusTakesTheFirstTapWithTheNoticeVisible`, que la fijaba, se reescribe para afirmar lo nuevo.

**D3 · Lo que no cambia** → el plazo, el «Deshacer», ⌘Z y que abrir el menú del «+» retire el aviso de guardado. Solo posición.

**D4 · Verificación** → XCUITest nuevo `UndoNoticePlacementUITests` (Panel, Registros, Bandeja): el aviso acaba abajo y no se mete en la barra; capturas antes/después de esas tres y del iPad.

**D5 · La franja invisible (salió al medir, contestada por Jürgen: «Arreglar la franja»)** → La ventana del aviso pasa a ocupar la escena y solo recoge los toques que caen en la cápsula; el resto llega a la app.
Por qué: medido con XCUITest, la ventana era una franja de 60 pt (y 708–768 en el iPhone 17 Pro) que tapaba el «+» entero, mientras la cápsula se pintaba 36 pt más abajo (744–796): el «+» no respondía ni donde se veía, y la mitad de abajo de «Deshacer» caía fuera de su ventana. Con la ventana a pantalla completa el hueco ya no sale de esa franja: se mide desde el área segura y vale 44 pt, que deja la cápsula donde se veía. Alternativa descartada: dejarlo como estaba.
