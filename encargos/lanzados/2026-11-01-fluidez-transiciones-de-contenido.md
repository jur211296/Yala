---
esfuerzo: high
release: no
---
# Transiciones de contenido: el esqueleto se funde con los datos, filas que entran y se van, y cargas sin golpe

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `fluidez-transiciones-de-contenido` · Sesión cola **S35l** · al cerrar → **S35m** (`fluidez-animaciones-apagadas`).

## Contexto
Estas cards salen de la auditoría de fluidez de `fluidez-animaciones-hapticos` (PR #720), que dejó el sistema común en `.claude/rules/swiftui-ds.md` («Fluidez: el sistema común»), `DS.Animation` y `DS.Haptic`. La auditoría completa está en `docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`: usa las filas marcadas C1, C3, C7.

Regla de Jürgen (2026-10-30): todo lo que sale de una sesión entra en 2.2 antes del barrido QA, nada a backlog.

Pantallas: Panel, detalle de grupo, Registros, Grupos (gastos y liquidaciones), Presupuestos, Insights, la tarjeta de la IA y el saludo del chat.

Cards:
- `tablero ver tablero-fluidez-c1-el-esqueleto-se-funde-con-los-0qhn` — Fluidez C1: el esqueleto se funde con los datos sin duplicar botones
  - Problema: En el Panel y el detalle de grupo los datos sustituyen al esqueleto de golpe al terminar de cargar. Un fundido simple deja dos copias de la pantalla durante 0,25 s y los XCUITest que tocan en ese instante fallan con «varios elementos».
  - Hecha cuando: Esqueleto → datos con fundido en Panel y detalle de grupo, sin elementos duplicados en el árbol de accesibilidad durante el fundido, respetando Reducir movimiento; vídeo antes/después; XCUITest del Panel en verde.
- `tablero ver tablero-fluidez-c3-filas-que-entran-y-se-van-con-fb1j` — Fluidez C3: filas que entran y se van con transición, y el aviso de Deshacer
  - Problema: Borrar, deshacer o añadir una fila en Registros, Grupos (gastos y liquidaciones) y Presupuestos hace que la lista salte; el aviso de Deshacer aparece y se va en seco.
  - Hecha cuando: Inserción y borrado con transición en esas listas y el aviso de Deshacer con entrada y salida, sin romper el deshacer ni los XCUITest de borrado; vídeo.
- `tablero ver tablero-fluidez-c7-cargas-que-aparecen-de-golpe-tyh9` — Fluidez C7: cargas que aparecen de golpe
  - Problema: La lista de Grupos, Insights, la tarjeta de la IA y las sugerencias del saludo del chat pasan de ProgressView a contenido en seco; Registros puede enseñar «Sin registros» un instante antes de cargar.
  - Hecha cuando: Cada carga de la lista C7 con transición y sin el destello de vacío; vídeo.

## Qué se pide
1. Lee la auditoría (filas C1, C3, C7) y el sistema común. Resuelve cada fila con `DS.Animation`/`DS.Haptic`, respetando Reducir movimiento, sin inventar curvas ni hápticos nuevos.
2. Para cada card, cumple su «hecha cuando», con tests (unitarios, source-scan o XCUITest según la card) y vídeo o capturas antes y después en `capturas/` y en el digest.
3. Pasa las cards a «in qa» de Jürgen al abrir el PR (con `--agente` de la sesión).

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Filas de la auditoría de otras cards de Fluidez.
- La lógica de datos, la sincronización y el servidor.
- marketing/ ni Web/.
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando».
- No hay elementos duplicados en accesibilidad ni XCUITest rotos.
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge y vídeo o capturas.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 (Frank, 2026-11-01)

Decisiones tomadas antes de escribir código (modo autónomo: la conservadora en cada una).

1. **C1, cómo se funde sin duplicar.** El esqueleto y los datos siguen siendo dos ramas (`if/else`), así que los datos
   se montan de nuevo al cargar, como hoy. Cambia solo la salida del esqueleto: se queda encima (`zIndex(1)`) y se
   funde, y desde el primer fotograma de su salida deja de existir para la accesibilidad y para los toques
   (`LoadingExitTransition`). Los datos entran debajo sin fundido, ya opacos. Así durante los 0,25 s hay una sola copia
   en el árbol. Descartado: una sola rama con `.redacted` condicional (dejaría de remontar el contenido al cargar y
   cambiaría cuándo corren sus `onAppear` y cuándo rueda la cifra del hero).
2. **C3, qué cambio de filas se anima.** Solo una edición pequeña: de 1 a 3 filas que entran o se van, con el resto en
   el mismo orden (`RowListEditLogic`). Cambiar de filtro o de período sigue en seco: animar una lista entera de
   cientos de filas es más tirón que fluidez. Listas: Registros (lista principal), Grupos (gastos y las dos listas de
   liquidaciones), Presupuestos.
3. **C3, el aviso de Deshacer.** Es una `UIWindow` aparte, fuera de la `TabView`: entra subiendo y fundiéndose
   (SwiftUI en su propia ventana) y se va fundiéndose (UIKit), sin accesibilidad ni toques durante la salida. Con
   Reducir movimiento, en seco como hoy.
4. **C3, hápticos que la fila de la auditoría pide.** Deshacer un borrado (y saltar un pago) → `success()`, desde el
   aviso; borrar un gasto o quitar un saldo inicial de un grupo → `warning()` en el ViewModel, solo si salió bien. Los
   avisos cuyo botón no deshace («Ver», «Editar», «Mover a la vista de grupo») no vibran.
5. **C7, el destello de «Sin registros».** `RecordsViewModel` apunta si ya filtró una vez; antes, la lista no enseña
   el vacío. Las cargas (Grupos, Insights, las cinco tarjetas de IA de Estadísticas, las sugerencias de los dos saludos
   del chat) se funden con la misma salida que el esqueleto.
6. **Curvas y Reducir movimiento.** Todo con `DS.Animation.appear` y `reduceMotion ? nil :`, implícito
   (`.animation(_:value:)`) porque todo menos el aviso vive dentro de una pestaña. Sin curvas ni hápticos nuevos.
7. **Tests.** Unit de `RowListEditLogic`; source-scan de cada sitio en `TabImplicitAnimationsWiringTests` y uno nuevo
   para la salida que se oculta; XCUITest que cuenta las copias de un botón del Panel mientras se funde el esqueleto.
