Yala
# Mejoras necesarias 2.3 · Grupos: saldos que se contradicen y lectura con VoiceOver
card: tablero-mejoras-necesarias-2-3-grupos-saldos-que-pl00
toca: Yala/App/Views/Groups/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 06 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/37-grupos/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/856 https://github.com/jur211296/Yala/pull/857.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. Saldos dice «Tú no le debes nada a nadie» encima de «Tú pagas a Ana S/ 40.00» (problema 1 A4 de la zona 37; GroupBalancesView).
2. La tarjeta de deuda dice «Beto paga a Tú» (ticket group-debt-card-reads-pays-to-tu).
3. ¿Quién puso más?: las barras pasan por encima de los nombres también a tamaño normal y la tuya dice Lucía y no Tú (ticket group-stats-who-paid-most-bars-cover-the-names).
4. VoiceOver lee el importe del gasto como 0.00 y la moneda y las filas de pago sin su dato (problema 5 E4 de la zona 37).
5. ¡Están al día! sale también en un grupo recién creado sin ningún gasto (GroupBalancesView.swift:69-76).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Punto 1: la frase tiene que ser verdad con «Menos pagos» encendido y apagado; no cambies el valor por defecto de «Menos pagos» (A1 queda para Jürgen).
- Punto 4: comprobación con VoiceOver en el iPhone 14 en el guion de QA; no bloquea el merge.
- El vocabulario de saldar y los nombres del puente siguen sin decidir: no los toques.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones (resueltas en autónomo, modo semi)

- **Precondición.** `origin/2.3..origin/2.2` = 16 commits: el arreglo de restos del puente en la Bandeja y docs; ninguno toca `Views/Groups` ni las vistas del lote. El merge corto de 2.2 en 2.3 ya entró. Se sigue. La rama nació de 2.2 y se recreó sobre `origin/2.3`.
- **Los 5 puntos siguen vivos en 2.3** y 2.2 no tiene arreglo pendiente de ninguno (`git log origin/2.3..origin/2.2` vacío en las vistas).
- **P1.** La cifra grande no cambia (es la misma en Gastos y en Saldos, decisión 3A). Cambia solo la frase: cuando en alguna moneda debes Y te deben a la vez (pasa con «Menos pagos» apagado), dice «Te deben X y tú debes Y.», con las sumas de las tarjetas de debajo. Con «Menos pagos» encendido eso no pasa y la frase sigue igual. Se aplica en Saldos y en la cifra de Gastos, que lleva la misma frase. El caption no cambia. «Menos pagos» no se toca.
- **P2.** «Beto · paga a · Tú» pasa a «Beto · te paga», sin el avatar de «Tú» detrás (texto de la alternativa A4). VoiceOver: «Beto te paga: S/ 40.00». 16 idiomas.
- **P3.** «¿Quién puso más?» deja Swift Charts y pasa a filas propias: nombre arriba, barra debajo con el importe al final, sin alto fijo. Tu fila dice «Tú». El alto del carrusel de «Todas» se mide en vez de estimarse con 44 pt fijos por persona, para que no corte con texto grande.
- **P4.** El importe del gasto y el del pago llevan nombre («Importe del gasto», «Importe del pago») y el valor con la moneda escrita, o «sin importe». El selector de moneda del pago lleva nombre. Las filas de «Pagos» se leen en una frase: «Beto te pagó S/ 10.00, 10 nov 2026. Confirmada.». La comprobación con VoiceOver en el iPhone queda en el guion.
- **P5.** Saldos de un grupo sin gastos ni pagos dice «Sin gastos» (el texto de la pestaña Gastos, icono de recibo) y no «¡Están al día!». Un grupo con todo saldado sigue diciendo «¡Están al día!».
- **Tests.** Unit para la lógica pura de los puntos 1, 2, 4 y 5 y el nombre del punto 3; XCUITest nuevo con semilla propia (`-uitest-seed-group-cross-debts`: «Piso compartido» con deudas cruzadas y tu nombre «Lucía», y «Grupo sin gastos»). Rojo sin el arreglo, comprobado.
- **Choque con el PR abierto del lote 01 de Grupos** (toca `GroupDetailView`, `SettlementFormView`, `L10n.swift`): mis cambios en esos ficheros van en líneas lejanas a las suyas; los textos nuevos en un fichero propio de `L10n`.

### Añadido tras el gate (2026-11-11) — P1, el rótulo

Con «Menos pagos» apagado y el neto en cero (debes S/ 40 a Ana y Beto te debe S/ 40), el rótulo gris decía «Estás a
mano en este grupo» encima de «Tú pagas a Ana». Es la misma contradicción que el punto 1, un renglón más arriba. Se
decide sin preguntar (menor y reversible): rótulo propio, «En este grupo te deben lo mismo que debes», solo en el
detalle del grupo y solo con deudas cruzadas. Sin cruce, «Estás a mano» sigue siendo verdad y no cambia.
