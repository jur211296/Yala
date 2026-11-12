---
esfuerzo: medium
release: no
---
# Panel: «Últimos registros» sin hueco ni título propio; el (?) junto al chevron

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `panel-ultimos-registros-sin-hueco` · Sesión cola **S35c** · al cerrar → **S35d** (`nuevo-gasto-grupos-propuestas`).

## Contexto
Jürgen (2026-10-30): al quitar el doble «Últimos registros» quedó una tabla con un hueco vacío encima. La tabla va sin título propio y sin hueco, empezando en la primera fila, y el (?) pasa a la fila «Últimos registros», antes del chevron.

Cards:
- `tablero ver tablero-panel-ultimos-registros-sin-hueco-arriba-gisw`

## Qué se pide
1. Quita el hueco y el título de la tabla; mueve el (?) a la fila de título, antes del chevron.
2. Revisa iPhone, iPad y Duo y los modos de uso.
3. Capturas antes/después en `capturas/`.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
El resto del Panel. Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0

Decisiones, auto-contestadas (MODO AUTÓNOMO, opción conservadora):

- **Dónde va el «?»**: en la fila del título de la sección (`PanelSection`, slot nuevo `titleAccessory`), entre el título y el chevron. Solo lo usa «Últimos registros»; las demás secciones no cambian.
- **La tarjeta sin cabecera**: con `showsTitle: false` el widget ya no pinta fila de cabecera; empieza en la primera fila (o en el estado vacío). La vista previa de la hoja de ayuda conserva su cabecera con título.
- **Misma ayuda**: el «?» es el mismo `WidgetInfoButton(kind: .recentRecords)` con el VM del Panel; si «Mostrar ayudas» está apagado, no se pinta, como antes.
- **Duo**: el runtime 27.1 no está instalado en la Mini (~45 min de descarga). La fila es un `HStack` sin ramas por ancho, igual en todas las formas; se revisó en iPhone 17 Pro y iPad Pro 13 y el Duo queda para el QA de Jürgen si quiere mirarlo.
- **Modos de uso**: en «Solo grupos» no hay Panel; en «Solo gastos» la sección es la misma vista. Sin cambio por modo.
- **Test**: caso nuevo en `PanelDashboardUITests` que fija la posición del «?» antes del chevron y que abre la ayuda; comprobado con mutante.
