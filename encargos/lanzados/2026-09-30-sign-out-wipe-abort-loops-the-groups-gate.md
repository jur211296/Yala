# Si el borrado de arranque no puede borrar los archivos, la puerta de Grupos deja de entrar en bucle

---
ticket: sign-out-wipe-abort-loops-the-groups-gate
modo: autonomo
cola: A
---

## Contexto
Cierre limpio de PR #303 (carril adaptativo / bloqueo 2.1: estrechar la ventana en iPad ya no cierra la app). Cola A autónoma sigue armada; turno Cola A (alternancia A ↔ adaptativo; el cierre fue el crash de narrowing). Una sola sesión Yala a la vez. Ticket: `tickets/backlog/sign-out-wipe-abort-loops-the-groups-gate.md` (medium, modo-nube/groups). Cola A = riesgo real nube/sync: aquí la persona queda atrapada en un bucle de la puerta de Grupos si el wipe de arranque aborta al borrar archivos (sin salida honesta).

Medido en el ticket (2026-09-11): `performSignOutWipeIfArmed` aborta (guard S3) cuando `deleteFiles` falla por algo que no es «no existe» y, con modo `.icloud`, desarma en vez de reintentar. Quien armó desde la puerta de Grupos: wipe aborta y desarma → datos y `hasCompletedOnboarding=false` siguen → `presentNextOnboardingScreen` reabre la puerta → re-mide → arma otra vez → «reabre Yala» → bucle. Cada vuelta cancela notificaciones locales y vacía la caché del widget.

Jürgen ordenó (2026-09-28 16:31, vigente): una sola sesión Yala a la vez, alternando Cola A y carril adaptativo. Esta es Cola A. No toques simuladores `YalaLane-Adapt-*`. MODO AUTÓNOMO / noche (Lima): elige la opción robusta / Recommended sin preguntar; no despiertes a Jürgen por preferencias reversibles. Device-QA opcional no frena merge ni `/cerrar-total`.

**Decisión de producto ya contestada (Frank, opción recomendada — no la vuelvas a preguntar):**
1. Deja un **testigo one-shot** cuando el abort S3 desarma el wipe (solo en el camino que armó la puerta de Grupos / destino `.groupsOrganizer`, o de forma que la puerta pueda leerlo).
2. La puerta, al ver ese testigo, **deja de rearmar** y enseña una pantalla honesta («no pudimos preparar este teléfono» / equivalente brand voice) con salida clara (Volver al chooser o equivalente recuperable), en vez de reintentar el wipe en bucle.
3. No inventes un reintento agresivo del `deleteFiles` sobre espejo montado (el desarmar en S3 con `.icloud` es correcto para no llevarse cambios no exportados).

## Qué se pide
Cierra el ticket `tickets/backlog/sign-out-wipe-abort-loops-the-groups-gate.md`.

1. **Medir primero** el bucle: arma desde la puerta de Grupos, fuerza fallo de `deleteFiles` (o el hook de test vigente), confirma rearme + cancelación de notificaciones/widget.
2. Implementa el testigo one-shot + pantalla honesta sin rearme; limpia el testigo en la salida recuperable.
3. Tests que fijen: con `deleteFiles` fallando siempre, la puerta deja de reintentar tras el primer intento y lo dice; el camino feliz de wipe sigue igual; no se desarma mal un wipe que sí puede completar.
4. Gate, review adversarial acotada al camino del abort/puerta, PR a `2.1`, merge y `/cerrar-total` en autónomo.

## Qué NO hay que tocar
- Carril adaptativo / iPad / simuladores `YalaLane-Adapt-*`. No `simctl shutdown all`, `erase all` ni `killall Simulator`.
- Producción / deploy.
- Cola B (UI/UX redesign) ni Cola C deferred.
- Abrir otra sesión Yala en paralelo.
- Reintentar borrados destructivos sobre espejo montado cuando S3 ya decidió desarmar.

## Cómo se sabe que está bien
- Con `deleteFiles` fallando siempre, la puerta de Grupos deja de reintentar tras el primer intento y lo dice con salida recuperable.
- El wipe que sí puede completar no regresa.
- Tests + CI verdes; PR mergeado a `2.1`; ticket a `qa` o `done` según cobertura; residuales a ticket propio; cierre limpio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada (ya fijada arriba).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, con resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por test rojo que vas a reclasificar ni ruido de CI advisory.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-30)

1. **Qué señal distingue «vengo de un aborto».** Un testigo durable nuevo, `cloudSync.groupsGate.wipeCouldNotDelete`
   (`GroupsGateWipeFailureMarker`). La alternativa del ticket —no re-persistir el destino— no sirve: el destino lo
   persiste la puerta en el arranque en el que arma, y el aborto ocurre en el siguiente.
2. **Quién lo escribe y cuándo.** El abort S3 con modo `.icloud` (la rama que desarma), **solo si hay destino pendiente
   de la puerta** (`.groupsOrganizer` / `.groupsInvite`), y **antes** de desarmar (kill-safe: el kill repite el abort).
   Un cierre de Ajustes que aborta no lo pone: no hay puerta que lo lea y una marca sin lector acabaría leyéndola otra.
   En `.cloud` tampoco: ahí el arm persiste y reintenta, no hay bucle de la puerta.
3. **Quién lo lee.** Las dos entradas de la vuelta al neutro de la puerta (organizador e invitado), como primera
   sentencia, antes de la fase del coordinador y de la celda.
4. **Qué enseña.** Pantalla nueva `.wipeFailed`: «No pudimos preparar este teléfono» + cuerpo que no afirma dónde
   siguen los datos ni que no se tocó nada (en el aborto de sync-meta el personal ya se borró). Un solo botón, «Volver»
   (al chooser de Grupos). Sin «Reintentar» en la propia pantalla: el reintento es un gesto de la persona desde el
   chooser.
5. **Quién lo retira.** Salir del aviso (botón o «volver» de arriba), la puerta cuando deja pasar (`.proceed`) y un
   borrado que completa. No se consume al leer: si la persona mata la app con el aviso delante, lo vuelve a ver.
6. **Sin reintento del `deleteFiles`** sobre espejo montado (lo manda el encargo).
7. **Tests.** Unit del hook (inyectable) + source-scan del orden y de la puerta + XCUITest con seam
   `-uitest-groups-gate-wipe-failed` (el aborto real no corre bajo `-uitest`; se fabrica su resultado).
8. **Asumido:** 16 idiomas traducidos por mí; review adversarial acotada al camino abort/puerta.
