# Despertar el loop de Grupos al volver a primer plano (cortar backoff)

## Contexto
Ticket: `tickets/backlog/groups-loop-in-backoff-ignores-the-return-to-foreground.md`.
Decisión Jürgen (2026-09-15), opción 1: **despertar el loop al volver a primer plano** — cortar el sueño del backoff y ciclar ya, como el runtime personal. No dejar solo el siguiente reintento.

Hoy `startIfEligible(foreground)` no interrumpe un loop vivo en backoff; el personal sí cancela el sueño en `handleBecameActive`.

Justo en 2.1: #176–#178 (avisos Attest + copy de cierre sin red). No reabrirlos salvo reutilizar patrones.

## NOCHE (Lima, después de 21:00)
Elige lo recomendado sin AskUserQuestion. Si la decisión es demasiado importante, aparca el ticket y avisa a Frank.

## Que se pide
1. Al volver a primer plano con loop en backoff: cortar el sueño y ciclar ya (espejo del runtime personal).
2. No romper el caso en que el loop no debería arrancar (`shouldStart` / elegibilidad).
3. Tests según estilo del repo.
4. Gate, commit, `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1 si gate OK, `/cerrar-total`. Bugs nuevos → ticket antes. No sync Kanban/store.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/`/cerrar-total` sin preguntar. Solo parar ante decisión/acceso real (noche: aparca). UI tests CI advisory.

## Que NO
marketing/; no reopen #176–#178 salvo patrón.

## Como se sabe que esta bien
Tras fallo pasajero + volver a primer plano: el loop no espera el backoff completo; cicla ya. Board al día + `/cerrar-total`.

## Avisos al bot dueño (Frank)
Webhook local Mini (URL/key en fichero local, no en git) cuando: (1) decisión producto/acceso; (2) PR/preview listo; (3) `/cerrar-total` con resumen usuario; (4) sin siguiente paso — una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones (resueltas en autónomo, bypass: noche de Lima, nadie delante)

1. **Dónde vive el despertar: dentro de `startIfEligible` o en una llamada aparte desde `AppBootstrapper`.**
   → **Dentro**, en el `else` del guard de `shouldStart`. Un call-site futuro no puede olvidarse de despertar,
   y el post-sign-in lo hereda gratis. El bootstrapper solo cambia su comentario, que decía «no-op».

2. **Cómo se corta el sueño: re-arrancar el loop (molde literal del personal) o cortar el sueño del loop vivo.**
   → **Cortar el sueño.** Re-arrancar exigiría matar y recrear el `loopTask`, y en este canal eso pasa por
   `purgeQueuedSplitGroupTombstones` + `rehydrateOutboxFromMirror`, que son redes de BOOT: correrlas en cada
   foreground puede re-insertar filas del espejo. El personal no tiene ese problema porque su re-arranque no
   arrastra esas redes.

3. **El sueño en tarea aparte pierde la cancelación del loop. ¿Se acepta el riesgo o se propaga?**
   → **Se propaga** con `withTaskCancellationHandler`. Sin él, `stopLoop()` —cinco caminos de cierre de
   sesión— esperaría el backoff entero. Va con test propio, porque es una regresión que el cambio podía
   introducir en algo que ya funcionaba.

4. **¿Qué pasa con el foreground que llega MIENTRAS el ciclo corre, cuando no hay sueño que cortar?**
   → **Marca de una vuelta** (`wakeRequested`): pone a 0 el delay de esa vuelta y solo de esa. Dejarlo fuera
   habría dejado abierta justo la ventana del ticket con la red lenta, que es cuando el ciclo dura más.

5. **¿Despertar resetea la racha de fallos (`consecutiveTransients`)?**
   → **No.** Adelantar un reintento no borra los fallos que ya hubo; resetear convertiría cada vuelta a la app
   en «vuelve a empezar por 5 s» y castigaría al backoff a no crecer nunca. Es también lo que hace el personal.
   Pinneado por una aserción.

6. **¿Despertar corta también la cadencia sana de 60 s, o solo el backoff?**
   → **También la sana**, que es exactamente lo que hace `CloudSyncRuntime.handleBecameActive` en `.running`.
   Distinguirlas sería divergir del molde que el ticket manda copiar.

7. **Estado de cierre del ticket: `qa` o `done`.**
   → **`done` sin device-QA.** Reproducirlo pide cortar la red con cambios sin subir, esperar el backoff y
   volver a primer plano; no hay seam de simulador que lo monte y el efecto no tiene superficie visual. El
   rastro de producción es `GroupsSync loopWoken trigger=foreground sleeping=true`.

8. **Los hallazgos de la review que no son de este ticket.**
   → El hueco del piggyback con el runtime personal parado sale como **ticket nuevo**
   (`groups-has-no-cadence-when-the-personal-runtime-is-stopped`); los dos comentarios que llaman DARK a un
   canal encendido se **anotan en el ticket de docs hermano**, que ya existía.
