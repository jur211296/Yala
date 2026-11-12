---
esfuerzo: high
release: no
---
# Fluidez de toda la app: animaciones, transiciones y vibraciones

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `fluidez-animaciones-hapticos` · Sesión cola **S35e** · al cerrar → **S36** (`barrido-qa-2-2-b`).

## Contexto
Jürgen (2026-10-30, TestFlight 2.2 (5)): faltan muchas animaciones, vibraciones y transiciones y la app se siente tosca. Ejemplo claro: en Grupos, al cambiar de pestaña a Gráficas o Saldos, primero cambia el chip y un segundo después la página cambia de golpe. Quiere que se sienta fluida y moderna. Antecedente: S27p ya decidió las animaciones «caso por caso» (opción B) y respeta Reducir movimiento; esto es la pasada completa.

Cards:
- `tablero ver tablero-fluidez-de-toda-la-app-animaciones-trans-pjum`

## Qué se pide
1. Diagnostica primero el caso de Grupos (chip y página desincronizados: probablemente carga o estado que se resuelve tarde, no solo falta de animación) y arréglalo para que chip y contenido cambien juntos, con una transición suave e inmediata.
2. Auditoría vista por vista (Panel, Registros, Bandeja, Grupos, Estadísticas, Presupuestos, Yala IA, Ajustes, onboarding, sheets y formularios) en iPhone y Duo: cambios de pestaña y segmento, aparición de listas y tarjetas, inserción y borrado de filas, números que cambian, guardar, borrar y deshacer, apertura de sheets, estados vacíos y de carga. Deja la tabla en `docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`.
3. Crea o completa un sistema común (curvas y duraciones estándar, `contentTransition(.numericText())`, `matchedGeometryEffect` donde aporte, `sensoryFeedback` para hápticos: selección, éxito, aviso y borrado), documéntalo en `.claude/rules/swiftui-ds.md` y aplícalo en todas las vistas. Todo respeta Reducir movimiento.
4. Sin parpadeos ni saltos: nada de contenido que aparece de golpe después de un retraso.
5. Videos o capturas antes/después de los casos clave en `capturas/`.
Si el alcance no entra en una sesión, implementa lo de más impacto y crea cards para el resto: TODAS en versión 2.2, estado «ready to launch», `cierra-sola`, asignadas a frank (nunca backlog ni otra versión; regla de Jürgen 2026-10-30). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Lógica de datos (solo presentación y feedback). Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 (2026-10-31, Frank, auto-contestado: MODO AUTÓNOMO)

1. **Causa del caso de Grupos.** Medida en el código antes de tocar nada: el desfase es de diseño, no de carga.
   `NavigationChipButton.switchTab` (card yc6k) anima primero la fila de chips (0,25 s) y monta la pestaña al terminar,
   sin animación. Eso es exactamente «primero el chip y después la página de golpe». En el iPhone se suma el bloqueo de
   montar Saldos o Estadísticas. → Se mide en vídeo el «antes» y se rehace el cambio para que chip y página cambien en
   el mismo movimiento, sin volver al salto de un fotograma que yc6k arregló.
2. **Sistema común: se completa el que hay, no se crea otro.** Ya existen `DS.Animation` (duraciones) y `DS.Haptic`
   (116 usos). Se añaden las curvas con nombre y el mapa de hápticos (selección, éxito, aviso, borrado), y se
   documenta en `.claude/rules/swiftui-ds.md`. Sin renombrar los 116 usos (refactor no pedido).
3. **El apagado de animaciones de `ContentView` se queda** (decisión 1yhi, opción B): se anima caso por caso con
   `.animation(_:value:)` y cada sitio nuevo entra en `TabImplicitAnimationsWiringTests`.
4. **Alcance.** Una sesión no cubre las diez áreas. Se implementa lo de más impacto (Grupos, cambios de chip de las
   cuatro pantallas con fila de chips, hápticos que faltan en guardar y borrar, números que cambian en los heros) y el
   resto va a cards 2.2 «ready to launch», `cierra-sola`, asignadas a frank.
5. **Reducir movimiento**: toda animación nueva pasa por el mismo camino (`nil` con Reducir movimiento). Los hápticos
   no dependen de Reducir movimiento (los gobierna el ajuste de vibraciones del sistema).
6. **Duo**: la auditoría lo cubre por código (los cambios no dependen del tamaño); las capturas se hacen en el
   iPhone 17 Pro. Conducir el Duo no funciona con axe/XcodeBuildMCP (regla del repo).
7. **QA en dispositivo**: la sensación de los hápticos y la fluidez a 120 Hz solo se ven en el iPhone → la card va a
   «in qa» de Jürgen con guion.
