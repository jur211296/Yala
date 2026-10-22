# Al activar Yala completo desde solo-grupos, las preferencias elegidas suben al iCloud del Apple ID

---
ticket: full-activation-local-state-never-reaches-the-apple-id-kv
modo: autonomo
cola: A
---

## Contexto
Cierre limpio de PR #305 (carril adaptativo / fase 2b: el Panel y Estadísticas aprovechan el ancho en iPad; iPhone sin cambio). Cola A autónoma sigue armada; turno Cola A (alternancia A ↔ adaptativo; el cierre fue adaptativo 2b). Una sola sesión Yala a la vez. Ticket: `tickets/backlog/full-activation-local-state-never-reaches-the-apple-id-kv.md` (medium, sesiones/sync/settings). Cola A = riesgo real nube/sync: aquí quien activa «Yala completo» desde solo-grupos elige nombre, moneda y periodo, pero eso no llega al iCloud-KV del Apple ID; otros dispositivos no lo reciben y un `applyRemoteValues` posterior puede pisar lo local con preferencias viejas del Apple ID.

Medido en el ticket (2026-09-14): `OwnerKeyValueGate` cierra el iCloud-KV mientras el eje 1 está en `false` y sigue cerrado durante toda la activación; `.persistOnboarding` escribe solo en local vía `PreferenceSyncService.set`; nada sube al encender el eje; el remoto gana en el merge. Abrir la puerta durante la activación ya se tumbó en review (una activación abandonada aplicaría prefs del dueño). El mismo hueco afecta el espejo del interruptor maestro de notificaciones de pagos programados.

Jürgen ordenó (2026-09-28 16:31, vigente): una sola sesión Yala a la vez, alternando Cola A y carril adaptativo. Esta es Cola A. No toques simuladores `YalaLane-Adapt-*`. MODO AUTÓNOMO / bypass: elige la opción robusta / Recommended sin preguntar; no despiertes a Jürgen por preferencias reversibles. Device-QA opcional no frena merge ni `/cerrar-total`.

**Decisión de producto ya contestada (Frank, opción recomendada — no la vuelvas a preguntar):**
1. **Subir al nacer la sesión privada.** En `completeFullActivation`, después de encender el eje, escribir al iCloud-KV las preferencias locales y el espejo del interruptor maestro, **solo en la rama privada nueva**.
2. En **Restaurar**, las del Apple ID valen: no subas nada en esa rama.
3. No abras `OwnerKeyValueGate` durante la activación (ya tumbaron esa vía).

## Qué se pide
Cierra el ticket `tickets/backlog/full-activation-local-state-never-reaches-the-apple-id-kv.md`.

1. **Medir primero** el hueco: tras activar privado nuevo desde solo-grupos, confirmar que lo elegido no está en el iCloud-KV y que un `applyRemoteValues` con remoto distinto lo pisa.
2. Implementa la subida al nacer la sesión privada (prefs del onboarding + espejo del master toggle), solo en la rama privada nueva; Restaurar no sube.
3. Tests que fijen: tras activación privada nueva, lo elegido está en el KV y el arranque siguiente no lo revierte; en Restaurar no se escribe al KV desde este camino; el orden kill-safe del plan (persist antes de complete) se respeta.
4. Gate, review adversarial acotada al camino de activación/prefs/KV, PR a `2.1`, merge y `/cerrar-total` en autónomo.

## Qué NO hay que tocar
- Carril adaptativo / iPad / simuladores `YalaLane-Adapt-*`. No `simctl shutdown all`, `erase all` ni `killall Simulator`.
- Producción / deploy.
- Cola B (UI/UX redesign) ni Cola C deferred.
- Abrir otra sesión Yala en paralelo.
- Abrir `OwnerKeyValueGate` durante la activación o mientras la sesión sigue siendo solo-grupos.
- El ticket hermano `neutral-boot-hands-owner-prefs-to-whoever-signs-in-next` (otro hueco; no lo mezcles salvo regresión inmediata).

## Cómo se sabe que está bien
- Tras «Activar Yala completo → privado», lo elegido en el onboarding está en el iCloud-KV del Apple ID y el arranque siguiente no lo revierte.
- En Restaurar no se sube nada por este camino.
- Tests + CI verdes; PR mergeado a `2.1`; ticket a `qa` o `done` según cobertura; residuales a ticket propio; cierre limpio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada (ya fijada arriba).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, con resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por test rojo que vas a reclasificar ni ruido de CI advisory.

## Paso 0

Decisiones resueltas antes de escribir código (MODO AUTÓNOMO; la de producto ya venía tomada):

1. **Qué se sube.** Todas las `PrefSyncKey` PRESENTES en local (el idioma, desde su suite del App Group) y el
   centinela del interruptor maestro si está en `true`. No solo las cinco del onboarding: el `applyHistoryChoice`
   y cualquier ajuste tocado en solo-grupos se tragaron por la misma puerta, y el siguiente `applyRemoteValues`
   los revierte igual. Una clave AUSENTE en local no se escribe: sería inventar un valor. *Asumido.*
2. **Solo en `.freshPrivate`.** `.restored` y «Restaurar sin onboarding»: gana el Apple ID (decisión). `.freshCloud`:
   las preferencias van al outbox del backend, no al iCloud-KV. El modo legado ya tiene la puerta abierta.
3. **Kill-safe con una marca durable, no con una línea detrás del eje.** Se ARMA antes de encender el eje y se
   CONSUME justo después (y en el arranque, antes de `PreferenceSyncService.bootstrap`). Un kill entre eje y subida
   dejaba el hueco entero: el arranque siguiente aplicaba el remoto. El arranque la consume SIEMPRE: con la puerta
   abierta sube, con la puerta cerrada (kill antes del eje) la descarta — la reactivación la vuelve a armar. Así la
   marca no sobrevive a un arranque y no puede subir nada en una Restauración posterior.
4. **La puerta no se toca.** La subida pasa por `OwnerKeyValueStore.shared`, que ya está abierta cuando corre.
5. **Fuera, a ticket propio si no existe:** la señal `lastOnboardingTimestamp` que el onboarding de la activación
   tampoco sube, y el espejo del interruptor maestro en la activación a la nube.

**Corregido tras la review adversarial (2026-09-30):** la decisión 1 cambió. Una clave AUSENTE en local ya no se
salta: se retira del KV (`removeObject`, el gesto de «idioma del sistema»), salvo el consentimiento de la nube.
Saltarla dejaba que el merge trajera el valor de la vida anterior del Apple ID (idioma, iconos, primer día de la
semana), que es el síntoma del ticket por otra puerta.
