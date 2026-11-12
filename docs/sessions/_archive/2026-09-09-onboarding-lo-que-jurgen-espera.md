---
updated: 2026-09-09
tags: [sesion, onboarding, welcome, decisiones]
estado: cerrado — consolidado en DECISIONS.md 2026-09-09
---

# Onboarding y Welcome — lo que Jürgen espera de la app, escenario por escenario

> Dictado por Jürgen durante el device-QA del 2026-09-09, contrastado por Frank con el código de `2.1`.
> Cada punto lleva **lo que se espera** y, si difiere, **lo que hace hoy** (medido). Al cerrar la sesión,
> lo que difiera sale como ticket; lo que sea decisión durable va a DECISIONS.

## Contexto medido (2026-09-09)

- Producción sirve `cloudOnboardingChoiceRolloutPercent: 100` (curl a `/config` del gateway prod).
  El repo dice `"0"` en `gateway/wrangler.toml:132` — **deriva**: un `wrangler deploy` desde el repo lo apagaría. → ticket.

## 1. El faro (iCloud-KV: «este Apple ID ya tiene cuenta nube»)

**Decisión:** el faro **encamina, nada más**. Si este Apple ID ya tiene cuenta nube, «Primera vez» lleva a
entrar con ella. Pero el usuario conserva la **libertad de crear otra cuenta con otro usuario** (otro
proveedor / otra identidad) si eso es lo que quiere.

**Hoy:** encamina (✔), pero además **bloquea** la creación de otra cuenta desde ese móvil: «Ya tengo
cuenta → Google» con una Google nueva devuelve «Tu cuenta se creó con Apple, vuelve atrás»
(`ProviderMismatchLogic`), y con faro puesto «Primera vez» nunca enseña la elección nube/privado.
**Pendiente de aclarar con Jürgen:** por dónde entra ese usuario a crear la segunda cuenta.

## 2. «Primera vez» → iCloud privado

**Se espera, en este orden:**
1. Apenas elige *privado*, la app **valida si hay datos en el iCloud del dispositivo**.
2. Si hay: alert con **doble confirmación**.
   - Borrar → **se borra** y **pide reinicio**. Tras el reinicio **ya no existen datos de iCloud en el
     dispositivo**, y abre el **onboarding completo de cero**.
   - Cancelar → vuelve a la elección nube/privado.
3. Si no hay: sin alert, directo al onboarding completo.
4. **Nunca** se muestra la pantalla de reinicio sin haber hecho esa validación antes.

**Hoy (instalación fresca):** elige privado → pantalla «reabre Yala» **sin validar** (el store neutro
está vacío, `hasLocalDataNow` da false) → al reabrir va **directo al onboarding**
(`ContentView:1390-1393`, consume el destino sin re-comprobar) mientras el espejo importa el histórico
de iCloud por debajo. El alert solo aparece cuando los datos ya estaban en el dispositivo al elegir.
**Es bug. Ticket al cerrar** (no existe aún: los dos tickets de «empezar de cero» son otros defectos).

## 3. «Vengo por un grupo» — pendiente de dictado

Anotado de la conversación: los grupos viven solo en la nube; entrar solo-grupos debe **ignorar** lo
personal que haya en iCloud. Medido: en instalación fresca ya es así (la rama no monta el espejo).
La puerta de «datos ajenos» solo bloquea el caso *móvil de otra persona con sus datos dentro*.

## 4. Descubrir que la cuenta de grupos ya es Yala completo — pendiente de dictado

Hoy no se hace: el sign-in de grupos no consulta `/account/exists`. Falta decidir: automático o pregunta.

## Rejilla por rellenar

| | Instalación fresca | Móvil con mis datos | Móvil de otra persona |
|---|---|---|---|
| Primera vez → privado | §2 | | |
| Primera vez → nube | | | |
| Ya tengo cuenta → iCloud | | | |
| Ya tengo cuenta → Apple/Google | | | |
| Vengo por un grupo → crear | §3 | | |
| Vengo por un grupo → invitación | | | |

## 5. Modelo de cuentas que Jürgen quiere (dictado 2026-09-09)

- El usuario elige entre **privado (CloudKit)** —para quien solo quiere que nadie vea sus datos— y
  **cuenta nube (Google/Apple)** —lo familiar: sign in/sign out como en cualquier app—.
- **Grupos es una mini-app dentro de Yala**: ajustes propios, login propio, cierre de sesión propio.
  Separada de lo personal, accesible desde Yala. Es el gancho («otro Splitwise») para traer usuarios.
- Un usuario **CloudKit personal** puede **asociar UNA cuenta nube de grupos** a la vez (es la que
  alimenta el bridge personal↔grupos) y **desasociarla** cuando quiera.
- Si la cuenta personal **es nube**, grupos **es esa misma cuenta**, sin opción de cambiarla: un solo
  login/logout amarra todo.
- Si un usuario CloudKit **sale de Yala**, puede entrar a grupos con **otra** cuenta nube (distinta de
  la que tenía asociada, o cualquiera) **sin tocar el contenedor de iCloud**.

**Medido contra el código (2026-09-09):** el store de Grupos es un archivo SwiftData aparte
(`YalaGroups`, `cloudKitDatabase: .none`) y nunca toca iCloud; hay UNA sesión nube por dispositivo
(`CloudAuthService.shared`) que comparten personal-nube y grupos, así que «una cuenta a la vez» y
«personal nube ⇒ grupos misma cuenta» ya son verdad por construcción; el cierre de sesión ya distingue
`groupsOnlySignOut` de `privateReset`/`cloudSecureSignOut`, y Ajustes ya pinta «cerrar sesión de grupos»
+ «salir de Yala» como filas separadas; Grupos tiene sus ajustes (`GroupsGlobalSettingsView`).
**Huecos:** (a) «asociar/desasociar» no existe como gesto con ese nombre en Ajustes para el usuario
iCloud; (b) el sign-in de grupos no descubre si esa cuenta ya es Yala completo (§4); (c) el faro
bloquea crear una segunda cuenta nube por la puerta «Ya tengo cuenta» (§1) — la puerta de grupos no
lo consulta, así que «salir y entrar a grupos con otra cuenta» sí es alcanzable hoy; (d) el bridge
corre siempre que hay grupos, no «solo si hay cuenta asociada» — con una sesión única es equivalente.
**Límite real de plataforma:** CloudKit privado es el Apple ID del teléfono; no tiene login/logout.
«Salir» = borrar local y dejar el contenedor en iCloud; «entrar» = «Restaurar desde iCloud».

## 6. Vocabulario y modelo de sesiones (dictado 2026-09-09)

- **«Cuenta invitada» se retira**: nombre erróneo. Jürgen propone **sesión privada** (la que vive en el
  dispositivo, CloudKit) y **sesión pública** (nube 100 %). Frank propone «privada» / «en la nube»
  («pública» en una app de finanzas se lee como «visible»). Pendiente de que Jürgen elija.
- La sesión privada **no es obligatoria**: habrá dispositivos solo-nube.
- Puede convivir **una sesión privada asociada a una cuenta nube de grupos** con **entrar a otras
  sesiones nube** (solo grupos o completas).
- Diagnóstico compartido: la experiencia es confusa porque hoy se exponen TRES ejes con nombres
  distintos —`StorageMode` (icloud/cloud), `OnboardingMode` (full/groupInvite/completed),
  `UsageFocus` (full/groupsOnly)— más la «sesión secundaria». Todos son derivables de dos ejes:
  **¿hay sesión privada?** × **¿qué sesión nube hay activa? (ninguna / solo grupos / completa)**.
- Medido: «invitad» aparece en 2 de 3719 strings ES; el nombre vive en código, tickets y rules, no en
  la UI. Renombrar es decisión de glosario, no barrido de código.

**Opinión de Frank sobre «desasociar»:** los grupos se van con la cuenta (son de la cuenta, el store
local es caché). Las filas puenteadas en Panel se quedan como movimientos personales normales —es
dinero que pasó— conservando su `splitExpenseID` para que re-asociar la MISMA cuenta re-enlace en vez
de duplicar; asociar OTRA cuenta no las toca. Alternativa descartada: borrarlas (deja agujeros en los
totales de meses cerrados). Nota: `unbridgeDeletedRemotely` borra la fila cuando el gasto de grupo deja
de existir — es otro hecho, y ahí borrar es correcto.
**Opinión sobre «X sesiones nube a la vez»:** UNA sesión nube activa por dispositivo, conmutable
(salir → entrar con otra); no un selector de cuentas simultáneas. La infra de sesión secundaria
(store por sesión + dominio de prefs por sesión) ya es la semilla del «conmutar».

## 7. Onboardings derivados del modelo (conversación 2026-09-09)

**Decidido por Jürgen:** una sesión nube activa por dispositivo, conmutable. El backend debe poder
decir «completa» / «solo grupos». La card «Grupos» sale del paso *propósito* del onboarding personal.

**Tres bloques:** [I] identidad nube (Apple/Google → ¿existe? → nueva / completa / solo grupos, excluyentes);
[P] onboarding personal (los 8 pasos); [G] alta de grupos (consentimiento + nombre + moneda).

**Flujos:** 1 privado → validar iCloud → [P] · 2 nube → consentimiento → [I] → nueva: [P]; existente: = 5 ·
3 grupo → [I] → nueva: [G]; solo grupos: entra; completa: entra completa + Grupos · 4 iCloud → restaurar ·
5 Apple/Google → [I] → completa: adopta; solo grupos: entra; no existe: botón al flujo 2 ·
6 privada + asociar grupos (desde Grupos) → [I] → nueva/solo grupos: [G]; completa: conflicto ·
7 conmutar → cerrar sesión nube → chooser.

**«Yala completo» ≠ «nube completa»** (Jürgen): Yala completo = personal + grupos, y lo personal puede
ser privado (CloudKit) o nube. ⇒ el solo-grupos que activa Yala completo tiene DOS destinos: *privada +
grupos asociados* o *nube completa*. Hay que preguntarle — con el MISMO chooser que «Primera vez».

**Hallazgos medidos (2026-09-09), ambos ticket:**
- **T1 · El segundo arranque de un solo-grupos monta el espejo de iCloud.** Arranque 1 (instalación
  fresca): `.neutralNoMirror`. El alta solo-grupos no arma el neutro duradero (`armNeutralMount` tiene
  UN llamador: el boot-wipe, `SwiftDataConfiguration:689`) y el archivo del store ya existe ⇒ arranque 2:
  `personalStoreDecision` cae en `iCloudAvailable ? .iCloudMirror : .localNoMirror` (`:341-342`,
  inputs `:1172-1178`). El espejo se adjunta al store personal del solo-grupos e importa lo que haya en
  el iCloud privado del Apple ID. Contradice «entrar a solo grupos e ignorar lo personal en iCloud».
- **T2 · «Activar Yala completo» no pregunta dónde viven los datos personales.**
  `FullModeActivationView` reusa [P] con nombre y moneda prerrellenados y escribe
  `onboardingMode = .completed` + `usageFocus = .full`; ni `storageMode` ni elección privado/nube
  (`:86-100`). Aterriza en el store que esté montado — que por T1 puede ser el espejo de iCloud con
  datos viejos, sin validación ni alert.

**Flujo 6, cómo se llega:** usuario con sesión privada en este móvil que, desde Grupos, asocia una
cuenta nube que YA es completa (la creó en otro móvil, o aquí antes de «salir de Yala»). Raro pero
alcanzable. **Recomendación de Frank:** bloquear con copy claro y llevar a «Ya tengo cuenta» (que
reemplaza la sesión privada con confirmación; iCloud queda intacto). «Migrar» = el cutover privado→nube
existente, pensado para una cuenta NUEVA; sobre una cuenta con datos sería una FUSIÓN de dos
datasets personales, que no existe y no conviene construir.

**Flujo 6, decidido (Jürgen):** bloquear. Dos salidas: «Ya tengo cuenta» (entrar con esa cuenta completa,
reemplazando la sesión privada) o «asociar otra cuenta» solo para grupos. **Onboarding: cerrado.**

## 8. Cierres de sesión y salidas (conversación 2026-09-09)

**Medido, hoy:** 7 verbos visibles («Cerrar sesión», «Cerrar sesión de grupos», «Salir de Yala en este
dispositivo», «Vaciar datos», «Eliminar mi cuenta», «Salir del grupo», borrar «copia vieja de iCloud»)
sobre **11 operaciones** (`DestructiveScopeLogic.Operation`), elegidas por **4 caminos**
(`CloudSignOutFlowLogic.Path`) y **4 layouts de filas**, en función de tres estados que el usuario no ve
(`storageMode`, modo groupInvite, sesión secundaria). 14 tickets vivos en el área, 9 de «secundaria».
**El peor:** para la sesión privada, «Cerrar sesión» = `.privateReset`, que **NO toca datos**: vuelve al
Welcome con el corpus del dueño vivo en el dispositivo. Esa ventana es la que obliga a la puerta de
«datos ajenos» y origina buena parte de los tickets de «secundaria».

**Propuesta de Frank — un verbo por sesión, y los datos aparte:**
| Sesión | Verbo | Qué hace |
|---|---|---|
| Privada | **Salir de Yala en este dispositivo** | borra lo local; iCloud intacto; vuelve al Welcome |
| Nube completa | **Cerrar sesión** | sube pendientes, borra lo local, cuenta intacta (= `cloudSecureSignOut`) |
| Nube solo grupos (sola o asociada) | **Desasociar / Cerrar sesión de grupos** | cierra solo grupos (= `groupsOnlySignOut`) |
| Datos | **Vaciar datos** | privada: local + iCloud; nube: contenido de la cuenta. Grupos, nunca |
| Datos | **Eliminar mi cuenta** | solo sesión nube |
| Legado | copia vieja de iCloud | a «avanzado»; desaparece con el tiempo |
La «sesión secundaria» deja de ser un caso: es una sesión nube en un móvil con sesión privada ajena;
su verbo es «Cerrar sesión». Qué filas se pintan se DERIVA de los dos ejes, no de tres flags.

**Decidido (Jürgen):** 1-4 sí. Y el modelo «equipo»: si el iCloud privado tiene una cuenta nube asociada
para grupos, **se mueven juntas**. Cerrar sesión = sube cambios de grupos → limpia local → iCloud intacto
→ Welcome. **No existe «salir solo de grupos»** en ese caso. Nube completa: sube cambios → limpia local →
Welcome. **Botones: «Cerrar sesión» y «Vaciar datos», nada más.** La cuenta asociada se ve y se
desasocia/reasocia en «¿Dónde viven tus datos?», con copy correcto.
**Aviso de Frank:** App Store Guideline 5.1.1(v) exige borrado de cuenta in-app cuando la app crea cuentas
⇒ «Eliminar mi cuenta» no puede desaparecer para sesiones nube; puede vivir DENTRO de «Tu cuenta de Yala»
en vez de como botón principal.

## 9. Qué más toca el modelo (medido 2026-09-09)

19 vistas leen hoy alguno de los tres estados (`.groupInvite` / `usageFocus` / secundaria / `storageMode`):
Settings ×5 (Storage, UserDataReset, GroupsRetention, Notifications, Theme) · Groups ×5
(FullModeActivation, GroupInviteOnboarding, GroupExpenseForm, GroupRecords, SettlementForm) ·
Onboarding ×4 · Profile ×2 (Profile, YalaAccount) · More · ExportWizard/GroupsExport ·
Shared/SecondaryHydrationBanner. Fuera de vistas: 9 ficheros en CloudSync, 3 en Utils (incluida la
decisión de mount), 2 en App/Services. **32 strings de nudge «Activar Yala completo»** (todos pasan
a preguntar privado/nube). `GroupsRetentionView` («Seguir con mis grupos» tras vaciar) pierde razón de
ser si «Vaciar datos» nunca toca grupos. Pendiente de mirar: widgets/Siri/Apple Pay bajo solo-grupos;
notificaciones de informes/recordatorios sin datos personales; la infra de sesión secundaria (M1, 0 %
en prod) y sus 9 tickets, re-leídos contra el modelo. **Fuera de mi territorio:** web, FAQ, política y
ficha de la App Store dicen que Grupos viaja «por iCloud» (revisión web L2, 3-sep) — es de Lola.

## Cierre de la sesión (2026-09-09)

Lo dictado aquí está consolidado en **`docs/DECISIONS.md` → «[2026-09-09] Sesiones — dos ejes (privada ×
nube), un verbo por sesión, y Grupos como mini-app»**, que es la referencia de todo lo que sigue. De
esa decisión salen **13 tickets** en `tickets/backlog/` (orden de implementación en el propio ADR) y se
**descartan 12** de la sesión de visita (M1), cada uno con su motivo en la línea `Why:`. El glosario
lleva los términos nuevos. Este documento queda como acta: no se actualiza; lo vivo está en el ADR y en
los tickets.

Lo que NO se hizo en esta sesión, a propósito: ningún cambio de código, ningún device-QA registrado
como PASS (la reinstalación fresca de Jürgen sirvió para medir, no para cerrar tickets de `qa/`).
