# Implementar ticket paso 6: beacon-routes-only-never-blocks

## Contexto
Cola del rediseño de sesiones. Pasos 0–5 (mitad 1) en `2.1`. Mitad 2 del paso 5 aparcada a espera del verbo del paso 9 (ticket blocked/backlog con medición). Jürgen 2026-09-10: lanzar paso 6 en bypass.

Decisiones YA tomadas: sección **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»** del ticket + índice `docs/sessions/2026-09-09-desbloqueo-decisiones-rediseno-sesiones.md`. **Mandan.** (chooser entero, privado incluido — deroga A26; faro huérfano se cubre aquí).

MODO AUTÓNOMO HASTA TERMINAR: gate/commit/board/`docs/TICKETS.md`/merge/`/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`. Ambigüedad NUEVA: elige lo más seguro alineado con Decisiones y regístralo. Para solo por credencial/acceso real.

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle — una vez.

## Que se pide
1. Leer: Decisiones → ADR → matriz → ticket → runbook (este paso). Necesita el paso 3 (`kind`) para «crear con Google» — ya en `2.1`.
2. Implementar alcance del ticket (beacon solo rutea, nunca bloquea).
3. Un PR a `2.1`; matriz/coverage según runbook; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Mitad 2 del paso 5 (espera paso 9). Pasos 7–13 salvo lo mínimo.

## Como se sabe que esta bien
Criterios del ticket + Decisiones; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (encargo lanzado en bypass, sin nadie delante): las recomendaciones se dan por
> buenas y se discuten en el PR. Por encima de ellas mandan las «Decisiones de Jürgen (2026-09-09)» del
> ticket, y ninguna de estas las contradice.

**Hechos medidos antes de decidir** (árbol `1f6729fe`):
- `AccountClaimDecision`: la variante B (mismatch en el claim) es solo de `.returningUser` ⇒ el ALTA nube
  nunca choca con el faro, y «crear con Google» ya crea: `claim_account` estampa `kind='complete'` por
  defecto (`qa/cloud/g15_01_account_kind.sql`).
- `GET /account/exists` = «¿hay fila en `profiles` para este `sub`?» (`gateway/src/sync/account.ts`).
- El hash del faro es del uuid de Supabase (`CloudAuthService.currentUserID`) ⇒ tras el fresh start, que
  borró `auth.users`, volver a firmar da OTRO uuid: una regla «mismo hash» sola **nunca** detectaría el
  faro huérfano del fresh start.
- Yala y Yala Dev NO comparten iCloud-KV (`$(TeamIdentifierPrefix)$(CFBundleIdentifier)` en los dos
  entitlements).
- `OwnerKeyValueStore.removeObject` pasa por la puerta M1: en sesión secundaria, limpiar el faro es no-op.
- El freno de adopción de Ajustes (`StorageMigrationSignInLogic`, regla 2) solo mira el faro con sesión
  YA viva, y con un faro huérfano bloqueaba para siempre. Limpiarlo deja que el adopt siga como migración a la
  cuenta nueva: la recuperación que se quiere para una cuenta borrada. *(Corregido tras la review: la primera
  versión decía que limpiar no retiraba ninguna protección que funcionara.)*

**D1 · ¿Cómo sabe la pantalla de sign-in que llegó encaminada por el faro?** → caso nuevo
`Entry.beaconRouted(accountProvider:)`.
Por qué: cada productor del cover escribe su `Entry` explícito; un `Bool` aparte en `ContentView` se
heredaría entre entradas. Descartado: un parámetro suelto de la vista.

**D2 · ¿Qué abre «Crear otra cuenta»?** → cierra el cover y reabre el Welcome en «Elige dónde quieres
guardar tus datos» con `visibleNewOptions` tal cual: sin preseleccionar, sin recortar, sin bypass. Si el
percent de la elección nube estuviera en 0, enseña la única card que haya.
Por qué: decisión de Jürgen (chooser ENTERO, privado incluido). Descartado: volver al chooser de nivel 1,
donde el faro volvería a encaminar.

**D3 · ¿Qué puerta de [I] usa la entrada encaminada?** → `.welcomeFirstTimeCloud`: la persona tocó
«Soy nuevo».
Por qué: es la puerta física, y hoy da exactamente los mismos destinos que `.welcomeExistingAccount`
(medido en la tabla). Cuando el ticket 8 separe «solo grupos» de «solo grupos ofreciendo Yala completo»,
le ofrecerá lo completo a quien venía a estrenar Yala. Descartado: la puerta de «Ya tengo cuenta».

**D4 · Copy del origen** → sustituye al subtítulo del intro encaminado: «Este Apple ID ya tiene una
cuenta de Yala creada con %@.»; con el proveedor del faro desconocido, «Este Apple ID ya tiene una cuenta
de Yala.». El botón de entrar conserva el fallback de siempre (Apple).
Por qué: decisión de Jürgen («nombra el proveedor y nada más»). Descartado: afirmar «con Apple» cuando
el faro no lo dice.

**D5 · Forma del mismatch** → `ProviderMismatchLogic.Verdict.mismatch(Exits)`: `accountProvider` (el del
faro, o nil), `signInWith` (el del faro; si no lo sabe, el OTRO de los dos métodos) y `createWith` (el
que la persona acaba de usar). Pantalla: mismo título; el cuerpo solo informa («Tu cuenta de Yala se creó
con %@.» — se va «Vuelve atrás y entra con ese método», que ERA la pared); dos botones de marca:
«Iniciar sesión con <faro>» y «Crear cuenta con <el usado>». Las cinco reglas de la tabla NO cambian:
cambia lo que lleva su salida.
Por qué: criterio del ticket («`.mismatch` lleva ahora las dos salidas»). Descartado: calcular las
salidas en la vista (dos sitios decidiendo lo mismo).

**D6 · ¿«Entrar con <faro>» vuelve a pedir el consentimiento?** → No: relanza el sign-in con ese
método. Es la misma ruta (adopt) que la persona acaba de consentir, y su escritura sigue pendiente hasta
el adopt. «Crear cuenta con…» sí pasa por el consentimiento del ALTA, por el mismo camino que ya usa el
CTA de «No encontramos una cuenta» (helper compartido).
Por qué: Jürgen en el paso 3, «no añadas ceremonia por prudencia»; el consent del alta es otro texto y
otra ruta. Descartado: re-mostrar el consent en las dos salidas.

**D7 · Faro huérfano: ¿dónde y cuándo se limpia?** → en el motor de [I] (`CloudIdentityDiscovery`), por
donde pasan todas las puertas, cuando el backend contesta «no existe» Y se PRUEBA que la cuenta del faro
es esa: (a) mismo hash de cuenta; o (b) faro de Apple y sesión de Apple — SIWA solo firma con el Apple
ID del teléfono, que es el mismo cuyo iCloud-KV guarda el faro, así que si esa identidad no tiene
cuenta, la del faro ya no existe. Con Google y otro hash NO se limpia (puede ser otra cuenta de Google de
la misma persona): ahí vale «al menos no bloquea», que ya garantiza D5. Breadcrumb de producción al
limpiar: es irreversible y cross-device, y si algún día se equivoca será su único rastro.
Por qué: decisión de Jürgen («se limpia solo en cuanto [I] lo descubre»); la regla (a) sola no
dispararía nunca tras el fresh start. Descartado: limpiar ante cualquier «no existe» (borraría el faro
de una cuenta viva cuando alguien firma con otra cuenta de Google).

**D8 · ¿Se cierra `restore-beacon-outlives-account-deletion`?** → No: se actualiza. Medido: su §1 ocurre
bajo el kill-switch, donde [I] no corre (las puertas de nube están cerradas) y «siguen a salvo» puede
seguir afirmando de más; su §2 (`.iCloudDisabled`) y su §3 (migrado con copia congelada) no los toca
este ticket.
Por qué: la decisión dice «márcalo como resuelto **cuando lo esté**». Descartado: cerrarlo por la letra.

**D9 · Verificación** → unit (salidas del mismatch, regla del huérfano, motor con faro inyectado, payload
de la ruta) + scans de cableado + **un XCUITest nuevo** con un seam DEBUG `-uitest-fake-beacon
<apple|google>` que finge el faro SOLO en lectura (no persiste en el KV del simulador): «Primera vez»
encamina, «Crear otra cuenta» existe y abre el chooser con sus DOS cards. Device-QA solo para lo que
exige sign-in real: crear con Google, el mismatch y la limpieza del faro huérfano.
Por qué: el estado de partida (faro puesto) sí se puede sembrar; sin el seam, esa mitad caería en la
cola de Jürgen. Descartado: dejarlo todo a device-QA.

**D10 · Hallazgos nuevos** → ticket propio en `tickets/backlog/`, sin implementarlo aquí (lectura de
«`--solo-crear`»).

**D11 · ¿ADR nuevo?** → No. La decisión es el ADR §10 más las de Jürgen del ticket. La regla técnica de
D7 (cuándo hay PRUEBA de huérfano) es convención del código y va a `.claude/rules/swiftdata-cloudkit.md`,
para que nadie la «simplifique» a «limpia ante cualquier no-existe».
