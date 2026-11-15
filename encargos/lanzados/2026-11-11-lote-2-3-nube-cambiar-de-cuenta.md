Yala
# Decidido 9-nov 2.3 · Nube: «Cambiar de cuenta» sin saltarse las consecuencias
card: tablero-2-3-nube-cambiar-de-cuenta-sin-saltarse-izvv
toca: Yala/App/Views/Settings/, Yala/Services/CloudSync/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 55 (G1). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/41-nube-almacenamiento/ficha.md. La diferencia entre las dos opciones de la hoja (decisión 59) no está en los 69 de este barrido; si al llegar ves que sigue solo en un párrafo, corrígela en este mismo PR (cada opción con su consecuencia bajo el botón y, arriba, lo que pasa igual en los dos casos), tras verificar en el código qué hace cada una con los gastos pagados.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. «Desasociar» deja de ser el botón más llamativo, encima de la acción. Opción G1: la cuenta en una fila bajo el estado («Apple · correo · la usan tus grupos») con enlace «Cambiar de cuenta»; el bloqueo ofrece esa salida como botón y abre la hoja de consecuencias de siempre, que no se salta nunca.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Review adversarial: soltar o cambiar la cuenta mueve datos. Nunca saltes la hoja de consecuencias.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0

Medido al arrancar (2026-11-11): `origin/2.3..origin/2.2` = 0 commits; la rama parte de `origin/2.3`. `git log origin/2.3..origin/2.2` sobre las vistas tocadas: vacío. G1 sigue vivo: «Desasociar» naranja en `GroupsAssociationSection`, entre el estado y «Activar la nube»; el bloqueo solo ofrece «Entendido». La hoja de soltar es un `confirmationDialog` con un párrafo: la decisión 59 entra en este PR.

Qué hace cada salida con los gastos pagados (leído en `GroupsAssociationDetach.action`): «Dejar lo que pagué» suelta los punteros de las patas reales (quedan como registros normales) y borra las virtuales (lo que te deben o debes); «Quitar también» borra las dos. En los dos casos los grupos salen del dispositivo y siguen en la cuenta, y la sesión de esa cuenta se cierra.

Decisiones:
1. La fila de cuenta (G1) sustituye a la tarjeta solo donde se ofrece soltar (`.associated`, `.associatedNeedsSignIn`); «Asociar», «misma cuenta» y «a medias» quedan como están. «Entrar con esa cuenta» sigue bajo la fila en `.associatedNeedsSignIn`.
2. «Cambiar de cuenta» abre una hoja nueva (no globo) con lo común arriba y cada salida con su consecuencia debajo (decisión 59). Sin auto-continuar a la elección de cuenta: tras soltar, la persona vuelve a «Activar la nube» (asumido; la maqueta decía «después elegirás…», no se promete nada que no pase solo).
3. El bloqueo ofrece «Cambiar de cuenta» donde hoy es un callejón que manda a «Grupos»: `accountHasPersonalData` y `anotherGroupsAccountAssociated` sin «Usar otra cuenta», y `sessionFromBeforeFreshStart`; y solo si la sección puede soltar en ese momento. Cadena: el bloqueo se cierra y su `onDismiss` pide la hoja a la sección (un solo anchor).
4. Los textos que mandaban a «desasociar en «Grupos»» pasan a nombrar «Cambiar de cuenta» (la tarjeta «Grupos» ya no existe en ese estado). 16 idiomas.
5. Test: lógica pura del bloqueo + XCUITest de la fila y de la cadena bloqueo → hoja → cancelar sin soltar.
