# Cerrar sesión en «Empezar desde cero» y purgar al reinstalar (sesión de la persona anterior)

## Contexto
Ticket: `tickets/backlog/previous-person-cloud-session-survives-fresh-start-and-reinstall.md` (high).
Must-fix 2.1: el JWT en el llavero sobrevive a borrar la app; «Empezar desde cero» no cierra la sesión; tras reinstalar el sello se pierde y varias puertas reusan la cuenta de la persona anterior.

Hermano ya mergeado (#190): en teléfono sellado, «Activar la nube» ya no promueve esa sesión. Esto cierra la raíz (la sesión viva).

## Decisión Jürgen (2026-09-17) — YA EN EL TICKET
**Las dos:**
1. Cerrar la sesión en la nube en el relevo («Empezar desde cero»), midiendo el cursor de Grupos.
2. Purgar la sesión en el primer arranque tras instalar (UserDefaults sin marca + JWT en llavero).
Quien reinstala su propia app vuelve a entrar. No basta preguntar «¿Sigues siendo…?» ni solo una de las dos.

## DIURNO (6:00–21:00 Lima)
Puedes AskUserQuestion a Jürgen si hace falta producto/acceso.

## Que se pide
1. Implementar las dos mitades de la decisión (con medición del cursor de Grupos en el relevo).
2. Ninguna puerta (Welcome, Activar completo, Grupos, adopt) debe usar la sesión anterior sin que la persona nueva la elija.
3. Camino claro para quien reinstala su propia app.
4. Tests, gate, commit, `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1, `/cerrar-total`. Bugs → ticket propio. No Kanban store/Tim.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/`/cerrar-total` sin preguntar. Solo parar ante decisión/acceso real. UI tests CI advisory.

## Que NO
marketing/ ni Web/ (Lola). No solo copy de «¿sigues siendo…?» como solución.

## Como se sabe que esta bien
Tras reinstalar o Empezar desde cero, ninguna puerta usa la sesión de la persona anterior sin elección. Quien reinstala la suya tiene camino claro. Board + `/cerrar-total`.

## Avisos Frank
Webhook Mini (URL/key local): (1) decisión/acceso; (2) PR/preview; (3) `/cerrar-total` + resumen usuario; (4) idle una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — árbol de decisiones (auto-contestado, 2026-09-17)

Todo lo de abajo está MEDIDO en este árbol salvo donde diga «inferido».

**D1 · Qué se borra del llavero.** El service `com.yala.cloudauth` guarda CINCO cosas de la persona
anterior: la sesión del SDK (`yala.cloudauth.session`), el perfil capturado (correo, nombre,
appleUserID), el provider del último sign-in, el par SIWA (refresh token de Apple) y el par Google.
→ **se purga el service ENTERO**, con un solo `SecItemDelete`. Una lista de keys es exactamente como
diverge de lo que el service acabe guardando mañana, y en una frontera de relevo el default correcto
es fail-closed.

**D2 · Borrar el llavero no basta: hay que apagar al escritor.** `AuthClient` se construye con
`autoRefreshToken: true`, así que su refresco en vuelo REPONDRÍA la sesión sobre el llavero recién
purgado. → el retiro es `await CloudAuthService.signOut()` **primero** (para el SDK y limpia su
memoria) y la purga del service **después** (se lleva lo que el sign-out conserva a propósito: los dos
pares de provider, y todo lo que el sign-out no toca cuando el backend no está configurado —
`guard let client else { return }`).

**D3 · El retiro es ASÍNCRONO y `wipeLocalGroupsDomain` es SÍNCRONO.** → el escritor **arma** (una
key durable) y **dispara**; un ejecutor único consume el arm y solo lo desarma si salió bien. Molde
de `SecondarySessionRetirement`: kill-safe y failure-safe. Ventaja lateral: la mitad del relevo y la
de la reinstalación comparten ejecutor, y un cuarto camino que nazca mañana hereda las dos.

**D4 · Dónde se arma cada mitad.**
- Relevo: DENTRO de `DataWipeService.wipeLocalGroupsDomain`, que es el escritor común de los TRES
  call-sites del handover. En las vistas sería un grep, no un test.
- Reinstalación: PRE-MOUNT, al lado de `SecondarySessionRetirement.purgeIfNeeded()` en
  `PersonalContainerHost.makeContainer()`, con la misma guarda de entorno.

**D5 · El cursor de Grupos — lo que Jürgen pidió medir.** La regla de área dice que en una frontera de
usuario el par coherente es **outbox muerto + cursor vivo**, y la razón escrita del cursor es que es la
BARRERA contra el corpus del anterior bajando *con ese mismo JWT*. Cerrar la sesión **no invierte el
signo del cursor**:
- el cursor está indexado por `groupID`; los grupos de la persona nueva son otros IDs ⇒ bajan enteros;
- si comparten grupo, el re-join ya resetea ese cursor (`cursorResetGroupIDs`, `GroupsSyncClient`);
- si el retiro FALLA (llavero que no borra), el cursor sigue siendo la única barrera.
→ **el cursor se conserva**, y la premisa del comentario cambia de «el JWT sobrevive» a «el JWT se
retira, y el cursor es lo que queda si el retiro falla». Se pinnea igual en los dos sentidos.

**D6 · Los dos caminos que declaran relevo y NO llaman al escritor.** Los dos se cierran:
- `performICloudCorpusWipe(.handover)` sale por `guard scope.deletesLocalRows, checkHasExistingData()`
  antes de purgar y sellar, aunque `.handover` promete «purga + sello» en su docblock;
- `startFreshPrivateOnboarding()`, rama sin datos locales, va al onboarding sin tocar nada.
En el primero se separa «borrar filas» de «purgar el dominio», que es lo que el enum ya dice. En el
segundo **solo se retira la sesión**: sellar ahí le quitaría la asociación del Apple ID a quien
reinstala su propia app y dice «soy nuevo», y el sello no se levanta nunca.

**D7 · Camino de vuelta para quien reinstala lo suyo.** Medido: `CLOUD_MODE_ROLLOUT_PERCENT = "100"`
en el bloque de producción de `gateway/wrangler.toml`, así que «Ya tengo una cuenta → Entrar con
Apple / Entrar con Google» SÍ se ofrece hoy. El comentario de `WelcomeAccountChoiceLogic` que dice
«prod DARK» está caducado; no se toca aquí, pero la premisa de este encargo se apoya en la medición,
no en él.

**D8 · Las premisas de docblock que este cambio deja MENTIROSAS** (y que se corrigen sin tocar
comportamiento): `GroupsAccountAssociation.associate` / `.clear` / `readICloud`, el registrador,
`StorageMigrationIdentityGateLogic.check` y la regla L202 de `swiftdata-cloudkit.md` dicen todas
«Empezar desde cero no cierra la sesión en la nube». Los guards del sello se CONSERVAN: cubren la
reinstalación mientras el arm no se haya consumido, y el caso en que el retiro falle.
