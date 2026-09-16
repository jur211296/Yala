# Aviso fijo en Grupos cuando el teléfono no puede sincronizar (veredicto Attest terminal)

## Contexto
Ticket: `tickets/backlog/groups-tab-does-not-say-this-phone-cannot-sync-groups.md`.
Ya mergeados en 2.1: #173 (veredicto terminal + salida con pérdida confirmada de cambios de grupos) y #175 (mismo patrón honesto en nube personal). El veredicto `GroupsAttestStreakStore.isTerminal` existe y lo leen cierres/desasociar/salir de grupo, pero la pestaña Grupos no dice nada hasta que la persona intenta uno de esos gestos.

Decisión Jürgen (2026-09-15), opción 1: aviso fijo en la pestaña Grupos mientras el veredicto sea terminal. Mismo texto que el aviso honesto de la nube («Este teléfono no puede sincronizar tus grupos»), y qué puede hacer la persona.

Hora Lima: diurno (antes de 21:00). Puedes usar AskUserQuestion si hace falta una decisión de producto o acceso de Jürgen. Si es menor, elige lo recomendado y documenta.

## Que se pide
1. Mientras `GroupsAttestStreakStore.isTerminal` (o el equivalente canónico del veredicto terminal de grupos), mostrar un aviso fijo en la pestaña Grupos.
2. Copy alineado con el aviso honesto de la nube personal (#175): «Este teléfono no puede sincronizar tus grupos» + qué puede hacer (p. ej. usar otro teléfono, exportar si aplica, no esperar que los cambios lleguen).
3. Que desaparezca cuando el veredicto deje de ser terminal (si algún día hay recuperación) o no aparezca si nunca lo es.
4. Tests / preview según el estilo del repo; no inventar banner personal si no está en scope — este ticket es Grupos.
5. Al terminar: gate, commit, actualizar `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1 si el gate pasa, `/cerrar-total`. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. No sync al Kanban/store del panel.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Solo parar ante decisión/acceso real (AskUserQuestion de día). UI tests del CI son advisory.

## Que NO hay que tocar
- marketing/
- No reabrir #173/#175 salvo reutilizar el copy/patrón
- No sync tickets al store/Kanban del centro de mando

## Como se sabe que esta bien
Con veredicto terminal: la pestaña Grupos muestra el aviso fijo con el texto honesto. Sin veredicto terminal: no hay aviso. Board del repo al día y sesión cerrada con `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo a reclasificar, build a reintentar, ni ruido de CI advisory.

---

## Paso 0 — el árbol de decisiones, resuelto antes de escribir

Jürgen decidió el QUÉ (opción 1: aviso fijo, copy del #173). Lo demás se auto-contestó. Cada decisión lleva lo
descartado, que es la mitad que evita rehacerla.

| # | Decisión | Por qué, y qué se descartó |
|---|---|---|
| **D1** | **Cuatro condiciones**, no «mientras el veredicto sea terminal» | El enunciado literal deja el aviso MINTIENDO a tres poblaciones: sin sesión, sin Grupos compilado y sin consent. La racha describe al TELÉFONO —sobrevive al cierre de sesión y desde el #175 la escribe también el motor personal, que no sube gastos de grupo. **Descartado:** el veredicto solo. |
| **D2** | El canal por **`groupsBackendCompiledCapability`**, no por el getter compuesto | El compuesto es fail-closed ante un snapshot de remote-config ausente: un teléfono restaurado desde iCloud se quedaba SIN aviso en su primer arranque, con el cierre de sesión enseñándoselo. Mismo criterio que los cuatro teardowns de `CloudSignOutFlowLogic.path`, y su docblock ya lo tenía escrito. **Descartado:** el compuesto (era lo que había hasta la review). |
| **D3** | **Solo el veredicto en `@State`**; sesión, canal y consent vivos en el body | Congelarlos dejaba dos huecos: iniciar sesión desde el CTA no sacaba el aviso (ese sheet se cierra en sitio, sin `onAppear`) y una sesión que el SDK borra en caliente lo dejaba puesto. **Descartado:** los cuatro en `@State`. |
| **D4** | **El escritor avisa** (`GroupsAttestStreakStore.didChangeNotification`) | `isTerminal()` lee `UserDefaults`, que no repinta. Medido: con la racha escrita un segundo después del arranque, el aviso no salía hasta salir del tab y volver. **Descartados:** sondear con un timer (gasto sin señal) y `UserDefaults.didChangeNotification` (se dispara con cualquier key, y en cualquier hilo). |
| **D5** | **Sin X y sin botón** | Describe un estado que sigue ahí después de leerlo, y no hay acción que lo arregle desde este teléfono. **Descartado:** descartable como el banner de re-entrada, y un botón «Reintentar» —reintentar es lo que lleva un día fallando. |
| **D6** | **Título reusado** del #173, cuerpo nuevo | Una avería, un nombre. **Descartado:** copy propio, que daría dos vocabularios para un solo fallo. |
| **D7** | El copy ofrece **usar otro teléfono**, no exportar | En la nube personal el #175 exporta un CSV; en Grupos no hay export equivalente y prometerlo sería inventar una feature. |
| **D8** | Tercer `safeAreaInset`, el **más arriba** | De los tres avisos del tab es el único que no caduca solo ni se descarta. Medido: los tres son insets apilados, ninguno tapa a otro. |
| **D9** | El seam de QA **escribe la racha por el camino de producción** | Un seam que forzara `isTerminal = true` dejaría ciegos a los cuatro casos XCUITest (`.claude/rules/testing.md`). Los tres relojes están en el borde exacto del intervalo de conteo, y un test lo fija. |
| **D10** | Bajo uitest, la racha **entera** va a una suite propia | No está en `removeUserPreferenceKeys` a propósito, así que `-uitest-reset` no la borra: una corrida dejaba el veredicto terminal puesto para todo arranque MANUAL y para el host de unit tests. **Descartado:** purgar solo en el `else` del seam —cubre al seam, no a los clientes. |
| **D11** | **es-AR en voseo** | El fichero es voseo 167 a 34. La clave nueva nace bien aunque el resto tenga su ticket abierto. |
| **D12** | El ticket cierra en **`done`**, sin device-QA | El aviso es visual y determinista; los cuatro casos XCUITest lo cubren en simulador. No hay nada que exija un dispositivo real. |
