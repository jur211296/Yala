---
esfuerzo: medium
release: no
---
# Grupos: implementar el hero elegido por Jürgen y quitar la barra de búsqueda

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `grupos-hero-implementar` · Sesión cola **S29e** · al cerrar → **S30** (`editar-cuenta-doble-linea`).

## Contexto
Jürgen eligió el diseño del hero de Grupos (2026-10-30 20:15) tras ver las 3 propuestas de `docs/disenos/grupos-rediseno-2-2/` (PR #703). Lee la nota de la card: ahí está la decisión exacta.

Cards:
- `tablero ver tablero-grupos-implementar-el-hero-elegido-por-j-y29x`

## Qué se pide
1. Implementa el hero y las filas según la decisión: sin naranja («debes» rosa o rojo según el tema, «te deben» verde), sin «En tus grupos», «‹ Debes» y «› Te deben» en neutro con fuente ligera y los montos debajo con el tamaño de la propuesta 3 (o un poco menos) en fuente regular, y el chip del neto de la propuesta 1 en morado, sin ícono o centrado verticalmente (si lleva ícono, uno de tip o info). Solo Yala completo lleva el chip del neto; revisa también Yala gratis.
2. Filas de grupo con nombre y color semántico, máximo 3 más «y N más», primero lo que debes (ver la card del hero y el README de las propuestas).
3. Quita la barra de búsqueda de Grupos (ya está la búsqueda en la Tab bar) y asegura que no vuelva el salto del resumen al entrar: el test del PR #703 sigue verde.
4. Capturas antes/después en todos los temas (Claro, Oscuro, Liquid Glass, Rosa) y en Yala gratis, en `capturas/`.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
La lógica de saldos (solo presentación). Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, Frank, 2026-10-30)

1. **Solo la lista de Grupos.** El hero del detalle de un grupo (`GroupBalanceHero`, «En este grupo te deben») no cambia:
   la decisión habla del resumen de la lista.
2. **Hero:** «↗ Debes» y «↙ Te deben» (flechas `arrow.up.right` / `arrow.down.left` de la propuesta 2) en gris, fuente
   ligera; debajo, los montos de cada lado unidos con « + », en `title2` regular (22 pt: «el tamaño de la propuesta 3 o
   un poco menos»). Primero lo que debes. Un lado vacío no se pinta; sin nada pendiente queda el «¡Están al día!» de hoy.
   Fuera «En tus grupos».
3. **Colores:** dos tokens nuevos, `Color.groupOweAmount` (rosa rojizo #BE123C en claro, #FB7185 en oscuro) y
   `Color.groupOwedAmount` (verde #15803D / #4ADE80), con su test AA sobre fondo y tarjeta de los diez temas. Sin naranja.
4. **Chip del neto:** el de la propuesta 1, a lo ancho, en cristal teñido de morado, **sin ícono** (la opción más simple de
   las dos que dio Jürgen). Solo en Yala completo (`!isGroupsFocusedShell`: es donde se elige moneda principal) y solo si
   hay algo pendiente. Neto = lo que te deben − lo que debes, convertido a la moneda principal con los tipos de cambio de
   la app; con tasa no exacta, el monto sale como aproximado. Neto 0: texto neutro. Lógica aislada y con tests.
5. **Filas:** las de la propuesta 1 (la recomendada y de la que sale el chip): cabecera del grupo y una fila por persona,
   «Le debes a Maria P.» / «Maria P. te debe» a la izquierda y el monto en color a la derecha. Primero lo que debes,
   luego lo que te deben, cada lado de mayor a menor; máximo 3 y «y N más». Se reusan los textos ya traducidos
   `groups.card.youOwe` / `theyOweYou`; los chips de estado (pendiente, rechazado, movido) no cambian.
6. **Buscador:** fuera el `.searchable` de la lista y el `searchText`/`filteredGroups` que solo lo servían. Sin cajón no
   hay alto que plegar: `GroupsSearchDrawerWiringTests` pasa a fijar que Grupos no tiene buscador y sigue prohibiendo el
   `.automatic` en todas las vistas.
7. **Regla «En Grupos los montos no llevan color»** de `swiftui-ds.md`: se sustituye por la de esta decisión.
8. **Yala gratis** = shell de solo grupos: mismo hero y filas, sin chip.
