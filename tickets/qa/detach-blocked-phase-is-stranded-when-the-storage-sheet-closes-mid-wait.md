---
id: detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait
status: qa
priority: medium
area: "modo-nube, settings, groups"
created: 2026-10-02
updated: 2026-10-02
qa-status: needs-testing
source: "review adversarial de `detach-saves-the-personal-graph-outside-the-quiescence-window` (lente de consumidores)"
---

# Si cierro Almacenamiento mientras el desasociar espera, cerrar sesión deja de funcionar hasta matar la app

## El problema, en lenguaje de usuario

Toco «Desasociar», el spinner se queda girando (sube cambios o espera a que iCloud termine de bajar datos) y cierro
la hoja de Almacenamiento. Si el gesto acaba bloqueado, no veo ningún aviso. Desde entonces «Cerrar sesión» no hace
nada, y si vuelvo a «Desasociar» me dice «Estás cerrando sesión en este momento», que es falso. Solo sale matando la app.

## Lo leído en el código (sin ejecutar)

- `GroupsAssociationSection.apply` escribe `blockedReason` en una vista ya desmontada: el aviso no sale y nadie llama a
  `acknowledgeBlocked()`, así que `CloudSessionSignOut.phase` se queda en `.blocked`.
- `ProfileView` ignora a propósito los motivos propios del desasociar (`case .bridgeUnreadable, .detachBusy,
  .sessionNotClosed: break`), así que tampoco lo reconoce ella.
- Un desasociar nuevo devuelve `.busy` (`guard phase == .idle`) y su aviso, `.detachBusy`, no llama a
  `acknowledgeBlocked()` porque la fase «es de otro».
- Es anterior a 2026-10-02: el push-all ya podía esperar 45-60 s. Ese día la espera de quiescencia antes del puente
  (`writeDetachUnderQuiescence`) añade otra ventana de hasta 60 s con el mismo desenlace.

## Lo que se espera

Que un `.blocked` del desasociar sin pantalla que lo enseñe no deje el coordinador cogido: o la sección lo vuelve a
leer al aparecer y enseña su aviso, o el bloqueo no se queda en la fase compartida cuando nadie lo va a reconocer.
Decidir cuál con el ticket `signout-alert-fires-on-detach-blocks-it-did-not-cause`, que toca la misma fase compartida.

## Resuelto (2026-10-02)

**Medido antes de tocar nada**, con el coordinador real y sin reconocer el bloqueo (que es la hoja cerrada): tras un
desasociar bloqueado la fase quedaba `.blocked(pendingCount: Int.max, reason: .uploadRetryLater)` y el desasociar
siguiente devolvía `.busy`. El bloqueo se provoca sin red ni sesión: la captura de salida dice «no terminé» y el
push-all bloquea en su pre-check.

**Camino elegido: el bloqueo no se queda en la fase compartida.** `detachGroupsAccount` devuelve el motivo por el
retorno (`.blockedBeforeWriting(reason:)`) y deja la fase en `.idle` en el mismo turno (`releaseDetachBlock`, el único
sitio por el que pasan sus cinco bloqueos). La sección enseña su aviso con el motivo devuelto, y cerrarlo ya no toca la
fase. Se descartó «la sección relee al reaparecer»: no distingue un `.blocked` suyo del de un cierre de sesión, y si
nadie reabre Almacenamiento «Cerrar sesión» sigue mudo.

Y una pieza que salió al medir: con la hoja reabierta **a mitad** de la espera, la sección nueva no pintaba el spinner
(era un `@State` de la que lanzó el gesto) y tocar «Desasociar» chocaba con el gesto en vuelo y decía «Estás cerrando
sesión». El spinner lo decide ahora el coordinador (`isDetaching`).

**Coste aceptado:** si la hoja se cerró a mitad de la espera, el aviso de ESE intento no sale —nadie lo mira—. La
sección vuelve a ofrecer «Desasociar» y reintentar dice el motivo.

Tests: `YalaTests/CloudSync/GroupsDetachBlockedPhaseTests` (comportamiento con el coordinador real + source-scan de los
cinco bloqueos, del reintento y de la sección). Mutantes, tres muertos: quitar la vuelta a `.idle` (4 rojos), quitar
`isDetaching` del gesto (1) y del reintento del borrado (1, el scan). Review adversarial, dos lentes: consumidores de la
fase y concurrencia sin hallazgos; la de la sección cazó que el spinner del reintento no lo fijaba ningún test.

### Guion de device-QA (no bloquea el merge)

Montaje: iPhone con `Yala Dev`, sesión privada con cuenta de grupos asociada y algún gasto de grupo recién apuntado.
Ajustes del iPhone → Desarrollador → Network Link Conditioner → «Very Bad Network» (alarga la subida).

1. Abre Perfil → «¿Dónde viven tus datos?» → «Desasociar» → «Conservar».
2. Con el spinner girando, cierra la hoja (desliza hacia abajo).
3. Espera un minuto. Vuelve a abrir «¿Dónde viven tus datos?».
   - Si el gesto sigue en curso: se ve el spinner, no el botón «Desasociar».
   - Si ya terminó bloqueado: se ve «Desasociar» otra vez.
4. Cierra la hoja y toca «Cerrar sesión» en Perfil: abre su hoja de cierre (no se queda mudo). No confirmes: «Cancelar».
5. Vuelve a «¿Dónde viven tus datos?» → «Desasociar» → «Conservar»: el aviso que salga NO dice «Estás cerrando sesión».
