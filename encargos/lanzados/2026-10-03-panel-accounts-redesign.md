---
esfuerzo: high
---

# El panel de cuentas: más espacio, sheet al tocar, editar en el sheet, filtro en la toolbar

## Contexto
Ticket: `tickets/backlog/panel-accounts-redesign.md` (backlog; 2026-05-13). La wiki ya se migró. La idea, entera, es esta cita:

> mas espacio. Clic abre sheet. Editar dentro e sheet. Añadir filtro a toolbar.

No hay título, ni «por qué importa», ni notas, ni layout. Lo que esa cita no dice queda sin especificar. No se inventa producto para llenarlo: se anota en el Paso 0 como supuesto y se sigue.

Cola B, después de `account-form-as-medium-detent-sheet` (PR #341, formulario de cuenta a media altura, en cola de auto-merge a 2.1). Ese PR no se reabre ni se rehace. Siguiente tras este, no lo implementes aquí: `more-tab-missing-profile-button` → `trends-insight-card-v2-bullets` → barrido QA. Al cerrar, no lances el siguiente: Frank se lo avisa a Dan y Jürgen dice sí antes de que salga.

`accounts-need-more-visibility-in-the-ui` es otra idea (más presencia, saldo a la vista). Su ticket dice que falta decidir si es el mismo trabajo o dos. No lo absorbas.

La checklist de `cola-b-redesigns-must-hold-up-at-ipad-width` deja este ítem sin marcar y solo dice que el detalle de cuenta debería poder ir en columna en iPad. Eso no es un layout. No armes columna ni split salvo que el Paso 0 lo deje escrito como supuesto de esa línea. Si el layout cambia, se decide por size class o ancho del contenedor, nunca por tipo de aparato ni por orientación.

## Que se pide
1. Leer el ticket. El trabajo de producto es solo la cita:
   - El panel de cuentas necesita más espacio. La nota no dice cuánto, ni si es una sección más alta, una lista u otra cosa.
   - Un toque (la nota dice «clic») abre un sheet. No dice cuál ni qué muestra.
   - Editar ocurre en un sheet. No dice si es el mismo sheet del toque o el formulario que ya abre el PR #341.
   - El filtro vive en la toolbar. No dice qué filtra ni de qué pantalla es esa toolbar.
2. Implementar solo eso. Lo no dicho no se diseña de más: se declara en el Paso 0 y se construye el mínimo que deje la cita cumplida.
3. Un PR a la rama `2.1`. Gate verde. Mover el ticket cuando cumpla. Un hallazgo que no sea esta cita va a ticket propio (`--solo-crear`), no a este PR.
4. Mini, pipeline serial, un simulador a la vez:
   1. Limpiar simuladores muertos de esta sesión (prefijo `YalaLane-Adapt-`, si existen). Prohibido `shutdown all`, `erase all`, `killall Simulator` y tocar simuladores de otros carriles.
   2. `xcodebuild -jobs 2` sin ningún simulador encendido.
   3. Encender un solo simulador.
   4. Tests, y capturas si el cambio se ve.
   5. Apagar ese simulador y borrar los datos de ese device.
   DerivedData en `.ddp` del worktree. Destino por UDID, nunca por nombre genérico ni `booted`.
5. Al cerrar, dejar la Mini limpia: sim apagado, datos de ese device borrados, y el worktree fuera solo si el PR ya está mergeado. Si el PR solo está en cola de merge, el worktree se queda. No acumular devices apagados.
6. Al terminar, `/cerrar-total`. Solo después de un `/cerrar-total` exitoso se puede matar el tmux de esta sesión. Ningún otro tmux. No tocar sesiones `salud--*` ni `Insolito--*`. No tocar otros carriles.

## Que NO hay que tocar
- El formulario de cuenta del PR #341.
- `accounts-need-more-visibility-in-the-ui`, `more-tab-missing-profile-button`, `trends-insight-card-v2-bullets` y el barrido QA.
- Otros carriles, sesiones `salud--*` e `Insolito--*`, y cualquier tmux que no sea el de esta sesión.
- Marketing y clínicas.
- Secrets. Si aparece uno, anotarlo en el cierre.

## Como se sabe que esta bien
- El panel de cuentas tiene más espacio, el toque abre un sheet, la edición ocurre en un sheet y el filtro está en la toolbar, dentro de la cita y de lo que el Paso 0 dejó escrito.
- Lo que la cita no dice no se presenta como requisito: o está en el Paso 0 o no se hizo.
- PR a `2.1`, gate verde, ticket al día.
- Tras `/cerrar-total`: sim apagado, datos de ese device borrados, worktree retirado solo si el PR mergeó, y ningún tmux ajeno tocado.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs, PR a `2.1` y `/cerrar-total` sin preguntar. No hay deploy que confirmar. La nota es corta: lo no dicho se asume en el Paso 0 (opción mínima, alineada con la cita) y no queda una decisión abierta para Jürgen. Un bug o una decisión nueva que no cubra el Paso 0 va a ticket propio antes de cerrar. Solo parar ante un secreto o un acceso que de verdad sea de Jürgen.

Al terminar, `/cerrar-total`.

## Paso 0

Medido en el árbol (`a73cd1a87`): hoy tocar una tarjeta del carrusel de cuentas **filtra** el Panel por esa cuenta
(`AccountsCarouselView.swift`), y editar va por una ruedita en la esquina de la tarjeta (`AccountCardView.swift`). El
Panel no tiene filtro en la toolbar: solo bandeja, secciones y perfil (`PanelView.swift`).

Decidido por Jürgen (AskUserQuestion, 2026-10-03 18:50 Lima):

| La cita | Qué se construye |
|---|---|
| «más espacio» | **Dentro de la tarjeta.** Sin la ruedita, el nombre ocupa todo el ancho. La sección no crece (eso es `accounts-need-more-visibility-in-the-ui`). |
| «Clic abre sheet» | **Una ficha de cuenta**: icono, nombre y saldo (el mismo número que la tarjeta), con «Editar» y «Filtrar por esta cuenta». |
| «Editar dentro del sheet» | «Editar» abre el formulario de cuenta (el de #341, sin tocarlo) **encima de la ficha**. |
| «Añadir filtro a toolbar» | **La hoja de filtros completa**, la misma de Estadísticas e Informes, desde un botón en la toolbar del Panel. |

Supuestos (opción mínima; nadie los pidió como requisito):

- «Filtrar por esta cuenta» en la ficha sigue la regla del menú contextual que ya existía: solo con la cuenta sin
  filtrar y fuera del modo excluir. Quitar o excluir se hace con el chip o desde la hoja de filtros. Cero textos nuevos.
- Las cuentas de sistema (`Grupos [moneda]`) también abren la ficha, sin «Editar»: no son editables.
- El menú contextual de la tarjeta (filtrar / editar) se queda como está: la cita no lo menciona.
- Si al guardar el formulario la cuenta queda borrada o archivada, la ficha se cierra sola: ya no está en el carrusel.
- Tamaño de la ficha: media altura en ventana compacta y grande en ventana ancha, como la ficha de registro
  (`\.usesLargeSheets`, lo decide la ventana). Contenido a ancho legible (`DS.Adaptive.readableWidth`).
- iPad: **no** se arma columna ni lista-detalle. La ficha no asume ser hoja de pantalla completa y respeta el ancho
  legible, que es lo que pide la línea heredada de `cola-b-redesigns-must-hold-up-at-ipad-width`.
- El badge del botón de filtro usa el mismo conteo que Estadísticas (`filterCriteria.activeFilterCount`).

### Revisado en la sesión (Jürgen delante, 2026-10-03 tarde)

Jürgen convirtió el encargo en una sesión de diseño: pidió propuestas, eligió sobre un lienzo
(https://claude.ai/artifact/LvWp7bj43PJY1S2Rin9Cu3) y amplió el alcance a «todo lo que tenga que ver con cuentas».
Se partió en entregas; **este PR es la primera** y las demás van a tickets (`accounts-settings-list-redesign`,
`account-form-redesign`, `account-collections`). Lo que cambió respecto a la tabla de arriba:

- Tarjeta: carrusel A, blanca con acento (A2) y teñida (A3) cuando la cuenta está en el filtro; etiqueta del importe
  («Saldo» / «Por pagar» / «Gastado · período») y «≈» en otra moneda.
- La ficha es una **vista de cuenta** a media altura con lo importante arriba (saldo, entró/salió, curva del período)
  y, al subirla, en qué se fue, últimos movimientos y filtrar. «Editar» en su barra.
- Filtro: **solo en la toolbar** (Jürgen descartó la fila de píldoras, «pueden ser infinitas»).
- «Tus finanzas» se queda con ese nombre y con la salud; se va la frase de IA con su botón; el plegado se queda.
