<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->

## Índice (23 entradas)

> **No hace falta leer este fichero entero** — son 93 KB. Localiza la entrada
> aquí y salta a ella.

- `—` [Lo que hay hoy (MEDIDO)](#lo-que-hay-hoy-medido)
- `—` [La decisión: dónde vive](#la-decisin-dnde-vive)
- `—` [La decisión: qué ruta y con qué guard](#la-decisin-qu-ruta-y-con-qu-guard)
- `—` [Cómo se LEE](#cmo-se-lee)
- `—` [La caché local, y por qué su forma importa](#la-cach-local-y-por-qu-su-forma-importa)
- `—` [Lo que ya existe (MEDIDO) — y es más de lo que la exploración supone](#lo-que-ya-existe-medido--y-es-ms-de-lo-que-la-exploracin-supone)
- `—` [La propuesta (INFERIDO)](#la-propuesta-inferido)
- `—` [La tabla, MEDIDA y completa: son CINCO polaridades, no dos](#la-tabla-medida-y-completa-son-cinco-polaridades-no-dos)
- `—` [Por qué `GroupService.softDelete` NO sirve — tres razones, no una](#por-qu-groupservicesoftdelete-no-sirve--tres-razones-no-una)
- `—` [La recomendación (INFERIDO)](#la-recomendacin-inferido)
- `—` [Los dos daños colaterales que hay que decidir](#los-dos-daos-colaterales-que-hay-que-decidir)
- `—` [La recomendación (INFERIDO)](#la-recomendacin-inferido)
- `—` [Las tres correcciones que la medición hizo al chip](#las-tres-correcciones-que-la-medicin-hizo-al-chip)
- `—` [La regresión que el propio gate destapó, y que vale por el chip entero](#la-regresin-que-el-propio-gate-destap-y-que-vale-por-el-chip-entero)
- `—` [Verificación](#verificacin)
- `—` [La decisión: qué cliente, y qué arrastra al conteo de `AttestWiringTests`](#la-decisin-qu-cliente-y-qu-arrastra-al-conteo-de-attestwiringtests)
- `—` [Lo que queda para device-qa (imposible en simulador)](#lo-que-queda-para-device-qa-imposible-en-simulador)
- `—` [Las decisiones de diseño, con su porqué](#las-decisiones-de-diseo-con-su-porqu)
- `—` [El efecto colateral que hubo que pagar: el `body` de `ContentView`](#el-efecto-colateral-que-hubo-que-pagar-el-body-de-contentview)
- `2026-08-12` [C2 · La cadena unificada, el educativo y el estado vacío — 🟢 HECHO (`3a960fd9`, 2026-08-12) · *depen](#c2--la-cadena-unificada-el-educativo-y-el-estado-vaco---hecho-3a960fd9-2026-08-12--dependa-de-c1)
- `2026-08-12` [C3 · Los grupos legacy desaparecen — 🟢 HECHO (2026-08-12) · *dependía de C4*](#c3--los-grupos-legacy-desaparecen---hecho-2026-08-12--dependa-de-c4)
- `2026-08-11` [C4 · Cerrar la fábrica de zombis  — *va PRIMERO* — 🟢 HECHO (`ad291c7f`, validado 11-08)  ✅ **HECHO (](#c4--cerrar-la-fbrica-de-zombis---va-primero---hecho-ad291c7f-validado-11-08---hecho-2026-08-11-ad291c7f)
- `2026-08-11` [C1 · El registro del consent contra la cuenta — 🟢 HECHO (`bc0bb256`, validado 11-08) · ⚠️ SQL SIN AP](#c1--el-registro-del-consent-contra-la-cuenta---hecho-bc0bb256-validado-11-08---sql-sin-aplicar-en-stagingprod---hecho-2026-08-11---worker-desplegado-2026-08-12-prod-1f72f6a5-staging-645b6820)

<!-- INDICE:fin -->

---
id: groups-consent-door-spec
status: qa
created: 2026-08-11
updated: 2026-08-26
source: YalaWiki/Backlog/modo-nube/qa_MODO-NUBE-SPEC-CONSENT-GRUPOS.md
---


# SPEC · La puerta de Grupos: educativo → login → consent, y el consent viaja con la cuenta (2.1)

> **Entregable de la sesión de EXPLORACIÓN + SPEC del 2026-08-11.** Responde a los 10 puntos de
> [[MODO-NUBE-EXPLORACION-CONSENT-GRUPOS]]. **Cero código de producción tocado.**
>
> **Árbol de medición:** `/Users/jur/Yala`, branch `2.0.5`, HEAD **`b5dab36d`** (pull hecho, «Already up
> to date»). Todas las coordenadas **MEDIDO** son de ESTE árbol y se re-midieron una a una: la
> exploración las traía contra el mismo commit y aun así **doce resultaron falsas o imprecisas** (§0).
>
> **Cómo leer las etiquetas:** **MEDIDO** = leído en el árbol, con fichero:línea. **INFERIDO** = decisión
> de diseño o consecuencia razonada; no está en el código y puede estar equivocada. Ninguna
> recomendación de este spec se apoya en una coordenada que no se haya vuelto a abrir.

---

## §0 · Lo que la exploración decía y la medición desmintió

Doce correcciones. Las cinco primeras **cambian el diseño**; las otras siete son higiene de coordenadas
que conviene arreglar antes de que alguien las reuse en un incidente.

| # | La exploración (o un docblock del repo) decía | MEDIDO en `b5dab36d` |
|---|---|---|
| 1 | «Las dos mecánicas de limpieza del bridge tienen semánticas opuestas» | Son **CINCO polaridades**, y la que muerde no estaba en la lista: `BridgeDeactivationSheet.deleteBridgedTransactions` (`Yala/App/Views/Groups/BridgeDeactivationSheet.swift:173-175`) **borra la TX de cuenta REAL y conserva el espejo virtual** — la inversa exacta del barredor, y está a un tap del usuario. §6 |
| 2 | «Un legacy se identifica con `isBackendGroup == false && movedToBackendAt == nil`» | **Inseguro por DOS vías.** (a) El predicado hay que evaluarlo **ANY-row por ZONA** (`belongsToBackendChannel`, `Yala/Services/CloudSync/Groups/GroupBackendIdentityLogic.swift:63-65` + `Yala/App/Logic/GroupZoneCacheGate.swift:90-99`), no por fila: una copia congelada y la gemela de un duplicado mixto lo cumplen. (b) **Hay un productor VIVO de filas con esa forma**: la rama `.cloudKit` sigue acuñando grupos legacy HOY (`Yala/App/Logic/GroupCreateRoutingLogic.swift:29` → `Yala/App/Views/Groups/GroupFormView.swift:283-292` → `Yala/Services/Groups/GroupService.swift:142`). ⇒ **C4 tiene que ir ANTES que C3** o la migración se lleva grupos creados esta semana. §6/§7 |
| 3 | «`softDelete` exige `isOwner` ⇒ hace falta otra vía» | Cierto (`Yala/Services/Groups/GroupService.swift:279`) **y hay un segundo bloqueante que la exploración no menciona**: `guard balances.allSatisfy({ abs($0.netBalance) <= 0.01 })` (`:293`) ⇒ un legacy con deuda pendiente **no se puede ocultar por ese camino ni siendo owner**. Y `softDelete` llama `freezeForSoftDelete` (`:316`), que es la semántica del fantasma. ⇒ `softDelete` no sirve, por tres razones y no por una. §6 |
| 4 | «`softDelete` propaga `isHiddenForAll` por dos canales» (docblock `GroupService.swift:272-275`) | **Falso hoy.** `CKShareCustomKey.isHiddenForAll` (`Yala/App/Models/RouterIntent.swift:24`) no tiene **ni un lector**; el transporte CKSyncEngine no existe (`grep 'CKSyncEngine(' Yala/` = 0). Queda UN canal y **condicionado**: el drain solo emite `is_hidden_for_all` si la zona está en `backendGroupZoneIDs` (`Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:812`, predicado `isBackendGroup == true` en `:722`) ⇒ **en un grupo legacy el flag NO SALE DEL MÓVIL.** Para «desaparecerlos» eso es exactamente lo que queremos. §6 |
| 4b | (no lo decía nadie) | **Hacer desaparecer los legacy APAGA un caveat GDPR.** `accountDeletionGroupsSummary` recorre solo `#Predicate { $0.isHiddenForAll == false }` (`GroupService.swift:1436`) y de ahí sale `hasLegacy = groups.contains { $0.ckSystemFieldsData != nil }` (`:1437`), que enciende la línea `.legacyFootprint` de «Eliminar mi cuenta» (`Yala/App/Logic/AccountDeletionDebtLogic.swift:98`) — el aviso de que tu nombre puede seguir visible en las zonas CloudKit. Ocultarlos borra el aviso sin borrar el hecho. §6 |
| 5 | «El punto 8 (versión del texto) requiere marcar cada versión» | **Ya está marcada y no gatea nada.** `GroupsConsentState.textVersion = 1` (`Yala/Services/CloudSync/GroupsConsentState.swift:24`) y `CloudConsentText.version = 2` con historial en el docblock (`Yala/Services/CloudSync/CloudConsentText.swift:16-32`), que además **declara medido** que «ningún camino COMPARA esta constante con lo persistido». Lo que falta no es marcar: es **comparar**. §8 |
| 6 | «Las TRES definiciones de la guard estricta» (`.claude/rules/gateway-attest.md`) | Son **CUATRO**: falta `gateway/src/sync/account.ts:179`, cuerpo byte-equivalente, y es la que sirve a `/account/delete` y `/account/siwa/revoke` — las dos rutas más destructivas. «Al tocar una, mirar las otras» apunta hoy a 3 de 4. |
| 7 | «Hay cinco `{ nil }` supervivientes, todos de `CloudAccountClient`» (misma regla) | Son **SEIS** y ninguno es un `{ nil }` explícito: son **omisiones** del parámetro (default en `Yala/Services/CloudSync/CloudAccountClient.swift:135`). Cinco llevan su porqué con coordenada correcta; el sexto —`Yala/Services/CloudSync/BornCloudSignUpService.swift:162`— **no lleva ni una línea**, y es justo el hueco por el que un método que exija attest entraría sin que el escáner lo viera. |
| 8 | «`groups/rpc.ts:81-83` es donde se exige App Attest» (header de `AttestWiringTests.swift:21`, y **replicado** en `GroupsMembershipClient.swift:156` y `GroupService.swift:115`) | `:81-83` es la validación del **JWT de Supabase**; el enforcement está en `gateway/src/groups/rpc.ts:86-89`. Tres puertas distintas llevan a la línea equivocada: quien verifique la premisa por cualquiera de ellas puede concluir que la ruta **no** exige attest. |
| 9 | «Los dos `refreshIfDue` que existen — boot y el `.task` del Welcome» (`Yala/App/Logic/GroupsOrganizerGateLogic.swift:15`) | Son **CINCO**: `AppBootstrapper.swift:296`, `WelcomeFlowContainer.swift:204`, `StorageSettingsView.swift:80` (sin `force`) + `WelcomeGroupsGateView.swift:140`, `CloudSyncDebugView.swift:894` (con `force`). La conclusión del docblock aguanta; su cifra no. |
| 10 | «`flagOn` es `false` GARANTIZADO en el primer render» | **Solo en build de RELEASE.** `absentDefault` es `#if DEV_BUILD true #else false` (`Yala/Services/CloudSync/CloudRemoteConfig.swift:120-126`) ⇒ en **Yala Dev** el flag nace TRUE y la ventana de zombis no existe; y `decide()` cortocircuita a `absentDefault` bajo `isRunningTests \|\| isUITestHost` **sin leer el snapshot** (`:186`) ⇒ **el escenario es inejercitable en el harness**. Es la asimetría observe/enforce de `gateway-attest.md` con otra ropa. §7 |
| 11 | «El consent de Grupos llega al backend si el usuario está en `.cloud`» | Cierto, pero el marco es peor de lo que sugiere: **para el grueso del parque el registro no existe en ninguna parte que Yala controle.** `storageMode` por defecto es `.icloud` (`Yala/Services/CloudSync/CloudSyncFlags.swift:52-57`) y Grupos va al 100 % **sin exigir Modo Nube** ⇒ un usuario con sesión Yala (`sub` vivo) escribe su consent en el iKV de su Apple ID. ⇒ **esto no es «mover» un registro de canal: es CREARLO.** §1 |
| 12 | Conteos del propio código | `PrefSyncKey` tiene **39** `case` (`PreferenceMergeLogic.swift:68-122`) y su docblock dice 38 (`:65`); `PreferenceSyncService` dice «las 34 keys» en `:29`, `:61` y `:95`. Importa si el diseño saca las 2 keys de Grupos del enum. |

**Y una confirmación que sí importa:** `grep -rni "consent" gateway/` (sin `node_modules`) = **0 líneas**. Ni
la palabra. El gateway no conoce ningún consent, ni de Nube ni de Grupos: los ve como pares key/value
opacos de `/prefs/push` (`gateway/src/sync/routes.ts:504-508`).

---

## §1 · El registro server-side del consent

### Lo que hay hoy (MEDIDO)

- `GroupsConsentState.register()` escribe **dos** keys por `PreferenceSyncService.set(int:forKey:)` — epoch
  y `textVersion` (`Yala/Services/CloudSync/GroupsConsentState.swift:38-45`; la coordenada `:38-45` de la
  exploración es **correcta**).
- `PreferenceSyncService.behavior` es **computed y se resuelve en cada llamada**
  (`Yala/App/Services/PreferenceSyncService.swift:96-100` → `PrefsSyncBehavior.resolve`, `:43-49`).
- `isAccepted` es `epoch > 0` (`GroupsConsentState.swift:31-33`) — **booleano puro, no mira la versión**.
- El consent **no gatea el canal**, solo pantallas: `GroupsSyncClient.startIfEligible` no lo consulta en
  ninguno de sus guards (`Yala/Services/CloudSync/Groups/GroupsSyncClient.swift:298-338`). Los cinco
  lectores vivos son tablas de routing de UI: `ContentView.swift:964`, `GroupFormView.swift:281`,
  `GroupsContainerView.swift:642`, `GroupJoinReconciler.swift:129`,
  `GroupBackendInviteEntryHandler.swift:40`.
- **El precedente gemelo que la exploración no nombra:** `CloudConsentRegistrar`
  (`Yala/Services/CloudSync/CloudConsentRegistrar.swift:30-51`) + `CloudConsentRegistrationLogic`
  (`Yala/App/Logic/CloudConsentRegistrationLogic.swift:25-73`) son el chip M0, y su tesis es exactamente
  la de este trabajo escrita hace días: «el destino de estas dos keys no es una propiedad del consent, es
  una propiedad del **INSTANTE** en que se escriben» (`CloudConsentRegistrar.swift:11-12`). Su docblock
  declara que su molde ES `GroupsConsentState.register` (`:22`).

### La decisión: dónde vive

**RECOMENDADO (INFERIDO):** tabla propia en Supabase, **no** columna en `profiles` y **no** D1.

```sql
create table public.groups_consents (
  user_id      uuid        not null references auth.users(id) on delete cascade,
  text_version int         not null,
  accepted_at  timestamptz not null,
  path         text,                       -- 'organizer' | 'invite' | 'tab'
  recorded_at  timestamptz not null default now(),
  primary key (user_id, text_version)
);
alter table public.groups_consents enable row level security;
-- 2 policies, no 4: select + insert. SIN update, SIN delete.
create policy groups_consents_select on public.groups_consents
  for select to authenticated using (user_id = (select auth.uid()));
create policy groups_consents_insert on public.groups_consents
  for insert to authenticated with check (user_id = (select auth.uid()));
revoke all on public.groups_consents from anon, authenticated;
grant select, insert on public.groups_consents to authenticated;
```

Cuatro razones, todas medidas:

1. **La PK `(user_id, text_version)` con `on conflict do nothing` da la idempotencia que el punto 1 pide
   literalmente** («aceptar dos veces no duplica ni re-fecha») y **conserva la historia** de qué versión se
   aceptó y cuándo — que es lo que el Art. 7.1 quiere demostrar. Molde de forma: `claim_report`
   (`supabase-staging.ddl:450-461`, `PRIMARY KEY (user_id, report_type, local_day)` + `ON CONFLICT DO
   NOTHING; RETURN FOUND`). ⚠️ **`claim_report` no tiene ni una llamada** (`grep` sobre todo el repo: solo
   DDL y docs) ⇒ es buen molde de FORMA y **cero precedente de cableado** — la familia de
   `AppAttestClient.ensureRegistered()`.
2. **Sin `update` ni `delete` en el grant, el «append-only» deja de ser una convención del cliente y pasa a
   ser un invariante del servidor.** Hoy el append-only lo sostienen tres docblocks
   (`CloudConsentRegistrar.swift:17-20`, `GroupsConsentState.swift:47-66`) y un test de cableado; con el
   grant, un `clear()` mal colocado ya no puede borrar nada remoto. Eso cierra por construcción el
   incidente `bdbc46d1` que la regla de prefs documenta (un `.int(0)` que pisa por LWW el epoch de una
   cuenta viva, porque el wire de prefs **no tiene tombstone**).
3. **Supabase y no D1**: `account_entitlements` (D1, `gateway/migrations/0002_account_entitlements.sql:14`)
   viaja con el deploy del Worker pero **no tiene RLS** — su único control de acceso es el `sub` que la
   guard sacó del JWT. Para un registro legal, la segunda barrera vale su coste de proceso.
4. **Coste de proceso, MEDIDO y no obvio:** `gateway/migrations/` tiene exactamente 2 ficheros y **los dos
   son de D1**; ninguna migración de Supabase vive bajo `gateway/`. Una tabla nueva en Supabase se aplica
   FUERA del deploy, con dos artefactos a mano: el snapshot-contrato (`supabase-groups-staging.ddl`) y la
   promoción (`docs/modo-nube/briefs/prod-promo-sql/`, 17 ficheros; molde exacto de `push_tokens` en
   `20260715014633_g1_01b_reapply_groups_infra_after_drop.sql:227-239`).

### La decisión: qué ruta y con qué guard

**RECOMENDADO (INFERIDO): dos `fn` nuevos en `POST /groups/rpc/:fn`.** No una ruta nueva.

| | `fn` nuevo en `/groups/rpc/:fn` | ruta nueva `/groups/consent` |
|---|---|---|
| Gateway | **UNA entrada** en `PARAM_ALLOWLIST` por fn (`gateway/src/groups/rpc.ts:35-59`). El handler no tiene una sola línea por-`fn` fuera de las tablas (medido recorriendo `:100-172`): el filtro de params es genérico (`:143-146`) y el dispatch es `callRpc(..., fn, args)` (`:155`). `index.ts` **no se toca** (`:102` ya existe). | handler + import + `app.post` + elegir entre **CUATRO** copias espejo de la guard + llamada explícita a `groupsChannelKilled` **que ningún test obliga** + goldens propios |
| Guard | `requireUserAndAttest` ya puesto (`rpc.ts:116`) | hay que elegirla |
| Kill-switch | **se auto-clasifica**: `KILLED_RPCS` se deriva de `Object.keys(PARAM_ALLOWLIST)` (`gateway/test/groups.killswitch.test.ts:57-59`) ⇒ ni `killSwitch.ts` ni sus tests se editan | a mano, y el olvido no lo caza nadie |
| `AttestWiringTests` | **0 líneas** si el llamador reusa una construcción existente de `GroupsMembershipClient` | igual, si el cliente es el mismo |

`canon.ts` / `manifest.ts` / `group_capability_manifest.json` **no intervienen** (medido: `rpc.ts` no los
importa; sus imports son `errors`, `attest/session`, `ratelimit`, `sync/userauth`, `encKey`, `killSwitch`).
Y `RPC_NEEDS_ENC_KEY` tampoco: un consent no escribe columnas †.

**Precedente exacto de un RPC de alcance-CUENTA en esa misma allowlist:** `groups_forget_user: new
Set<string>()` (`rpc.ts:56`), sin params, que deriva todo de `auth.uid()`. ⇒ que el consent sea un hecho de
la cuenta **no lo saca** del namespace de grupos.

**Los dos fn:**

- `record_groups_consent(p_text_version int, p_accepted_at timestamptz, p_path text)` — `SECURITY INVOKER`,
  `insert … values ((select auth.uid()), …) on conflict (user_id, text_version) do nothing`, devuelve el
  estado vigente en jsonb. `p_accepted_at` viaja del cliente **a propósito**: el epoch es la hora de la
  ACEPTACIÓN, no la del reintento que consiguió red — es la misma razón por la que
  `CloudConsentRegistrar.register(now:)` es inyectable y por la que el paso 5-bis del cutover re-emite el
  epoch persistido y jamás `now()` (`Yala/Services/CloudSync/MigrationWorkExecutor.swift:1189-1204`).
  ⚠️ Aceptar una fecha del cliente obliga a acotarla server-side (rechazar futuro y una antigüedad
  absurda); si no, el registro legal es falsificable por un cliente modificado.
- `groups_consent_state()` — sin params, devuelve `{text_version, accepted_at}` del máximo `text_version`.

**Guard: `requireUserAndAttest`, y la elección NO es de estilo.** El criterio del repo está escrito en
`gateway/src/sync/account.ts:165-175`: `/account/*` usa `requireUser` porque **el claim PRECEDE al
`/attest/bind`**, y `/account/delete` es la excepción porque «la ejecuta un device ya establecido (con
sesión de attest viva)». **El consent de Grupos es de la clase de `/account/delete`, y está medido:** las
TRES puertas ordenan sign-in ANTES que consent y las tres lo hacen con la sesión como primer guard
(`GroupCreateRoutingLogic.swift:30` antes de `:31`; `GroupsOrganizerFlowLogic.swift:42` antes de `:43`;
`GroupBackendInviteEntryLogic.swift:41` antes de `:42`), y el propio docblock del organizador lo declara
invariante (`GroupsOrganizerFlowLogic.swift:8-9`). ⇒ **no hay flujo pre-sesión análogo al del claim, y la
guard estricta no rompe nada.**

### La decisión: qué cliente, y qué arrastra al conteo de `AttestWiringTests`

**`GroupsMembershipClient`.** Es el único client tipado de `/groups/rpc/{fn}`
(`Yala/Services/CloudSync/Groups/GroupsMembershipClient.swift:242`) y **pone el header en `call(fn:args:)`**
(`:247-249`), común a todos los `fn` ⇒ un método nuevo que use `call()` **hereda el header sin cablear
nada**. Sus **7** construcciones de producción pasan `attestProvider: AttestSessionProvider.live`
(re-medidas una a una y casan con el `expected: 7` de `YalaTests/CloudSync/AttestWiringTests.swift:56`).

- Si el llamador **reusa** una construcción existente ⇒ **diff en `AttestWiringTests`: 0 líneas.**
- Si nace una construcción nueva (p. ej. dentro de `GroupsConsentView.registerConsent()`,
  `Yala/App/Views/Groups/GroupsConsentView.swift:104-107`) ⇒ **una cifra**: `("GroupsMembershipClient", 7)`
  → `8` en `:56`.

⚠️ **Lo que el escáner NO comprueba, y es la mutación que el chip tiene que verificar a mano:** cuenta el
`attestProvider:` del **init**, no los `setValue(..., forHTTPHeaderField:)` de cada método. Un método que se
salte el header pasa los tres tests en verde. Como el header vive en `call()`, la forma de romperlo es
escribir el método **sin** pasar por `call()` ⇒ el pin es el par de tests de transporte del molde
`AttestHeaderTransportTests` (`:228-257`): provider vivo ⇒ header presente, provider nil ⇒ ausente.

⚠️ **Y la asimetría que hace inútil el e2e:** staging corre `ENFORCE = "observe"`
(`gateway/wrangler.toml:32`) y producción `"enforce"` (`:91`); además el AAGUID
(`gateway/src/attest/verifyAttestation.ts:79`) hace que **ningún build de Xcode pueda validar contra
producción**. ⇒ el pin es estructural y vive en el repo. Palabra por palabra la regla de
`.claude/rules/gateway-attest.md`.

### Cómo se LEE

**El login NO pasa por el gateway** (MEDIDO): `signInWithIdToken` va del cliente directo a Supabase Auth
(`Yala/Services/CloudSync/CloudAuthService.swift:373`); el gateway solo verifica el JWT contra el JWKS
(`gateway/src/sync/userauth.ts:18`). ⇒ **no hay «payload de login» que ampliar.**

Y `/account/claim` **tampoco sirve como portador**, aunque a primera vista sea el candidato natural (es
passthrough de un jsonb y ya creció aditivamente una vez con `profile`, `gateway/src/sync/account.ts:57`):
sus tres call-sites son el panel DEBUG, el cutover (`MigrationWorkExecutor.swift:237`) y el alta born-cloud
(`BornCloudSignUpService.swift:202`). **Un usuario solo-grupos nunca lo llama** — `GroupsSignInView`
«autentica y NADA MÁS» por regla dura de su docblock.

⇒ **la lectura es `groups_consent_state()`, en dos momentos:** (a) en el closure de éxito del sign-in
(`Yala/App/Views/Shared/GroupsBackendInviteModifier.swift:65`, donde ya se arranca `startIfEligible`) y
(b) en el boot cuando hay sesión viva y la caché dice «no aceptado».

### La caché local, y por qué su forma importa

`GroupsOrganizerFlowLogic.nextStep` es `nonisolated` y **síncrona**, y el drain la llama sin `await`
(`Yala/App/ContentView.swift:962-966`) ⇒ **una lectura de red no cabe en esa firma.** La caché local se
queda, y los cinco lectores no cambian de forma.

**Pero cambia de contenido (INFERIDO, y esto es lo que cierra el punto 9):** la caché deja de ser dos
`PrefSyncKey` y pasa a ser un snapshot **con el `userID` DENTRO**, molde `AccountEntitlementStore`
(`Yala/Services/CloudSync/AccountEntitlementStore.swift:28`), cuya seguridad —medido— **no viene de la
purga sino del sello**: un snapshot cuyo `userID` no casa con el `sub` vivo se ignora. Razón medida: **no
existe ningún dominio de `UserDefaults` por sesión** (`PreferenceSyncService.local` es `.standard`
hardcodeado, `:78`; `GroupsConsentState.defaults` también, `:28`), así que la caché de una visita cae
siempre en el dominio del dueño. El sello es la única defensa que no depende de que una purga corra.

⇒ **las dos `PrefSyncKey` (`groupsConsentAcceptedAt`, `groupsConsentTextVersion`) salen del enum** — el
canal de prefs deja de transportar el consent de Grupos. Ojo al conteo: el enum tiene **39** `case` y su
docblock dice 38 (§0.12).

---

## §2 · El fallo de red: intent durable

**Decisión ratificada (owner + punto de control): el usuario PASA.** Aceptó de verdad; bloquearlo por un
fallo nuestro sería castigarle. La caché local se escribe siempre y las cinco tablas de routing la leen ⇒
la puerta no depende de la red.

**El molde vivo es `GroupsPendingBridgeIntent`** (`Yala/Services/Groups/GroupsPendingBridgeIntent.swift:64`)
— y **NO** `GroupsIdentityPurgeIntent`, que la regla sigue citando como canónico y que **tiene cero
ocurrencias** en `Yala/` (borrado el 2026-08-06; el propio docblock del bridge intent, `:29-30`, todavía lo
cita como molde vivo: esa frase está stale).

`GroupsConsentPendingIntent` (INFERIDO), con cuatro diferencias deliberadas respecto del molde:

| | Bridge intent (molde) | Consent intent |
|---|---|---|
| Almacén | `UserDefaults` | igual — la escritura no puede depender de un `save()` de SwiftData |
| TTL | ninguno | **ninguno**: caducar es perder la prueba legal |
| Tope de intentos | 3 por ID | **ninguno**. El motivo del tope allí es que un ID envenenado haría trabajo **y un `save()`** en cada arranque; aquí no hay `save()`, es un request. A cambio, **backoff** (§abajo) + canario |
| Identidad | `Channel` por ID | **`userID` (el `sub`) en el payload**, obligatorio: un intent que sobreviva a un relevo de sesión no puede registrarse contra la cuenta equivocada. Si el `sub` vivo no casa, **no se intenta y no se descarta** |

**Dónde se arma:** en `registerConsent()` de `GroupsConsentView` (`:104-107`), que es el **choke-point único**
que comparten organizador, invitado y tab — **antes** de `onAccept()`. Regla de la casa aplicada literal
(`.claude/rules/swiftdata-cloudkit.md:57`): «recorre la función desde su primera línea y arma antes del
primer `return` que no deje rastro». Aquí no hay `return` intermedio, pero sí un `onAccept()` que cierra el
sheet y continúa el flujo: armar después de él ya es tarde.

**Desarme:** solo con 2xx confirmado. Por unidad cumplida (aquí la unidad es una: el par
`(text_version, accepted_at)`).

**Retome:** dos disparadores. (a) `AppBootstrapper`, tras `awaitPersonalStoreReady()`, junto a los demás
retomes; (b) el closure de éxito del sign-in
(`GroupsBackendInviteModifier.swift:65`) — es el instante en que la sesión acaba de nacer y es el caso del
usuario que aceptó sin red y firma después.

**Clasificación de errores** (nunca `try?` — regla inviolable de `CLAUDE.md`, y la lección de
`GroupBatchStepZoneTests`: un `try?` disfraza el error del estado de negocio que el `nil` significa ahí):

| Respuesta | Qué se hace |
|---|---|
| 2xx | desarmar |
| 403 `yala_groups_disabled` (kill-switch) | **conservar**, transient. Sin canal no hay grupos, pero el consent ya ocurrió |
| 5xx / red / `sessionExpired` | conservar, transient |
| 400 `yala_rpc_error` | **conservar** + canario `groupsConsentRegistrationRejected`. Un 400 sobre un registro legal es un bug nuestro, no una razón para tirar la prueba |

**Backoff:** MEDIDO — **no existe ninguna primitiva reusable** (tres escaleras independientes y de forma
distinta: `AttestRefreshBackoffLogic.swift:51` tabla fija, `SyncCadencePolicy.swift:86` exponencial,
`CloudSignOutFlowLogic.swift:199` presupuesto por tiempo) y **ninguna racha sobrevive a un kill**
(`AppAttestClient.swift:64` es una propiedad almacenada). ⇒ el intent lleva su propio contador **en el
payload** (como el tope por ID del bridge, `:70`) y la escalera va en una lógica pura propia. No se
generaliza una cuarta primitiva en este chip.

**Superficie de observación:** canario `groupsConsentPending` con la edad en horas del intent más viejo,
emitido **en cada retome y antes de cualquier early-return** (molde `bridgedTxOrphanSweepDeferred`: se emite
antes del outcome vacío, porque si no «hay intents frenados» y «no había intents» se leen igual en el
dashboard). ⚠️ MEDIDO: el spool tiene cap 50 con drop-oldest (`Yala/Services/Metrics/MetricsSpool.swift:45-47`)
⇒ un canario puede caer por presión de cola sin dejar rastro; no es una garantía de entrega.

---

## §3 · La cadena unificada

### Lo que ya existe (MEDIDO) — y es más de lo que la exploración supone

**El paso de consent ya está en las tres tablas**, entre el login y la escritura final:

| Tabla | Coordenada | Orden |
|---|---|---|
| `GroupsOrganizerFlowLogic.nextStep` | `Yala/App/Logic/GroupsOrganizerFlowLogic.swift:41-46` | signIn → consent → name → form |
| `GroupBackendInviteEntryLogic.nextStep` | `Yala/App/Logic/GroupBackendInviteEntryLogic.swift:34-44` | signIn → consent → inviteOnboarding → join |
| `GroupCreateRoutingLogic.route` | `Yala/App/Logic/GroupCreateRoutingLogic.swift:28-33` | cloudKit \| needsSignIn → needsConsent → backend |

**Lo que falta en las tres es el EDUCATIVO.** Vive aparte, en `GroupsOnboardingLogic.shouldShow`
(`Yala/App/Logic/GroupsOnboardingLogic.swift:30-39`), como sheet del tab.

**Y las puertas al modo son CUATRO, no tres** (MEDIDO):

| | Puerta | Guardias hoy |
|---|---|---|
| A | **Organizador** (Welcome → «Crear mi primer grupo») | **La única completa**: `GroupsOrganizerGateLogic.decide` tras `refreshIfDue(force: true)` (`WelcomeGroupsGateView.swift:139-150`) → signIn → consent → `completeSetup` |
| B | **Card «Solo grupos»** del onboarding de 8 pasos | Un único guardia, de iCloud y **solo con el canal apagado** (`OnboardingGroupsPurposeGateLogic.shouldBlockSelection`, `OnboardingView.swift:530-536`). Ni sign-in, ni consent, ni `force` |
| C | **Invitación backend** (`GroupBackendInviteEntryHandler.swift:74`) | signIn → consent, sin educativo |
| D | **Tab Grupos** (`requestCreateGroup`, `GroupsContainerView.swift:638`, con **cuatro** entradas: `:327`, `:419`, `:689`, `:703`) | signIn/consent por la tabla, **sin `force`** |

**El punto 1 de la exploración («la card Solo grupos deja al usuario sin cuenta en ninguna parte») está
CONFIRMADO al detalle:** `completeGroupsOnlyOnboarding()` (`OnboardingView.swift:1816-1874`) escribe
`userName`, `defaultCurrencyCode`, `defaultPeriod`, `onboardingMode = .groupInvite` **empujado al iKV**
(`:1835-1836`, never-downgrade cross-device), `groupsBetaUnlocked` (`:1844`), siembra categorías y marca
`hasCompletedOnboarding` (`:1864`). Cero identidad.

**El punto 2 también:** `GroupsOnboardingLogic.shouldShow` corta con `if onboardingMode == .groupInvite {
return false }` en **`:36`** — la coordenada de la exploración es correcta — y ese modo es justo el que la
card B acaba de escribir. Pierden además el CTA de sign-in del cierre, que existe y está pinneado
(`shouldShowSignInCTA(isLastStep:flagOn:hasSession:)`, `:60-66`, + `GroupsOnboardingResult.completeAndSignIn`,
`:84`).

### La propuesta (INFERIDO)

**Una sola tabla pura, `GroupsGateLogic.nextStep(entry:hasSeenEducational:hasSession:isConsented:hasCompletedSetup:)`,**
con los tres primeros escalones compartidos y el terminal por `entry`:

```
educativo → login → consent → [ .name → .groupForm  (entry: .organizer / .onboardingCard)
                              | .inviteOnboarding → .join  (entry: .invite)
                              | .groupForm  (entry: .tab) ]
```

Las tres tablas actuales **se derivan de ella** en vez de duplicarse — el precedente de que esto se puede
es que `GroupsOrganizerFlowLogic` ya declara espejar a `GroupBackendInviteEntryLogic` «a propósito, y
respeta su orden» (`:8-9`). Lo que hoy son tres funciones que se prometen paridad por docblock pasa a ser
una con un parámetro.

**Cambios concretos:**

1. **La card B deja de escribir estado local** y entra en la cadena, reusando `GroupsOrganizerGateLogic.decide`
   y terminando en `GroupsOrganizerOnboarding.completeSetup` — que MEDIDO ya es **el único punto donde se
   escribe todo junto con identidad en mano** (`GroupsOrganizerNameView.swift:91` →
   `GroupsOrganizerOnboarding.swift:146-182`).
2. **El educativo deja de cortar por `.groupInvite`.** El corte de `:36` se sustituye por el hecho REAL que
   quería expresar: «ya vio un educativo de Grupos» — que para el invitado es `GroupInviteOnboardingView`.
   Son dos estados distintos y hoy están colapsados en uno falso.
3. ⚠️ **El `force: true` NO viaja solo** (MEDIDO): `GroupsOrganizerGateLogic.decide` es pura y recibe el flag
   ya leído (`:57-61`); el refresco vive en la VISTA (`WelcomeGroupsGateView.swift:140`) y **el orden solo lo
   sostiene un source-scan** (`YalaTests/Groups/GroupsOrganizerBranchTests.swift:311-323`). Si el paso
   educativo unificado se monta en otra vista, hay que **re-cablear el `force` y mover ese escáner**, o la
   puerta nueva medirá un snapshot de hasta 6 h.
4. **La máquina sigue síncrona** (§1): `isConsented` se lee de la caché sellada; el refresco desde servidor
   ocurre donde ya hay red.

⚠️ **Coste de verificación medido, y es una mala noticia:** el educativo es **inalcanzable desde XCUITest**
— `evaluateGroupsOnboarding()` abre con `#if DEBUG / if UITestHooks.isActive { return }`
(`GroupsContainerView.swift:373-376`, «interceptaría taps»), y `qa/coverage-index.json` ya lo anota. ⇒ la
puerta unificada solo se puede cubrir con **unit + device-qa**, salvo que el chip añada un seam
(`-uitest-groups-educativo`) que invierta ese early-return. **Recomendación: añadirlo**, o el primer escalón
de la cadena nace sin red determinista.

---

## §4 · El estado vacío que dice la verdad

**MEDIDO:** `GroupsEmptyStateLogic.decide(flagOn:hasSession:)` — la firma de la exploración es correcta
(`Yala/App/Logic/GroupsEmptyStateLogic.swift:29`), dos casos (`:21-26`), dos consumidores
(`GroupsContainerView.swift:322` y `:626`), 4 tests que agotan el dominio
(`YalaTests/GroupsEmptyStateLogicTests.swift`). El copy es `groups.empty.signedOut.title` = «Tus grupos
están en tu cuenta» (`es.lproj:4985`) + `.message` = «Inicia sesión para ver los grupos que compartes.»
(`:4988`).

**MEDIDO — las señales están todas disponibles en el sitio de llamada**, síncronas: `flagOn`
(`GroupsContainerView.swift:323`), `hasSession` (`:324`), `GroupsConsentState.isAccepted` (`:642`, ya se lee
en el mismo fichero) y `AppPreferences.hasShownGroupsOnboarding`. ⇒ **la ampliación es barata.**

**Propuesta (INFERIDO):** `decide(flagOn:hasSeenEducational:hadSessionEver:hasSession:isConsented:)` con
cinco casos: `.standard` · `.needsEducational` · `.signInToView` (re-entrada) · `.createAccount` (nunca tuvo
cuenta) · `.needsConsent`.

**La señal que mata el «tus grupos están en tu cuenta» a quien nunca tuvo cuenta:** `GroupsSignOutBannerMarker`
ya existe y significa exactamente «cerró su sesión de grupos» (`GroupsContainerView.swift:617`,
`groups.empty.signedOut.reentryBanner`). Usarla como `hadSessionEver` evita inventar una key nueva. **Si el
marcador resulta demasiado volátil, la alternativa es una key propia** — pero medirlo antes.

---

## §5 · La línea del educativo y el copy honesto

**MEDIDO — el paso 3 tranquiliza y no dice el hecho:**
- `groups.onboarding.step3.title` = «Tu privacidad, primero» (`es.lproj:4281`)
- `.point1` = «Cada miembro entra con su cuenta de Yala.» (`:4283`)
- `.point2` = «Tu información personal no se sincroniza con el grupo, solo los gastos compartidos.» (`:4284`)

Ninguno dice **dónde** se guardan los gastos del grupo. El consent sí — `groups.consent.point1` = «…viven en
la nube de Yala para que todos vean los mismos gastos, al día.» (`:4843`) — pero llega **después** de pedir
identidad. La condición del punto de control está justificada por la medición.

**Propuesta:** un `groups.onboarding.step3.point0` (o reescribir `.point1`) que diga el hecho sustantivo en
voz de marca: *los gastos que apuntes en un grupo se guardan en los servidores de Yala, para que todos los
vean al día.* Sin promesa de cifrado — `GroupsConsentView` ya evita esa palabra a propósito
(`GroupsConsentView.swift:8-9`: «NO promete "cifrado" (G7 no aterrizó — "protegidos" es lo honesto)»).

**Copy del escenario 1 (usuario CloudKit):** se le está **creando** una cuenta de Yala que no tenía. Hoy el
CTA dice «Iniciar sesión» (`groups.onboarding.step3.signInCTA`, `:4286`) y el empty state también
(`groups.empty.signedOut.action`, `:4991`). ⇒ con `hadSessionEver == false` el copy debe hablar de crear
cuenta.

**¿Bumpea esto la versión del consent?** **No** (INFERIDO): la versión identifica el CONTRATO del consent
—qué sale, quién lo lee, dónde se guarda— y el texto del consent no cambia. El educativo no es el contrato.
Es el mismo criterio con el que `CloudConsentText` documenta que el cambio de `7906c1fa` **no** bumpeó
(`CloudConsentText.swift:24-26`).

**Coste de l10n, MEDIDO y mayor de lo que dice la doc:** `qa/scripts/add-l10n-key.sh` toca **10 locales base
+ 4 variantes + 2 aliases** = 16 `.lproj` (`:44`, `:59-62`, `:115`, `:152-166`) — la doc dice 9 y 12 en
sitios distintos, y las dos cifras son falsas. Y ⚠️ **la red de l10n no bloquea CI**: el paso que corre
`YalaTests` lleva `continue-on-error: true` (`.github/workflows/qa.yml:71`); lo que frena es el sello local
de `/gate`. Y ⚠️ `-only-testing:YalaTests/LocalizationParityTests` **ejecuta 11 de 15** y se salta
`StringsdictParityTests` y `BundleLocaleDriftTests`, que viven en el mismo fichero (`:15`, `:264`, `:277`).
**No existe ningún test de reglas de tono** (`LSFallbackTests` y `LocalizationContentRules` que L10N.md lista
tienen **cero ocurrencias** en el repo) ⇒ el copy nuevo no tiene pin automático: lo revisa un humano contra
BRAND-VOICE o no lo revisa nadie.

---

## §6 · Los grupos legacy desaparecen — LA TRAMPA

### La tabla, MEDIDA y completa: son CINCO polaridades, no dos

| Mecánica | TX de cuenta **REAL** | Espejo **VIRTUAL** (cuenta de sistema) | Coordenada |
|---|---|---|---|
| `freezeForSoftDelete` | **libera** los 3 punteros, conserva la fila | **conserva INTACTA, con los punteros puestos** | `GroupTransactionBridge.swift:1464-1468`; el virtual nunca entra en `txsToRelease` por `guard tx.account?.isSystemAccount == false` (`:1405`) |
| `OrphanedBridgedTxSweeper` | **libera** los 3 punteros | **BORRA la fila** | `.releasePointers` `:308-312` · `.deleteVirtual` `:313-315`; clasificación reusada literal en `:141-146` |
| `unbridgeExpense` / `unbridgeSettlement` | **BORRA** | **BORRA** | `:1276-1279` / `:1255-1258` — sin ningún filtro de cuenta |
| `unbridgeDeletedRemotely` | **BORRA** | **BORRA** | `:1335`, `:1349` |
| **`BridgeDeactivationSheet.deleteBridgedTransactions`** | **BORRA** | **CONSERVA** | `Yala/App/Views/Groups/BridgeDeactivationSheet.swift:173-175` — `for tx in txs where tx.account?.isSystemAccount == false { delete }` |

La quinta es **la inversa exacta del barredor** y **está a un tap del usuario**: toggle per-grupo
(`GroupSettingsView.swift:439`) → «Eliminar» → `performAction` (`BridgeDeactivationSheet.swift:122-123`).
Pierde el dinero real **y** se queda los fantasmas. Es el peor de los cinco resultados.

**Dos matices medidos que no se ven leyendo el clasificador:**

- **El freeze NO llama a `classifyForSoftDelete`** (su docblock dice que lo comparten). `computeFreezePlan`
  inlinea el predicado con **polaridad invertida** (`== false` en `:1405` vs `== true` en el sweeper `:283`)
  ⇒ para `account == nil`: el freeze **conserva** y el sweeper **libera**. Misma fila, dos destinos.
- **`freezeForSoftDelete` tiene SEIS call-sites, no 5** (`GroupService.swift:316`, `:643`,
  `AppBootstrapper.swift:1337`, `GroupsSyncClient.swift:2075`, `BridgeDeactivationSheet.swift:141` y `:150`).
- **El freeze deja fuera un tercer tipo de borrador:** `.groupScheduledExpense`
  (`Yala/Models/InboxDraft.swift:28`) lleva `splitGroupZoneID` (`ScheduledPaymentDraftService.swift:270`), el
  freeze lo **fetchea** (`:1457`) y **no lo convierte ni lo borra** (su bucle solo mira
  `groupExpense`/`groupSettlement`, `:1413`) ⇒ sobrevive apuntando a una zona muerta. El barredor tampoco lo
  ve (exige `splitExpenseID != nil || splitSettlementID != nil`, `:196`).

### Por qué `GroupService.softDelete` NO sirve — tres razones, no una

1. `guard group.isOwner` (`:279`) — la de la exploración.
2. `guard balances.allSatisfy({ abs($0.netBalance) <= 0.01 })` (`:293`) ⇒ **un legacy con deuda no se puede
   ocultar por ahí ni siendo owner.** Esta no estaba en la exploración y es la que más grupos deja fuera.
3. Llama `freezeForSoftDelete` (`:316`) = **la semántica del fantasma**, y además hace `clearOverride`
   (`:330`) cuyo `BridgeModeResolver.clearOverride` tiene **su propio `save()`** (`BridgeModeResolver.swift:170`).

Y no pasa por `validateGroupIsWritable`, al revés que `updateGroup` (`:207`), `setArchived` (`:258`),
`removeMemberLocal` (`:392`), `transitionPendingMember` (`:456`) y `changeRole` (`:480`).

### La recomendación (INFERIDO)

**Un barrido propio, `LegacyGroupsRetirement`, molde `OrphanedBridgedTxSweeper`: idempotente, sin sentinel,
en DOS fases (clasificar sin mutar → aplicar).** La segunda fase separada no es estética: es el punto 7 de la
regla del sweeper — `computeFreezePlan` compara `splitExpenseID` contra las TX que recibe, y mutar antes hace
que la comparación dé `false` siempre ⇒ borradores a `.manual` ⇒ **gasto duplicado al aprobarlos**.

1. **Predicado: la negación de `belongsToBackendChannel`, ANY-row por ZONA** (`isBackendGroup ||
   movedToBackendAt != nil`, `GroupBackendIdentityLogic.swift:63-65`, evaluado sobre todas las filas de la
   zona como en `GroupZoneCacheGate.swift:90-99`). Nunca el per-fila: captura la copia congelada y la gemela
   de un duplicado mixto.
2. **CONSERVA la fila `SplitGroup`** y le pone `isHiddenForAll = true`. **No la borra**, y la razón está
   medida: si la fila desaparece, `zoneHasSettledGroup` falla (`GroupChannelFreshness.swift:144`) ⇒ el gate
   devuelve `.noSettledGroup` (`GroupChannelFreshnessGate.swift:126`) ⇒ `NewTransactionView` calcula
   `bridgedPointerResolves = true` (`:174`) ⇒ **Borrar y Duplicar DESHABILITADOS** sobre un gasto que ya no
   existe (`:876`, `:888`) = el dinero fantasma **atrapado**, que es el bug
   `qa_groups-tx-fantasma-al-borrar-gasto-de-grupo`. Con la fila conservada, quedan habilitados.
   ✅ Y ocultar es seguro hacia fuera: en un legacy el drain **nunca emite** `is_hidden_for_all` (`:812` +
   `:722`) ⇒ el flag no sale del móvil.
3. **Bridge: semántica del BARREDOR, no la del freeze.** Real → **liberar**; virtual → **BORRAR**. El motivo
   no es teórico: **el barredor nunca podrá limpiarlos después**, porque `zoneIsSweepable` corta con `guard
   status.belongsToBackendChannel` (`OrphanedBridgedTxSweeper.swift:259`) **antes** de mirar la frescura, y
   una zona legacy no lo es. El propio fichero lo declara precio asumido en `:38-40`. ⇒ con el freeze, los
   espejos «presté X» quedan como **fantasma permanente y sin canario**.
4. **`account == nil` → tratar como REAL (conservar).** Dirección segura, y hay que escribirlo porque las dos
   mecánicas existentes discrepan justo ahí.
5. **`.groupScheduledExpense` → `.manual`**, o sobrevive apuntando a una zona muerta.
6. **PROHIBIDO en este camino:** `unbridgeExpense` / `unbridgeSettlement` / `unbridgeDeletedRemotely` (borran
   la TX real = destruyen dinero que salió de verdad) y `BridgeDeactivationSheet.deleteBridgedTransactions`
   (borra la real y conserva el fantasma).
7. **Cuándo corre:** barrido de arranque idempotente, **no** migración one-shot. Molde y razón del sweeper
   (`:38`, sin sentinel a propósito: es también la red de lo que no llegue a correr). Y **detrás de la misma
   evidencia de canal** que ya usa el sweeper si va a decidir por zona — aquí no hace falta, porque el
   criterio no es «el gasto no existe» sino «esta zona no pertenece a ningún canal vivo», que es estable.
8. **Sin aviso al usuario** (decisión del owner: «desaparecerlos y fue»). Las TX de cuenta real liberadas
   siguen visibles como transacciones personales normales, editables y borrables — que es lo correcto y lo
   que hoy no tienen.

### Los dos daños colaterales que hay que decidir

- ⚠️ **El caveat GDPR.** `hasLegacy` se calcula sobre grupos con `isHiddenForAll == false`
  (`GroupService.swift:1436-1437`) ⇒ ocultarlos **apaga** la línea `.legacyFootprint` del diálogo de borrado
  de cuenta (`AccountDeletionDebtLogic.swift:98`), que es justo el aviso de que tu nombre puede seguir en las
  zonas CloudKit. **RECOMENDADO:** que `hasLegacy` deje de filtrar por `isHiddenForAll` — el hecho es del
  servidor de Apple, no de la vista. Ocultar el grupo no borra la huella.
- ⚠️ **El seed de XCUITest crea grupos LEGACY.** `DevSeedGroups.swift:20` construye `SplitGroup(...)` **sin
  `isBackendGroup`** y el default del modelo es `false` (`SplitGroup.swift:52`) ⇒ **ocultar legacy sin tocar
  el seed deja sin datos a 22 tests en 9 ficheros** (GroupsSmokeUITests 9, GroupsRetentionUITests 2,
  UserDataResetScopeUITests 2, DeeplinkRoutingUITests 2, DeleteAccountDialogUITests 2, LaunchSliceUITests 2,
  GroupDetailDeeplinkColdLaunchUITests 1, GroupExpenseSuccessUITests 1, InboxConvertToGroupUITests 1).
  **El seed pasa a `isBackendGroup: true` en el MISMO commit.**

---

## §7 · La fábrica de zombis

**MEDIDO, y la evidencia es más fuerte que la documentada:**

- `GroupCreateRoutingLogic.route` abre con `guard flagOn else { return .cloudKit }`
  (`Yala/App/Logic/GroupCreateRoutingLogic.swift:29`) — la afirmación de la exploración es correcta.
- **Es irrecuperable.** `fetchCandidates`: **cero ocurrencias** en todo el repo. `migrate_group`: **cero en
  `gateway/src/`** — no es que esté revocada, **no hay endpoint**. `movedToBackendAt`: **un único escritor**
  (`SplitGroupDeduplicationService.swift:138`, alimentado por el `min` de los duplicados) ⇒ punto fijo en
  `nil`. `markerEnqueuedFlag`: **cero escritores**, columna muerta. Y `createShareLink` cae al `else` para
  todo `isBackendGroup == false` ⇒ `Groups.Errors.inviteFailed` **siempre**
  (`GroupDetailViewModel.swift:459-472`). Grupo de una persona, no invitable, para siempre.
- **Funciona OFFLINE y sin error visible.** El otro final que el docblock promete (un `CKError` crudo) exige
  un device que nunca sembró identidad: `seedIfNeeded()` devuelve el valor persistido sin tocar red
  (`GroupICloudIdentitySeed.swift:76`) y el boot lo siembra en cada arranque
  (`AppBootstrapper.swift:486-490`).
- **Cerrar el router cierra la fábrica ENTERA.** Los cuatro sitios que construyen `SplitGroup(` en `Yala/`:
  `GroupService.swift:142` (único call-site de producción: `GroupFormView.swift:284`, dentro de
  `case .cloudKit`), `GroupBackendMembershipService.swift:119` (backend), `GroupsSyncClient.swift:2495-2514`
  (born-remote del pull, que pone `isBackendGroup = true` en `:2514` ⇒ **un pull no produce zombis**) y
  `DevSeedGroups.swift` (fichero entero bajo `#if DEBUG`). **Aceptar un CKShare no existe.**
- **No rompe a nadie.** El transporte murió en la Fase 3 (`grep 'CKSyncEngine(' Yala/` = 0; los 47 hits de
  `SplitSyncManager` son todos comentarios) ⇒ **no existe el usuario con grupos CloudKit «vivos por
  CKShare»**. El router decide solo la CREACIÓN: leer, editar y calcular siguen igual.

**Y la ventana es peor de lo que la exploración dice, por tres vías medidas:**

1. **La cierra el ÉXITO, no el intento.** El `catch` de `refreshIfDue` no escribe snapshot
   (`CloudRemoteConfig.swift:286-290`) y un status != 200 tampoco (`:270-274`) ⇒ con el gateway inalcanzable
   el flag queda OFF **indefinidamente**.
2. **No es de instalaciones nuevas: el kill-switch la reabre en TODO el parque.** Con
   `GROUPS_BACKEND_ROLLOUT_PERCENT = 0` (`gateway/wrangler.toml:166`, hoy `"100"`) cualquier device tiene
   `flagOn == false` ≤6 h después, con su CTA «crear grupo» intacta. **Bajar ese percent es la respuesta
   operativa documentada a un incidente ⇒ el remedio ENCIENDE la fábrica.**
3. **Ninguna de las cuatro entradas fuerza refresh** (`GroupsContainerView.swift:327`, `:419`, `:689`,
   `:703`). El único `force: true` del camino de creación protege el **Welcome**
   (`WelcomeGroupsGateView.swift:140`) y **deja el tab desnudo**.

### La recomendación (INFERIDO)

- **La rama `.cloudKit` MUERE.** `route` pasa a devolver un caso nuevo `.channelOff` cuando `!flagOn`, con
  copy honesto — molde literal de `GroupsOrganizerGateLogic.Decision.blockedChannelOff` («ahora mismo no
  puedo abrirte grupos»), que describe un estado transitorio y no culpa al usuario.
- **`refreshIfDue(force: true)` antes de decidir, en las cuatro entradas** — «la intención del usuario ES
  evidencia de que el canal debería estar encendido», que es la misma regla que ya usa
  `GroupInviteChannelRoutingLogic` con un link backend. El `force` no es cosmético: sin él `refreshIfDue` es
  no-op en el caso exacto del bug.
- **`GroupService.createGroup` se queda sin call-site de producción** ⇒ decidir en el chip: muere con la rama
  (recomendado) o se marca como solo-tests. Dejarlo vivo y sin llamador es la familia de
  `AppAttestClient.ensureRegistered()`.
- ⚠️ **El pin NO puede ser un e2e.** El escenario es **inejercitable en el harness**: `decide()` cortocircuita
  a `absentDefault` bajo `isRunningTests || isUITestHost` sin leer el snapshot
  (`CloudRemoteConfig.swift:186`) y en **Yala Dev** `absentDefault` es `true` (`:120-126`). ⇒ tabla de la
  lógica pura + **source-scan del orden** (`force` antes de leer el flag) en las cuatro entradas, molde
  `GroupsOrganizerBranchTests:311-323`.

---

## §8 · Versión sustantiva vs. menor

**MEDIDO:** la maquinaria existe entera y **no se usa**. `GroupsConsentState.textVersion = 1`
(`:24`), `CloudConsentText.version = 2` con historial y criterio en el docblock (`:16-32`), y ese mismo
docblock **declara medido** que «ningún camino COMPARA esta constante con lo persistido […] Lo que la
versión hace es dejar registrado QUÉ texto se aceptó (trazabilidad), no gatear una re-petición». Los únicos
lectores de `*TextVersion` comprueban **presencia** (`BornCloudSignUpService.swift:365-376`) o resetean en
UITest (`AppBootstrapper.swift:607`). Cero comparaciones.

**Propuesta (INFERIDO): dos constantes, no una.** El owner pidió re-preguntar **solo si el cambio es
sustantivo**, y una sola versión no puede expresar eso:

```swift
enum GroupsConsentText {
    /// Se bumpea SIEMPRE que cambie el texto — es la trazabilidad de QUÉ se aceptó.
    static let version = 2
    /// La última versión SUSTANTIVA (cambió qué se trata o quién accede).
    /// Aceptar una versión anterior a ésta obliga a volver a preguntar.
    static let requiresReacceptanceFrom = 2
}
```

Con historial en el docblock, molde exacto de `CloudConsentText.swift:24-31`, que ya distingue el caso de la
corrección de redacción que **no** bumpeó.

**El arranque:** el estado que devuelve `groups_consent_state()` trae la `text_version` aceptada. Si
`aceptada < requiresReacceptanceFrom` ⇒ `isConsented == false` en la caché ⇒ la cadena vuelve a presentar el
consent, y la aceptación nueva **inserta una fila más** (la PK es `(user_id, text_version)`) sin tocar la
anterior. La traza queda completa: qué versiones aceptó esa cuenta y cuándo cada una.

**Cabe en C1** — es un campo del payload y una comparación. No merece chip propio.

---

## §9 · La visita (M1)

**MEDIDO — la visita tiene su propio JWT y el registro server-side funciona sin caso especial.** El Keychain
tiene **un solo slot** (`AuthClient.Configuration(storageKey: "yala.cloudauth.session")`,
`CloudAuthService.swift:176-186`) y el flujo M1 exige que el dueño haya **cerrado** su sesión antes
(`WelcomeCloudSignInView.swift:720` comprueba `StorageModePersistence.read() == .icloud`) ⇒ el slot está
libre, la visita firma la suya, `currentUserID` es **su** `sub` (`:200-202`) y `accessToken()` devuelve **su**
JWT. El attest se vincula al usuario del JWT por diseño del servidor (`gateway/src/sync/types.ts:93`).

**MEDIDO — NO reabre la frontera que M1 blindó.** La frontera de prefs es doble y sigue cerrada:
`PrefsSyncBehavior.resolve` devuelve `.localOnly` con el descriptor vivo
(`PreferenceSyncService.swift:44`) y `syncPrefsOnce` corta antes de push y pull
(`CloudSyncRuntime.swift:681`). **El consent server-side no entra por ahí**: el canal correcto es una lectura
propia con el JWT, y **el precedente completo ya existe y no toca prefs** —
`AccountEntitlementService.sync()` pide un hecho de la cuenta con el JWT (`:101`, `:118`) y lo cachea en
`AccountEntitlementStore` con el `userID` **dentro** del snapshot.

**⚠️ Lo que sí hay que resolver, y no estaba en el enunciado:**

1. **No existe dominio de `UserDefaults` por sesión** (§1): la caché de la visita cae en el dominio del
   dueño. ⇒ **la caché lleva el `userID` sellado dentro**, y su seguridad viene del sello, **no de la purga**
   — que es exactamente por qué `AccountEntitlementStore` es seguro (medido: su `clear()` no lo llama la
   entrada secundaria, pese a lo que dice su docblock; lo cubre el sign-out previo).
2. **El consent pasa a sobrevivir al sign-out.** Hoy `GroupsConsentState.clear()` tiene **cinco** call-sites
   (`SwiftDataConfiguration.swift:587`, `SecondarySessionBoundaryPurge.swift:49`,
   `CloudSessionSignOut.swift:153`, `:478`, `:557`). Con el registro en el servidor, esos cinco pasan a
   limpiar **solo la caché** y **jamás llaman al servidor** — el grant sin `delete` (§1) lo hace imposible
   por construcción. Eso es una mejora: hoy el `clear()` del cierre es una mina documentada en su propio
   docblock (`GroupsConsentState.swift:62-66`).
3. **Precedente a NO copiar, medido:** el consent de **NUBE** de la visita **sobrevive a su salida** —
   `confirmSecondaryEntry` lo escribe (`WelcomeCloudSignInView.swift:776` → `CloudConsentRegistrar.swift:49-50`)
   y ninguna purga de frontera lo retira (la purga solo limpia el par de GRUPOS,
   `SecondarySessionBoundaryPurge.swift:49`); peor, `MigrationWorkExecutor.adoptBackendAccount` re-emite el
   epoch **persistido** al outbox de prefs del DUEÑO (`:1195-1204`) ⇒ **la traza GDPR del dueño podría llevar
   la hora de aceptación de la visita.** Es el daño que el chip M0 describe, resuelto para el iKV y **no**
   para el espejo local. Anotarlo como residual (no es de este trabajo, pero el diseño no debe replicarlo).
4. **Residual adyacente medido:** `GroupsOrganizerOnboarding.writePreferences` escribe **seis** keys en el
   dominio del dueño desde una sesión de visita (`:129`, `:134-135`), y su `setLocal(groupsBetaUnlocked)`
   **esquiva el guard** que `9301b74d` acaba de poner para esa misma key en
   `GroupsDomainAdoptionMarker.swift:51`. El test que lo exime lo justifica por una premisa de alcanzabilidad
   que el propio commit rechaza para su hermano. **Es de la misma familia y este trabajo lo toca (§3.1): el
   chip C2 debe cerrarlo o declararlo residual explícito.**

---

## §10 · Registro documental

- El residual GDPR del chip M1 queda **CERRADO por C1**. Anotarlo en [[MODO-NUBE-SPEC-M1-REVIVAL]] §6.x y en
  el punto #19 de [[MODO-NUBE-REVISION-FLUJOS-NOTAS]] **al cerrar C1**, no antes.
- **Correcciones a `.claude/rules/gateway-attest.md`** que salen de §0 y van en el commit que toque el
  gateway: la guard estricta son **CUATRO** definiciones (falta `sync/account.ts:179`); los `{ nil }`
  supervivientes son **SEIS** y son omisiones, no literales, y uno (`BornCloudSignUpService.swift:162`) no
  lleva su porqué; y la coordenada `groups/rpc.ts:81-83` apunta al guard equivocado **en tres sitios**
  (`AttestWiringTests.swift:21`, `GroupsMembershipClient.swift:156`, `GroupService.swift:115`).
- **Correcciones a `.claude/rules/swiftdata-cloudkit.md`:** el molde vivo del intent durable es
  `GroupsPendingBridgeIntent` y la frase de su propio docblock que cita `GroupsIdentityPurgeIntent` como
  molde vivo (`:29-30`) está stale; las coordenadas de la lectura de `memberships` derivaron todas (reales
  hoy: idle `:1835`, post-save `:1942`, canario `:2025`, DTO `:3227`).
- **`qa/coverage-index.json`:** el área del educativo cita `GroupsOnboardingSignInCTATests` y
  `GroupsOnboardingSignInCTAWiringTests`, que **no existen** — son suites dentro de
  `YalaTests/GroupsOnboardingLogicTests.swift` (`:92` y `:167`). Corregir o `qa-sync` seguirá reportando
  orphans.
- El Atlas gana nodos **en el refresco F5**, no en estos chips.

---

## §11 · Riesgos, con el invariante que roza cada uno

| # | Riesgo | Invariante que roza | Mitigación |
|---|---|---|---|
| R1 | El header de attest no viaja en el método nuevo y nadie lo ve: **staging en `observe` lo deja pasar** y ningún build de Xcode puede validar contra producción | `gateway-attest.md` §«asimetría observe/enforce» | El header vive en `call()` (común); par de tests de transporte + **mutación obligatoria** (quitar el provider ⇒ exit 65) |
| R2 | El barrido de legacy usa el predicado **por fila** y se lleva una copia congelada o la gemela de un duplicado mixto | «se decide por ZONA, ANY-row» (la familia entera de los 14 puntos de `swiftdata-cloudkit.md`) | `belongsToBackendChannel` ANY-row + test con el duplicado montado a propósito (sin duplicado el escenario limpio pasa igual sin el fix) |
| R3 | El barrido corre **antes** de cerrar la fábrica y desaparece grupos creados esta semana | «lo que cierra la cadena es la ausencia de un PRODUCTOR, no un guard» | **C4 antes que C3, dependencia dura** |
| R4 | Se elige la mecánica del **freeze** y quedan fantasmas permanentes que ningún barrido puede tocar | «cuenta real → liberar; virtual → borrar; y el barredor NO ve zonas legacy» (`OrphanedBridgedTxSweeper.swift:259`) | Semántica del barredor, escrita en el docblock del barrido nuevo con la coordenada del guard que lo justifica |
| R5 | Alguien «unifica» la limpieza reusando `unbridge*` o el sheet de desactivación ⇒ **destruye dinero real** | «un borrado tiene DOS mitades y el criterio lo decide lo que DESAPARECE» | La tabla de 5 polaridades va en el docblock del barrido; source-scan que prohíba esos símbolos en el fichero nuevo |
| R6 | El consent se registra pero el epoch es el del reintento, no el de la aceptación | «el epoch es la hora de la ACEPTACIÓN» (`MigrationWorkExecutor.swift:1189-1204`) | `p_accepted_at` viaja en el intent, `now` inyectable; acotarlo server-side |
| R7 | Un `clear()` del cierre alcanza el servidor y borra el registro de una cuenta viva | append-only (`bdbc46d1`) | El grant **no tiene `delete` ni `update`**: imposible por construcción, no por convención |
| R8 | Ocultar los legacy **apaga** el caveat `.legacyFootprint` del borrado de cuenta | «no fabricar ni retirar afirmaciones legales» | `hasLegacy` deja de filtrar por `isHiddenForAll` |
| R9 | El intent sobrevive a un relevo de humano y registra el consent de A contra la cuenta de B | frontera M1 (`9301b74d`) | `userID` en el payload; si no casa, ni se intenta ni se descarta |
| R10 | La puerta unificada nace sin red determinista (el educativo no se monta bajo `-uitest`) | «el ratchet BLOQUEA si el backlog determinista crece» | Seam `-uitest-groups-educativo` en C2, o bajar el baseline **conscientemente** |
| R11 | El kill-switch deja al usuario sin poder aceptar los términos y la puerta se cierra en el último escalón | «sin canal no hay nada que consentir», pero hoy aceptar **nunca** falla | La puerta bloquea **antes**, en el educativo, con `blockedChannelOff`; el intent trata el 403 como transient |
| R12 | 22 XCUITest se quedan sin datos porque el seed crea grupos legacy | «no confiar en BUILD SUCCEEDED» | El seed pasa a `isBackendGroup: true` en el **mismo** commit |

---

## §12 · Los chips

Molde de los chips G/M: `[El porqué]` · `[Dónde, medido]` · `[La invariante que no puedes romper]` ·
`[Alcance CERRADO]` · `[Criterio de hecho]` · `[Contrato de salida]`.

---

### C4 · Cerrar la fábrica de zombis  — *va PRIMERO* — 🟢 HECHO (`ad291c7f`, validado 11-08)  ✅ **HECHO (2026-08-11, `ad291c7f`)**

> **Cerrado.** `route` pierde `.cloudKit` y gana `.channelOff`; `GroupService.createGroup` **borrada** (era
> el único productor de `SplitGroup` legacy y su único call-site de producción era esa rama); las cuatro
> entradas del tab pasan por el choke-point único `GroupsContainerView.requestCreateGroup`, con
> `refreshIfDue(force: true)` **antes** de leer el flag. Cero escrituras al bloquear.
>
> **Copy: cero keys nuevas.** Se reusa `welcome.groups.channelOff*` (ya en 16/16 locales) — el mismo hecho
> que dice la puerta del Welcome, y el mismo precedente por el que esa puerta reusa `welcome.cloud.blocked*`.
> El alcance del chip preveía «copy (16 `.lproj`)»; no hizo falta.
>
> **El `force` vive en el choke-point, no replicado en los cuatro call-sites.** Es lo que hace que una
> quinta entrada futura no reabra el agujero, y el source-scan lo sostiene con conteo (4 entradas, **una
> sola** decisión por vista).
>
> **Pin:** `YalaTests/GroupCreateRoutingLogicTests` (7, dominio 2×2×2 completo) +
> `GroupCreateRoutingWiringTests` (6 source-scan), con **6 mutaciones verificadas a exit 65**, cada una
> cayendo solo en su mitad. `/gate` verde: build ×2 sin warnings nuevos, 5671 unit en 543 suites, 17
> XCUITest en 4 suites (GroupsSmoke 9, GroupsEmptyState 2, OnboardingFlow 2, WelcomeChooser 4),
> `coverage-index` actualizado en el MISMO commit y ratchet sin mover.
>
> ⚠️ Confirmado al ejecutarlo: **el escenario NO es ejercitable en el harness** y queda dicho en el docblock
> de la lógica, en el de los tests y en el coverage-index, para que nadie lo persiga.
>
> **Lo que este chip DESBLOQUEA:** C3 ya puede correr sin llevarse grupos recién creados (R3 cerrado).
> **Lo que deja para C3, medido y NO tocado aquí:** `DevSeedGroups` sigue acuñando grupos legacy
> (`isBackendGroup` default `false`) — pasa a `true` en el commit de C3, que arrastra los 22 XCUITest.

**[El porqué]** Con el canal apagado, crear un grupo desde el tab fabrica un grupo local, no invitable y
**permanente**: no hay `migrate_group` en el gateway, `fetchCandidates` tiene cero ocurrencias y
`movedToBackendAt` no tiene escritor que lo ponga. Y la ventana no es de instalaciones nuevas: **bajar
`GROUPS_BACKEND_ROLLOUT_PERCENT` a 0 —la respuesta operativa a un incidente— la abre en todo el parque.**

**[Dónde, medido]** `GroupCreateRoutingLogic.swift:29` · las cuatro entradas de `requestCreateGroup`
(`GroupsContainerView.swift:327`, `:419`, `:689`, `:703`) y el switch de `:638-654` ·
`GroupFormView.swift:283-292` · `GroupService.createGroup` `:142` (único call-site de producción) ·
`WelcomeGroupsGateView.swift:140` (el único `force` del camino de creación, que protege solo el Welcome).

**[La invariante que no puedes romper]** El `force: true` va **antes** de leer el flag, y ese orden solo lo
puede fijar un **source-scan** (la lógica pura puede ser perfecta y sus tests verdes mientras nadie la llama
donde hace falta). Ningún camino nuevo escribe `onboardingMode`, `groupsBetaUnlocked` ni
`hasCompletedOnboarding` al bloquear — **cero escrituras**, molde `GroupsOrganizerGateLogic.Decision`.

**[Alcance CERRADO]** Caso `.channelOff` en `route` + `force` en las cuatro entradas + copy (16 `.lproj`) +
muerte de la rama `.cloudKit` y de `GroupService.createGroup` si queda huérfano. **NO** toca el educativo, ni
el consent, ni los grupos ya creados.

**[Criterio de hecho]** Tabla de `GroupCreateRoutingLogicTests` ampliada; **source-scan del orden** en las 4
entradas con **mutación verificada a exit 65**; `/gate` verde; l10n 16/16. ⚠️ **Nada de e2e**: el escenario es
inejercitable en el harness (`CloudRemoteConfig.swift:186` + `absentDefault` true en Yala Dev) — decirlo en el
docblock para que nadie lo busque.

**[Contrato de salida]** Ningún camino de producción puede crear un `SplitGroup` con
`isBackendGroup == false`. Queda escrito el porqué en el caso `.channelOff`.

---

### C1 · El registro del consent contra la cuenta — 🟢 HECHO (`bc0bb256`, validado 11-08) · ⚠️ SQL SIN APLICAR en staging/prod — 🟢 HECHO (2026-08-11) · 🚀 Worker desplegado 2026-08-12 (prod `1f72f6a5`, staging `645b6820`)

> **Cerrado.** El consent de Grupos vive ahora en `groups_consents` (Supabase), **append-only por el
> GRANT** (`select, insert` — sin `update`, sin `delete`), y se escribe/lee por dos `fn` nuevos de
> `POST /groups/rpc/:fn` bajo `requireUserAndAttest`. Las dos `PrefSyncKey` **salieron del enum** (39 → 37)
> y la copia local es un snapshot **sellado con el `userID` dentro** (`GroupsConsentState`), molde
> `AccountEntitlementStore`. **§8 dentro**: `GroupsConsentText.version` + `requiresReacceptanceFrom`, con la
> comparación que hasta hoy no hacía nadie (`GroupsConsentDecisionLogic`).
>
> **La guard elegida y su porqué:** `requireUserAndAttest`, y no es de estilo — las tres puertas ordenan
> sign-in ANTES que consent, así que no hay flujo pre-sesión análogo al del claim. ⇒ el `GroupsConsentRegistrar`
> construye su `GroupsMembershipClient` con `AttestSessionProvider.live` y el conteo de `AttestWiringTests`
> pasa de **7 a 8**. Como el header vive en `call(fn:args:)`, los dos métodos nuevos llevan además su **par
> de transporte** (provider vivo ⇒ header; provider nil ⇒ ausente): el escáner mira el init, no los métodos.
>
> **El intent durable** (`GroupsConsentPendingIntent`): sin TTL y **sin tope de intentos** (caducar es
> perder la prueba legal; el molde del bridge lleva tope porque allí cada arranque costaría un `save()` de
> SwiftData y aquí es un request), con **el `sub` en el payload** — si no casa, ni intenta ni descarta— y su
> propia escalera (`GroupsConsentRetryBackoffLogic`, hasta 6 h; MEDIDO: no existía ninguna primitiva de
> backoff reusable en el repo, son tres escaleras de forma distinta y ninguna sobrevive a un kill).
>
> **Y lo que el spec no preveía y sí hizo falta: la ADOPCIÓN del consent legacy.** Sin ella, sacar las keys
> del enum le habría vuelto a pedir el consent a todo el que ya lo dio. `readSnapshot()` es legacy-aware
> (deriva el snapshot en memoria, sin escribir, para que la primera lectura del primer render sea correcta)
> y `adoptLegacyIfNeeded` lo sella y **arma su registro** en cuanto hay sesión — que es literalmente lo que
> convierte C1 de «mover un registro» a «crearlo» para el parque.
>
> **Pin:** 51 tests nuevos (`GroupsConsentStateTests` · `GroupsConsentDecisionLogicTests` ·
> `GroupsConsentRetryBackoffLogicTests` · `GroupsConsentPendingIntentTests` · `GroupsConsentRegistrarTests` ·
> 4 de transporte) + `gateway/test/groups.consent.test.ts` (8: la guard estricta da 401 sin attest bajo
> `enforce`; `p_user_id` jamás viaja en el body) + la partición NEEDS_KEY/NO_KEY de `groups.enckey` ahora
> **derivada de `PARAM_ALLOWLIST`** (su docblock prometía «obliga a clasificar la nueva» y no lo comprobaba
> nadie). **SEIS mutaciones verificadas a exit 65**, cada una en su mitad: sin `attestProvider`; con
> `{ nil }` explícito; epoch = hora del reintento; sin el guard del `sub`; _disarm-then-attempt_; y el gate
> del wipe ciego al formato legacy.
>
> **Verde:** 5722 unit en 547 suites · 15 XCUITest (GroupsSmoke 9, WelcomeChooser 4, GroupsEmptyState 2) ·
> 287 tests offline del gateway · build ×2 sin warnings nuevos · `coverage-index` en el mismo commit.
> Los 2 rojos del gateway son los goldens contra staging real (piden `GROUPS_ENC_KEY` y red) y **fallan
> igual en HEAD limpio** — medido con `git stash`.
>
> ### SQL APLICADO EN LOS DOS ENTORNOS — 2026-08-12 ✅
>
> `g13_01_groups_consents`, método del gate §12 bloque A (precheck → apply → post-check con la TERNA →
> advisors). **Paridad byte-exacta**: los dos md5 de `pg_get_functiondef` salen IDÉNTICOS en staging y en
> producción, porque se aplicó **el mismo texto verbatim** en ambos (lección L3 de g10_01: el archivo del
> repo no siempre es lo aplicado — aplicando el mismo texto el problema no llega a existir).
>
> | | staging `fostjbbwstyuunmmefuk` | producción `kefvaiymtgytemwbltlz` |
> |---|---|---|
> | Migración | `20260812115736 g13_01_groups_consents` | `20260812120453 g13_01_groups_consents` |
> | md5 `record_groups_consent` | `1fab251ac926dc8f8e71bd307084a36a` | **idéntico** |
> | md5 `groups_consent_state` | `47b8829a8667aff4c5acab29f3fc2514` | **idéntico** |
> | Funciones en `public` | 34 → 36 | 34 → 36 (**paridad 36/36**) |
> | Filas tras los WIRE | 0 | 0 |
>
> ⚠️ **El md5 registrado NO es el del archivo `.sql`** (ese es `5f3f5c148a13d53099b7a1589a97641a`) sino el de
> `pg_get_functiondef` — confundirlos hace abortar una promoción por un falso positivo (L1 de g10_01).
>
> **Precheck (idéntico en ambos):** los 3 objetos a crear AUSENTES ⇒ **aditivo puro**; `auth.users` y el rol
> `authenticated` presentes; 8 tablas `split_*`/`group_*` intactas; `postgres.rolbypassrls = true`; mismas 3
> últimas migraciones en los dos entornos (`g6_02`, `g10_01`, `g12_02`). **Cero `DROP` en el diff**,
> verificado sobre el fichero además de a ojo — la lección del incidente del 2026-07-14.
>
> **Terna del post-check (los dos entornos):** owner `postgres` · `prosecdef=false` (**SECURITY INVOKER**,
> las dos funciones) · `search_path=public` · EXECUTE anon `false` / authenticated `true` · `proacl` sin
> PUBLIC · RLS habilitada, no forzada · PK `(user_id, text_version)` · FK a `auth.users ON DELETE CASCADE`.
> **Advisors: ninguna clase nueva** en ninguno de los dos (los WARN son las 15 `SECURITY DEFINER`
> preexistentes; las de C1 son INVOKER y no aparecen).
>
> **EL INVARIANTE DEL CHIP, EJERCITADO —no leído del catálogo— EN AMBOS ENTORNOS:** como `authenticated`,
> `UPDATE` → `permission denied`, `DELETE` → `permission denied`, `INSERT` con `user_id` ajeno → cortado por
> la RLS. Grant efectivo: `INSERT,SELECT` para `authenticated`, **nada** para `anon`. ⇒ el append-only lo
> enforza el servidor, y ningún `clear()` del cliente puede alcanzar el registro de una cuenta viva.
>
> **Comportamiento verificado:** clamp de futuro (pedí +5 años → quedó `now()`); `< 2015`, versión 0 y fecha
> nula → `yala_bad_input` (que el gateway traduce a 400 con el código preservado); idempotencia (2ª
> aceptación de la misma versión con otra fecha → `inserted:false` **conservando la fecha original**: ni
> duplica ni re-fecha); aislación cross-user en staging (B ve 0 filas de A y su estado es `{null, null}`).
> Todo en transacciones con `rollback` ⇒ **0 filas** en los dos entornos, y prod no recibió ni un dato de
> prueba (sus 2 usuarios reales, intactos).
>
> ⚠️ **Lección de instrumento, del método más que del chip:** el primer WIRE mezclaba escrituras y lecturas
> en un `UNION` — cuyas ramas **no tienen orden de evaluación garantizado**— y devolvió «0 filas» con los
> inserts ya hechos. Re-medido en statements secuenciales. Antes de leer un cero como señal, comprueba que
> el instrumento tocó algo.
>
> ✅ **EL SEGUNDO PENDIENTE — CERRADO el 2026-08-12 13:06:59Z** (registro del deploy al final de este
> bloque). Se conserva el diagnóstico original porque es lo que explica qué se desplegó y por qué:
>
> ⚠️ **EL SEGUNDO PENDIENTE, que sí bloquea el e2e y estaba fuera del enunciado — MEDIDO: el Worker de
> producción todavía no tiene las 2 entradas de `PARAM_ALLOWLIST`.** Último deploy real: **2026-08-04
> 12:01:53Z** (versión `265dadfa-af88-4f8f-a7e0-91e675698a04`, leído de `wrangler deployments list --env
> production` — jamás de la fecha que digan los docs, L4 de g10_01); las entradas viajan en `bc0bb256`, de
> hoy. Sin redespliegue, `/groups/rpc/record_groups_consent` devuelve **404 `yala_bad_request` ANTES de
> tocar PostgREST**: el schema está puesto y la ruta no existe. Hoy no daña a nadie (el build no está
> distribuido y el intent trataría el 404 como transitorio, CONSERVANDO la intención), pero **el e2e
> fracasará si se hace antes del deploy**. Lo pendiente de desplegar no es solo C1: `eb377123` sí entró en
> aquel deploy (11:51Z, diez minutos antes), así que son **`b5dab36d` + `bc0bb256` = 4 ficheros, +34/−3**.
>
> ### 🚀 Registro del deploy (2026-08-12) — lo que cierra el pendiente de arriba
>
> **Producción: versión `1f72f6a5-c6ac-4d32-9329-ba56e7b95e73`**, creada **2026-08-12T13:06:59.020Z**, leída de
> `wrangler deployments list --env production` (sustituye a `265dadfa-af88-4f8f-a7e0-91e675698a04` del
> 2026-08-04T12:01:53Z, que la línea de arriba midió). Staging fue primero, como manda el orden:
> **`645b6820-e8f3-40a5-aa34-796d87d55667`**. Desplegado desde `43b473c8` con `npm run deploy:{staging,production}`.
>
> ⚠️ **Corrección de la cifra de arriba, RE-MEDIDA hoy sobre el mismo rango:** `git diff a8663f3b..HEAD --
> gateway/` da **5 ficheros no-test, +47/−3** — `config.ts` (+5), `env.ts` (+5), `groups/killSwitch.ts`
> (+12/−1), `groups/rpc.ts` (+12/−2) y **`wrangler.toml` (+13)**, que el conteo «4 ficheros, +34/−3» dejaba
> fuera; los 13 del toml son exactamente la diferencia. Ninguno de los dos commits del rango tocó nada más del
> gateway (`43b473c8`, C3, no entra: no toca `gateway/`).
>
> **Percentiles: este deploy NO enciende nada.** `/config` de producción publica, verificado en caliente,
> `{cloudMode:100, cloudOnboardingChoice:0, groupsBackend:100, secondarySession:0}`, y `ENFORCE` sigue en
> `"enforce"` (jamás se tocó — apagarlo desactivaría App Attest para todo el gateway, proxy de IA incluido).
> El flip de `SECONDARY_SESSION_ROLLOUT_PERCENT` sigue siendo del owner y es el chip M5.
>
> ⚠️ **Lo que el deploy NO puede demostrar, y es estructural:** el «no 404» de la allowlist **no es observable
> sin un JWT de usuario válido**. En `rpc.ts` la auth va ANTES de la allowlist a propósito («no revelar la
> allowlist a un caller anónimo») ⇒ `record_groups_consent`, `groups_consent_state` y un `fn` inventado
> devuelven los TRES el mismo **401 `yala_attest_required`**. Un curl anónimo NO distingue ruta viva de
> inexistente; solo descarta el 404 del router (que sí se ve, «Not found», si te equivocas de prefijo — el
> Worker NO cuelga de `/v1` en workers.dev). Verificado por las dos vías que sí sirven sin credenciales:
> las 2 entradas aparecen **en el bundle** de `wrangler deploy --env production --dry-run --outdir`, y
> `/config` publica el campo `secondarySessionRolloutPercent`, nacido en el mismo push. El e2e con build de
> distribución sigue siendo del owner — el párrafo de abajo no se toca.
>
> ⏱️ **Gotcha medido, para el próximo que despliegue:** el campo nuevo de `/config` tardó **~30 s** en aparecer
> en producción **incluso con cache-buster** (URL distinta en cada intento ⇒ no es la caché HTTP; lo más
> probable, INFERIDO, es la propagación de la versión entre PoPs). En staging sí fue caché: `/config` manda
> `cache-control: public, max-age=300` y la lectura sin buster devolvió el cuerpo viejo mientras la busteada ya
> traía el campo. ⇒ **un `/config` que no publique el campo nuevo justo tras un deploy NO es un deploy
> fallido**: re-mide con buster y espera, antes de diagnosticar. (De paso: el docblock de `config.ts` afirma que
> «Cloudflare NO cachea en el edge respuestas generadas por Workers sin Cache API» — la lectura de staging es
> consistente con que sí lo hace, o con que hay otro intermediario. No se tocó; queda anotado.)
>
> **Tests del gateway antes de desplegar:** los 4 ficheros del diff, verdes (`groups.consent` 8 ✓, `config` 10 ✓,
> `groups.killswitch` 44 ✓, `groups.enckey` 25 ✓). Los 2 rojos son de ENTORNO, no de código, y lo dicen ellos
> mismos: falta `GROUPS_ENC_KEY` (`groups.goldens`) y `PUSH_ROLE_JWT` (`push.fanout`). `account.goldens` falló
> en la 1ª corrida y pasó en la 2ª (29 ✓): es el no-idempotente cuyo «ESTADO PREVIO REQUERIDO» documenta su
> propia cabecera, no una regresión. **`npm run typecheck` tiene 3 errores, los 3 en `test/` y ninguno en
> `src/`** ⇒ no afectan al bundle (wrangler compila solo `src/`); uno es nuevo de C1 —
> `groups.consent.test.ts:129`, el `headers` sin `Authorization` no encaja en el tipo inferido del helper `rpc`
> — y los otros 2 son preexistentes de `wrangler.forceupdate.test.ts` (`node:fs`, `import.meta.url`). **Sin
> arreglar**: fuera del alcance de un deploy.
>
> ⚠️ **Lo que SIGUE abierto y no lo puede cerrar quien escribió el chip:** el **e2e contra producción, con
> un build de distribución** (y después del deploy del Worker de arriba). Staging corre `ENFORCE = "observe"` (un request sin attest PASA) y ningún
> build de Xcode puede atestar contra producción (AAGUID). El schema ya está listo en los dos lados; lo que
> falta es ver el 200 real desde un device. Hasta entonces el cliente está **PINNEADO, no verificado**.
>
> **Residual medido y NO cerrado** (fuera del alcance de C1, anotado para C2/M1): el consent de NUBE de una
> visita sobrevive a su salida y `MigrationWorkExecutor.adoptBackendAccount` re-emite el epoch persistido al
> outbox del DUEÑO ⇒ su traza GDPR podría llevar la hora de aceptación de la visita. C1 no lo replica —el de
> Grupos ya no pasa por prefs— pero el de Nube sigue igual.


**[El porqué]** El consent de Grupos **no llega a Yala para el grueso del parque**, y no por un bug sino por
la rama: `storageMode` es `.icloud` por defecto y Grupos va al 100 % sin exigir Modo Nube ⇒ el epoch vive en
el iKV del Apple ID. Como responsables del tratamiento no podemos demostrar el consentimiento (Art. 7.1).
**Esto no es mover un registro: para casi todos es crearlo.**

**[Dónde, medido]** `GroupsConsentState.swift:38-45` (escritura) y `:31-33` (lectura) ·
`PreferenceSyncService.swift:96-100` + `:43-49` (la rama que decide el destino) ·
`PreferenceMergeLogic.swift:120-121` (las dos `PrefSyncKey`) · `gateway/src/groups/rpc.ts:35-59` (allowlist) y
`:116` (guard) · `GroupsMembershipClient.swift:242-249` (el header) ·
`AttestWiringTests.swift:54-68` (el conteo) · `GroupsConsentView.swift:104-107` (choke-point único de
escritura) · los cinco lectores: `ContentView.swift:964`, `GroupFormView.swift:281`,
`GroupsContainerView.swift:642`, `GroupJoinReconciler.swift:129`, `GroupBackendInviteEntryHandler.swift:40`.

**[La invariante que no puedes romper]** **Append-only, ahora enforceado por el grant** (sin `update`, sin
`delete`). El epoch es la hora de la **aceptación**, jamás la del reintento. El intent se **arma antes** de
intentar y se desarma **solo** con 2xx. La caché lleva el **`userID` dentro** (no hay dominio de
`UserDefaults` por sesión). Y la lectura **no** entra por el canal de prefs: la frontera M1 sigue cerrada.

**[Alcance CERRADO]** DDL + promo-SQL (2 artefactos a mano, `gateway/migrations` es solo D1) · 2 `fn` +
2 entradas en `PARAM_ALLOWLIST` · método(s) en `GroupsMembershipClient` · `GroupsConsentPendingIntent` +
retome (boot + post-sign-in) · caché sellada · **§8 entero** (las dos constantes y la comparación) · salida de
las 2 `PrefSyncKey` del enum. **NO** toca la cadena de pantallas (eso es C2) ni el legacy.

**[Criterio de hecho]** Tests: transporte del header (provider vivo/nil) con **mutación a exit 65** ·
idempotencia (aceptar dos veces no duplica ni re-fecha) · intent kill-safe (armar → matar → retomar) ·
`sub` que no casa ⇒ ni intenta ni descarta · 403 ⇒ conserva. Goldens del gateway. `/gate` verde.
⚠️ **La validación e2e contra producción la hace el owner con un build de distribución** — quien escribe el
fix no puede ejercitarlo y **no debe declararlo verificado**.

**[Contrato de salida]** Una cuenta que aceptó tiene fila en `groups_consents` con su versión y su hora.
Ningún camino del cliente puede borrarla. El consent sigue a la persona: entra en su iPad, hace login, y la
app ya lo sabe.

---

### C3 · Los grupos legacy desaparecen — 🟢 HECHO (2026-08-12) · *dependía de C4*

> **Cerrado.** `LegacyGroupsRetirement` (`Yala/Services/Groups/`) retira en el arranque toda zona SIN canal
> vivo: le pone `isHiddenForAll = true` **conservando la fila** y suelta su puente personal con la
> **polaridad del BARREDOR** — cuenta real → liberar los 3 punteros; espejo virtual de sistema → BORRAR.
> Cableado en `AppBootstrapper` 16.5.6 tras `awaitPersonalStoreReady`. Sin aviso al usuario.
>
> **Las cinco polaridades, resueltas donde se ven.** La tabla completa vive en la cabecera del fichero
> nuevo, con la quinta (`BridgeDeactivationSheet.deleteBridgedTransactions`, la inversa exacta del
> barredor) nombrada como prohibida, y un **source-scan que prohíbe los cuatro símbolos destructivos** en
> ese fichero — ignorando las líneas de comentario, porque la cabecera los nombra para explicar por qué lo
> están. La quinta polaridad se llevó además a `.claude/rules/swiftdata-cloudkit.md`, donde la lista decía
> dos.
>
> **UN solo gate, y la diferencia con el barrido de huérfanas está escrita:** `awaitPersonalStoreReady`
> sí (esto SALVA el store personal), `awaitGroupsChannelEvidence` **no**, porque la pregunta es «¿esta zona
> pertenece a algún canal vivo?» y eso es estable — MEDIDO: un grupo backend lleva `isBackendGroup = true`
> desde el instante en que su fila existe (`GroupsSyncClient.applyGroupMeta` :2514 born-remote y :2538
> adopción a TODAS las filas de la zona; `GroupBackendMembershipService.createGroup` :120 antes de
> insertar) ⇒ no hay ventana en la que un grupo vivo se lea legacy. Y los dos barridos **no compiten**: sus
> conjuntos de zonas son disjuntos por construcción (aquel excluye las zonas sin canal backend, este actúa
> solo sobre ellas), así que el orden entre sus Tasks no importa.
>
> **Lo que el spec pedía y va dentro:** predicado ANY-row por ZONA · fila conservada · dos fases · el
> tercer tipo de borrador (`.groupScheduledExpense` → `.manual`) · `hasLegacy` sin el filtro de
> `isHiddenForAll` (el caveat GDPR `.legacyFootprint` sigue encendiéndose con el grupo oculto — la huella
> es de Apple, no de la vista) · el seed a `isBackendGroup: true` en el MISMO commit.
>
> **Un matiz que el spec no decidía y aquí se decidió:** el barrido actúa también sobre el grupo legacy que
> el usuario YA había ocultado con soft-delete. Su freeze conservó el espejo virtual intacto y el barredor
> de huérfanas jamás podrá tocarlo ⇒ es exactamente el fantasma permanente que el contrato de salida
> nombra («ningún espejo virtual sobrevive apuntando a un grupo invisible»). Ocultar solo cuenta cuando
> cambia algo, o el barrido salvaría en cada arranque.
>
> **Pin:** `YalaTests/LegacyGroupsRetirementTests` (28 en 4 suites: decisión+polaridad, zona ANY-row con el
> **duplicado MIXTO montado a propósito**, barrido, y source-scan de cableado/orden/prohibiciones) +
> `AccountDeletionGroupsSummaryTests#legacyFootprint_survivesWhenTheGroupIsHidden`. **NUEVE mutaciones
> verificadas a exit 65**, cada una cayendo en su mitad: predicado por fila (caen los dos tests del
> duplicado mixto y ninguno más); polaridad del freeze; **clasificar después de mutar** (cae el test de
> comportamiento Y el source-scan del orden); `hasLegacy` filtrado; un grupo del seed legacy; sin
> call-site en el arranque; borrar la fila `SplitGroup`; contar los ya ocultos (rompe la idempotencia); y
> no convertir el borrador planificado.
>
> **Gate verde:** build ×2 sin warnings nuevos · **5751 unit en 551 suites** · **22 XCUITest en 9 clases**
> con el seed nuevo (GroupsSmoke 9, DeleteAccountDialog 2, UserDataResetScope 2, DeeplinkRouting 2,
> GroupsRetention 2, LaunchSlice 2, GroupDetailDeeplinkColdLaunch 1, GroupExpenseSuccess 1,
> InboxConvertToGroup 1) · `coverage-index` en el MISMO commit (3 áreas) y ratchet sin mover · audit limpio.
>
> **Residual MEDIDO y NO cerrado (fuera del alcance):** `computeFreezePlan` sigue sin mirar
> `.groupScheduledExpense`, así que el hueco del §6 persiste en los **seis** call-sites del freeze (borrado
> del grupo entero, salir, expulsión, soft-delete, tombstone remoto y el sheet de desactivación): ahí ese
> borrador sigue sobreviviendo apuntando a una zona muerta. C3 lo cubre solo en su propio camino;
> arreglarlo en el freeze cambia el comportamiento de seis llamadores y merece su propio chip.

**[El porqué]** Un grupo de la era CloudKit es hoy un zombi **plenamente escribible**: se puede crear gastos,
editar, liquidar y archivar sin una sola señal, y lo único que avisa es invitar. El transporte murió; la
sincronización está al 100 % muerta.

**[Dónde, medido]** `SplitGroup.isHiddenForAll` (`SplitGroup.swift:29`), dos escritores
(`GroupService.swift:297` y `GroupsSyncClient.swift:2509`) · `GroupService.softDelete:277-333` (los tres
bloqueantes) · la tabla de 5 polaridades de §6 · `OrphanedBridgedTxSweeper.swift:259` (por qué el barredor no
puede limpiar después) · `GroupChannelFreshnessGate.swift:126` + `NewTransactionView.swift:174` (por qué la
fila se conserva) · `GroupService.swift:1436-1437` + `AccountDeletionDebtLogic.swift:98` (el caveat GDPR) ·
`DevSeedGroups.swift:20` + `SplitGroup.swift:52` (los 22 XCUITest).

**[La invariante que no puedes romper]** El predicado es **ANY-row por ZONA**. La fila `SplitGroup` **se
conserva** (borrarla atrapa el dinero fantasma). **Cuenta real → liberar; espejo virtual → borrar.** Nunca
`unbridge*` ni el sheet de desactivación. Clasificar **antes** de mutar (mutar primero produce gastos
DUPLICADOS al aprobar los borradores). `account == nil` → tratar como real.

**[Alcance CERRADO]** `LegacyGroupsRetirement` (dos fases, idempotente, sin sentinel) + `.groupScheduledExpense`
a `.manual` + `hasLegacy` sin el filtro de `isHiddenForAll` + el seed a `isBackendGroup: true`. **Sin aviso al
usuario** (decisión del owner).

**[Criterio de hecho]** Tests de la clasificación con **duplicado mixto montado a propósito** (sin él, el
escenario limpio pasa igual sin el fix) · el barrido corre dos veces y no cambia nada la segunda ·
los 22 XCUITest **verdes** con el seed nuevo · `/gate` verde · `qa/coverage-index.json` actualizado en el
mismo commit.

**[Contrato de salida]** Un grupo de la era CloudKit deja de verse; el dinero que salió de una cuenta real se
queda como transacción personal editable; ningún espejo virtual sobrevive apuntando a un grupo invisible.

---

### C2 · La cadena unificada, el educativo y el estado vacío — 🟢 HECHO (`3a960fd9`, 2026-08-12) · *dependía de C1*

**[El porqué]** Hay **cuatro** puertas al mismo modo y solo una tiene guardias. Una de ellas —la card «Solo
grupos»— deja al usuario **sin cuenta en ninguna parte**, propaga `.groupInvite` por iKV con never-downgrade
(en su iPad ve una app recortada y vacía) y su única recuperación es restaurar por iCloud. Y el educativo
está suprimido **justo** para esa gente, por un argumento falso.

**[Dónde, medido]** `GroupsOnboardingLogic.swift:36` (el corte) y `:60-66` (el CTA de sign-in que se pierde) ·
`OnboardingView.swift:1816-1874` (lo que escribe la card) y `:530-536` (su único guardia) ·
`GroupsOrganizerFlowLogic.swift:41-46` · `GroupBackendInviteEntryLogic.swift:34-44` ·
`GroupCreateRoutingLogic.swift:28-33` · `GroupsEmptyStateLogic.swift:29` y sus dos consumidores
(`GroupsContainerView.swift:322`, `:626`) · el copy: `es.lproj:4281-4286`, `:4985-4991`, `:4843` ·
`GroupsContainerView.swift:373-376` (el educativo no se monta bajo `-uitest`).

**[La invariante que no puedes romper]** **Nada se persiste hasta saber quién es y a dónde va**: el nombre, el
modo y el consent se escriben **juntos y al final**, en `GroupsOrganizerOnboarding.completeSetup`.
`onboardingMode = .groupInvite` es never-downgrade cross-device: escribirlo antes de confirmar la ruta
propaga y no vuelve. **A6 no se toca.** El `force: true` **no viaja solo** con la puerta: si el educativo se
monta en otra vista, hay que re-cablearlo y mover su source-scan.

**[Alcance CERRADO]** `GroupsGateLogic` (tabla única) + las tres tablas derivadas + la card B dentro de la
cadena + el educativo sin el corte por `.groupInvite` + la línea sustantiva del paso 3 + `GroupsEmptyStateLogic`
a cinco casos + copy nuevo en 16 `.lproj` + seam `-uitest-groups-educativo`. **Cierra o declara residual** el
`setLocal(groupsBetaUnlocked)` de `GroupsOrganizerOnboarding.swift:134`.

**[Criterio de hecho]** Tabla completa de `GroupsGateLogic` (4 entradas × los estados) · los 4 casos de
`GroupsEmptyStateLogic` ampliados · **source-scan del `force`** en la puerta nueva · XCUITest del educativo
con el seam · l10n 16/16 con `add-l10n-key.sh` (16 ficheros, no 9 ni 12) y **revisión humana contra
BRAND-VOICE** (no hay test de tono: `LSFallbackTests` y `LocalizationContentRules` **no existen**) ·
device-qa de los 4 escenarios del owner.

**[Contrato de salida]** Las cuatro puertas llevan al mismo sitio y en el mismo orden: educativo → login →
consent. Nadie termina el onboarding de Yala en modo Grupos sin una cuenta. El estado vacío dice qué falta.

---

## §12-bis · Implementación de C2 (2026-08-12, `3a960fd9`)

**Qué cambia para quien usa la app.** Hay cuatro formas de entrar a Grupos y cada una pedía cosas
distintas. Ahora las cuatro llevan al mismo sitio y en el mismo orden: primero se cuenta qué es un grupo y
dónde se guardan sus gastos, después se entra a la cuenta, después se decide. **Nada se guarda hasta saber
quién es y a dónde va.** Y la lista vacía dice qué falta —verlo funcionar, crear la cuenta, volver a ella o
dar el permiso— en vez de repetir un mensaje que para la mitad de la gente era falso.

### Las tres correcciones que la medición hizo al chip

1. **La «cuarta puerta» existe; lo muerto era una función vecina.** `GroupBackendInviteEntryLogic.routesToBackend`
   no tiene call-sites de producción —su propio fichero lo declara— pero la coordenada que el chip citaba
   para la puerta C es `nextStep` (`:34-44`), viva en `GroupBackendInviteEntryHandler` y `GroupsSignInView`.
   Lo que sí se corrige del §3: quien decide **si** se entra por ahí es `GroupInviteChannelRoutingLogic.route`
   (por la forma del link); `nextStep` gobierna la cadena una vez dentro.
2. **`GroupsSignOutBannerMarker` NO sirve como `hadSessionEver`** — el §4 pedía medirlo antes de dar el
   atajo por bueno, y medido no vale: es **one-shot** (se arma solo en `finalizeGroupsOnlyClose`, se quema
   en el `onAppear` del banner y se desarma al re-firmar), así que tras mostrarse una vez quien SÍ tuvo
   cuenta volvería a leer «crea una cuenta». Y no cubre el cierre de sesión de nube completo. Se estrena
   `GroupsSessionHistoryMarker`, latch monotónico. **Su key vive en `groups.*` y NO en `cloudSync.*`**: ese
   prefijo está excluido del wipe a propósito (`DataWipeService`, «infra del propio sign-out/wipe … JAMÁS
   aquí»), así que ahí habría sobrevivido al handover y le habría dicho al humano nuevo que tiene grupos
   esperando en una cuenta que nunca creó.
3. **El `force: true` NO hubo que moverlo.** El chip avisaba de que «no viaja solo con la puerta»; medido,
   el educativo se monta DESPUÉS de `WelcomeGroupsGateView`, que sigue siendo el primer paso de la rama y
   donde vive el refresco forzado. Su source-scan se queda donde estaba, y hay un test nuevo que lo fija.

### Las decisiones de diseño, con su porqué

- **El educativo no se antepone en las CUATRO puertas, y es una medición, no un descuido.** Va primero en
  `.organizer` y `.onboardingCard`; en `.invite` el educativo es `GroupInviteOnboardingView` —contextual al
  link, con metadata del grupo— y anteponer el general daría **dos educativos seguidos**; en `.tab` lo
  presenta ya el `onAppear`, antes de que ninguna CTA de creación sea alcanzable, así que devolverlo desde
  `route` sería una segunda presentación compitiendo con ese sheet. En las cuatro el usuario ve un
  educativo antes de que se le pida identidad, que es el contrato.
- **El educativo se monta dentro de `GroupsBackendInviteModifier`** y no en un modifier propio: ese tipo ya
  es el DUEÑO ÚNICO del anchor de la cadena y el educativo es su paso 0; un anchor aparte para el escalón
  anterior a `GroupsSignInView` sería la regla (4) de Presentaciones. (La otra mitad de la razón es el
  type-checker — abajo.)
- **La card B arrastra nombre y divisa EN MEMORIA** (`GroupsOnlyOnboardingPayload`, un `@State`) y salta la
  pantalla del nombre. Que viaje en memoria y no en `UserDefaults` **es** la invariante hecha comprobable.
  La divisa elegida a mano gana sobre la derivación por región (G4): el guard de «solo si está ausente»
  protege de que una derivación automática tape una decisión del usuario, no al revés.
- **Un one-shot para el educativo, y no es simetría.** Cerrar con la «X» NO marca la preferencia (por
  diseño del educativo), así que continuar la cadena devolvería `.presentEducational` en bucle sin salida.
  Cancelar apaga la rama y vuelve al chooser, como los demás sheets.
- **Residual DECLARADO:** el `setLocal(groupsBetaUnlocked)` del alta se queda. `.groupInvite` ya lo implica
  por el segundo término de `GroupsDomainAdoptionLogic.isDomainOpen`, pero ese término muere si el usuario
  activa Yala completo más tarde, y la key es per-device y permanente.

### La regresión que el propio gate destapó, y que vale por el chip entero

Borrar `OnboardingView.completeGroupsOnlyOnboarding` se llevó por delante **su guard M1**
(`if !SecondarySessionStore.isActive()`), que nadie había listado como parte de lo que hacía. La card B es
justo el camino alcanzable con una sesión secundaria viva (la invitada entra con el onboarding ya marcado,
pero un borrado de datos en sesión lo reabre), así que en `.localOnly` ese `set` habría caído en el
`UserDefaults.standard` del **dueño** dejándole `.groupInvite` (rank 1) sobre su `.full` (rank 0),
irreversible por never-downgrade. Lo cazó `SecondaryOwnerDomainWiringTests` al correr el mutante.
`GroupsOrganizerOnboarding` **hereda el guard junto con el camino**, y su test invierte la aserción que
antes decía «este tipo NO lleva guard, y es una decisión».
⇒ **al eliminar una función, lista lo que hacía ADEMÁS de lo que la sustituye.**

### El efecto colateral que hubo que pagar: el `body` de `ContentView`

Con la cadena entera inline, el getter tardaba **591 s** en type-checkear y la compilación moría con
«unable to type-check this expression in reasonable time» (medido con `-warn-long-function-bodies`; **no**
era una expresión concreta: eran 33 eslabones y el coste es superlineal en la LONGITUD de la cadena). Se
partió en tres tramos (`rootContent` / `shellPresentations` / `shellObservers`) y los cuatro alerts de
datos salieron a `ShellDataAlertsModifier`. **Movimiento mecánico: no cambia ninguna decisión.** Corolario
para el yo-futuro: si al añadir una presentación vuelve a reventar, el arreglo es partir otra vez, no
revertir el cambio — y el diagnóstico se hace con el flag, no adivinando qué modifier tiene la culpa.

### Verificación

- Build ×2 ✓ (0 warnings nuevos) · **unit 5785 / 557 suites ✓** · **XCUITest 34 en 11 suites ✓** · audit
  limpio · ratchet OK.
- **Mutaciones verificadas a exit 65:** quitar el seam `-uitest-groups-educativo` → cae `MUTACIÓN (g)`;
  quitar el guard M1 del alta → cae el escáner de escritores del modo.
- **El educativo DEJA DE SER inalcanzable desde XCUITest**: el seam invierte el early-return (no lo retira
  — retirarlo haría que el sheet interceptara los taps de toda la suite de Grupos), y hay un test que
  afirma que SIN el arg sigue desmontado.
- **`BudgetAlertsConfigUITests` falló en la tanda de 11 y pasa aislado**, con mis cambios y sin ellos:
  contención de la tanda, no regresión. Anotado para no volver a perseguirlo.
  - **Re-verificado el 2026-09-04 (Frank), en una tanda de 33 suites:** vuelve a fallar en tanda
    (`test_enablingAlertsRevealsThresholds`, «No aparecieron los chips de umbral») y vuelve a pasar
    aislado, 2/2 en verde. Descartado que lo causara el borrado del recorrido del invitado de aquella
    sesión: su diff sobre la matriz de readiness es puramente sustractivo —quita los bloqueadores
    `restoreOffer` y `groupReconnect` y no añade ninguno—, y menos bloqueadores no pueden hacer que
    un chip deje de aparecer. La hipótesis de contención sigue viva.
- **Sin pin automático: el copy nuevo.** No existe test de tono (`LSFallbackTests` y
  `LocalizationContentRules` siguen sin existir), así que las 11 keys × 16 locales las revisa un humano
  contra BRAND-VOICE o no las revisa nadie.

### Lo que queda para device-qa (imposible en simulador)

La cadena COMPLETA desde el Welcome —educativo → login → consent → alta— necesita una sesión de nube real.
Y la rama `.signInToView` del estado vacío exige el latch armado, que `-uitest-reset` limpia a propósito
para no contaminar las corridas siguientes; su cobertura es la tabla unit + device-qa.

---

## §13 · Veredicto de tamaño para 2.1 y orden

**Estado (2026-08-12): LA OLA C ESTÁ COMPLETA.** C4 ✅ (`ad291c7f`) · C1 ✅ (`bc0bb256`) · C3 ✅ (`43b473c8`) · C2 ✅ (`3a960fd9`). Lo único que queda abierto de todo el spec es la verificación e2e de C1 contra producción, que hace el owner con un build de distribución.

**Orden obligatorio: C4 → C1 → C3 → C2.** (C1 y C3 son independientes entre sí y podrían ir en paralelo si
fueran dos sesiones distintas; C4 antes que C3 es **dependencia dura**, y C2 después de C1 evita construir la
cadena sobre una fuente de verdad que va a cambiar.)

| Chip | Tamaño | Por qué |
|---|---|---|
| **C4** | **Pequeño-mediano** — media sesión | Una lógica pura, cuatro call-sites, un copy. Lo que cuesta es el source-scan y aceptar que **no hay e2e posible** |
| **C1** | **Grande** — sesión larga | Cruza tres capas (DDL+promo-SQL fuera del deploy, gateway, cliente) y estrena un intent durable. El §8 cabe dentro |
| **C3** | **Mediano-grande** — sesión larga | El barrido es acotado, pero arrastra 22 XCUITest, el seed y un caveat GDPR |
| **C2** | **Grande** — sesión larga | Es el que más superficie de UI toca (4 puertas + educativo + estado vacío), el que lleva copy en 16 locales y **el peor cubierto**: el educativo no se monta bajo `-uitest` y no hay test de tono |

**El veredicto honesto: los cuatro caben en 2.1 pero no en una sesión ni en un commit.** Son **cuatro chips
secuenciales, cada uno con su `/gate`**, y aproximadamente **3–4 sesiones largas**. El owner ya decidió que
todo va en 2.1; lo que este spec añade es que **el orden no es negociable** (R3) y que **C2 sin C1 deja el
consent otra vez en local** — si hubiera que recortar por fecha, el corte natural es aplazar **C2**, no
partirlo: C4+C1+C3 dejan el sistema coherente (fábrica cerrada, registro legal creado, legacy retirado) y C2
es el que mejora la experiencia sin cambiar ninguna garantía.

**Lo que ninguna de las cuatro puede declarar por su cuenta:** la verificación e2e de C1 contra producción.
La hace el owner con un build de distribución, y hasta entonces el registro está **pinneado, no verificado**.

migrated from YalaWiki Backlog/modo-nube/qa_MODO-NUBE-SPEC-CONSENT-GRUPOS.md @ 1934e8ad
