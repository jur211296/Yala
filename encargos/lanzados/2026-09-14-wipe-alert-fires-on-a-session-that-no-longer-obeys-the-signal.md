# Implementar ticket: wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal

## Contexto
Una más antes de la pausa por cambio de cuenta Claude. Tras #157/#161: en móvil prestado/solo-grupos, cuando el dueño vacía, sale «Datos no disponibles — Tus datos fueron eliminados de iCloud» y «Empezar de cero» expulsa al onboarding. No son sus datos.

## Decisión de Jürgen (2026-09-14)
**(1) Callar el alert** cuando la sesión no obedece la señal de wipe. No mostrar ese aviso en esa celda. Queda sabido el riesgo: un hueco real de CloudKit en esa celda también se callaría — documentarlo en el ticket/PR.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank. Device-QA → `tickets/qa/` si aplica.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.

No lances el siguiente: cola en pausa tras este. No marketing/.

## Que se pide
1. Leer ticket + ContentView wipeGraceTask / ShellDataAlertsModifier / decisión shouldProcess.
2. Implementar (1): sesión que no obedece la señal no muestra el alert ni el botón que expulsa.
3. Criterios del ticket; PR a `2.1`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. (2) otro texto / (3) dejarlo. Wipe de prod.

## Como se sabe que esta bien
Criterios del ticket; tests; PR mergeado; `/cerrar-total`.

## Paso 0 — árbol de decisiones (autónomo, 2026-09-14)

La decisión de producto ya venía dada (callar). Lo que faltaba por resolver es **con qué predicado**,
**en qué instante** y **qué queda sin cubrir**. Seis nodos, todos medidos contra el árbol de esta rama.

### N1 · ¿Qué predicado decide «esta sesión no obedece la señal»? → el que ya existe

`DestructiveScopeLogic.wipeSignalObeyedByThisSession(confirmedPrivateSession:storageMode:)`. **No se
crea uno nuevo.** Las tres superficies responden la MISMA pregunta —«¿los datos de este teléfono son
los del Apple ID?»— y el docblock del propio predicado ya explica por qué sus dos mitades delegan en
vez de copiarse: dos predicados que «siempre van juntos» divergen en el commit siguiente, y la
divergencia es silenciosa. Un tercero para el aviso tendría el mismo destino.

**El signo del error coincide, y eso es lo que permite reusarlo.** En el emisor y en el receptor,
equivocarse hacia `true` BORRA. Aquí, equivocarse hacia `true` afirma un hecho falso sobre datos
ajenos y ofrece un botón que expulsa al onboarding. Los tres quieren el mismo default seguro: ante
la marca ausente, `false`. Por eso la entrada es `confirmedPrivateSession()` y no `hasPrivateSession()`.

### N2 · ¿El guard a t=0 (antes de arrancar la gracia) o a t=5 (antes de encender)? → t=5

Va **dentro de la `Task`, inmediatamente antes de `showRemoteWipeAlert = true`**, que es el único
escritor de ese flag en todo `Yala/`. Dos razones:

1. El aviso afirma un hecho sobre AHORA («tus datos fueron eliminados»), así que el eje se lee en el
   instante en que se va a afirmar, no cinco segundos antes.
2. El guard vive dentro del escritor. A t=0 quedaría un escritor sin guard y una condición a
   distancia — la forma exacta del defecto que este ticket cierra (la compensación de
   `handleRemoteWipeSignal` vive DESPUÉS de su propio `guard`).

### N3 · ¿Se retira además el botón destructivo? → no hace falta, y por eso no se toca

Medido: el alert tiene **un único call-site** en producción (`ShellDataAlertsModifier`, las cuatro
claves `icloud.remoteWipe.*` no se usan en ningún otro sitio). Callar el alert deja el botón
inalcanzable para esa población. Rediseñar el cuerpo del alert sería la opción (2), que Jürgen
descartó. Alcance mínimo.

### N4 · ¿Qué se calla de más, y se acepta? → sí, con nombre

Con el eje apagado también se calla **un hueco transitorio real de CloudKit** en esa celda. Jürgen lo
dio por sabido. Lo que pierde esa persona es un aviso informativo: los datos vuelven cuando vuelven, y
el botón que se pierde con él es el genérico de degradación que el ticket ya describe como peor que el
orquestado. Queda escrito en el docblock del guard, en el ticket y en el PR.

### N5 · ¿Qué residual hereda del eje? → dos, los dos ya con ticket

- **Solo-grupos anterior al 2026-09-10**: el backfill les escribe `hasPrivateSession = true`, así que
  el eje da `true` y **el aviso les sigue saliendo**. Es el mismo residual que ya gobierna el borrado
  (`remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark`); ahora gobierna también este
  aviso, y se anota allí.
- **Ventana del cutover** (sesión privada con `storageMode == .cloud` y el espejo todavía vivo): el
  eje da `false` y el aviso se calla en una celda donde sería legítimo. Mismo proxy, mismo ticket
  (`storage-mode-is-a-proxy-for-the-mirror-in-the-wipe-signal`); se anota allí.

Ninguno de los dos se arregla aquí: los dos se cierran cambiando el EJE, y el eje es compartido — un
parche local al aviso lo haría divergir del borrado, que es justo lo que N1 evita.

### N6 · ¿Qué red lo sostiene? → source-scan de sentencia completa + el conteo del eje

El camino no es invocable (`onChange` de una `View` privada) y no hay seam de uitest que provoque la
caída de `hasPersonalData` — el mismo hueco que ya registra `remote-wipe-receiver-has-no-behaviour-test`.
Así que la red es la que el repo ya usa para los otros dos extremos: un scan que fija la **sentencia
entera** (comparación por igualdad, no `contains`: un `|| loQueSea` colgado del final reabriría el bug
en verde) y el conteo de lecturas de la estricta en todo `Yala/`, que sube de 5 a 6 a conciencia.
