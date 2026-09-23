---
id: full-mode-activation-must-ask-where-personal-data-lives
status: qa
priority: high
area: "groups, onboarding, modo-nube"
created: 2026-09-09
source: "medido durante el device-QA guiado del 2026-09-09 · ADR 2026-09-09 «Sesiones — dos ejes» §8"
updated: 2026-09-23
---

# «Activar Yala completo» no pregunta dónde van a vivir tus datos personales

## El síntoma, en lenguaje de usuario

Uso Yala solo para grupos. Toco «Activar Yala completo» (desde Ajustes o desde cualquiera de los 32
empujones que hay repartidos por Grupos). Me sale el onboarding con mi nombre y mi moneda ya puestos y
al terminar tengo Panel, cuentas y presupuestos… **sin que nadie me haya preguntado si quiero mis
finanzas en mi iCloud privado o en mi cuenta de Yala.** Aterrizan donde caigan.

## Lo que Jürgen decidió (ADR §8)

«Yala completo» no es «nube completa». Yala completo = personal + grupos, y lo personal puede ser
**privado** (CloudKit) o **en la nube** (la misma cuenta que ya usa para grupos, que pasa a ser
completa). Quien activa Yala completo desde solo-grupos **elige con el mismo chooser** que ve quien
entra por «Primera vez» (las dos cards: «Tu cuenta en tu iCloud privado» / «Tu cuenta en la nube»).

## Lo medido (2026-09-09, árbol `3a94604e`)

- `Yala/App/Views/Groups/FullModeActivationView.swift` reusa `OnboardingView` con nombre y moneda
  prerrellenados (docblock `:1-8`) y al terminar escribe `onboardingMode = .completed` y
  `usageFocus = .full` (`completeFullActivation`, `:86-100`). **Ni `storageMode`, ni elección, ni
  validación de iCloud.**
- Los datos aterrizan en el store que esté montado. Por `groups-only-second-launch-mounts-icloud-mirror`,
  desde la segunda apertura ese store lleva el espejo de iCloud con lo que hubiera en el Apple ID ⇒ el
  onboarding «completo» corre sobre datos viejos sin el alert de «Detectamos datos previos».

  > **Esa premisa CAMBIÓ el 2026-09-10** (mitad 1 de `groups-only-second-launch-mounts-icloud-mirror`):
  > una sesión solo-grupos ya monta sin espejo en todos los arranques, así que el onboarding de aquí
  > **ya no corre sobre datos viejos bajados solos**. Lo que este ticket arregla sigue vivo y sigue
  > siendo `high`, pero el daño cambia de forma: hoy `completeFullActivation` **levanta** el neutro
  > (`StorageModePersistence.clearGroupsOnlyNeutralMount()`), así que el espejo se adjunta en el
  > arranque siguiente **sin preguntar nada** — el histórico del Apple ID le cae encima al reabrir, no
  > antes. El chooser de este ticket es justo lo que tiene que decidirlo, y quien lo implemente debe
  > mover ese desarme a la rama «privado» en vez de dejarlo incondicional.
- 32 strings `groups.nudge.*` en `Yala/Resources/es.lproj/Localizable.strings` (y sus 15 hermanos)
  empujan hacia esta pantalla con el copy «Activar Yala completo».

## Alcance

1. Al activar: **chooser privado / nube** (reusar `WelcomeNewChooserView`, mismas cards, mismo gate de
   visibilidad `WelcomeAccountChoiceLogic.visibleNewOptions`).
2. **Privado** → validación de iCloud + alert con doble confirmación (misma pieza que
   `welcome-private-fresh-start-skips-icloud-check`; depende de ella) → adjuntar el espejo (relanzar si
   hace falta) → onboarding personal [P] prerrellenado. Resultado: celda «privada + grupos asociados»
   del ADR: la cuenta en la nube que ya tenía queda **asociada** para grupos.
3. **Nube** → la cuenta en la nube que ya tiene pasa de «solo grupos» a «completa» en el backend
   (depende de `backend-account-kind-complete-or-groups-only`) → onboarding [P] → `storageMode = .cloud`
   y el motor de sync personal arranca (el mismo tramo que el alta born-cloud recorre hoy tras
   `activateBornCloudStorage`). Resultado: celda «nacida en la nube».
4. Copy: el CTA puede seguir diciendo «Activar Yala completo»; lo que cambia es que ahora pregunta.
5. **Ratificado por Jürgen (2026-09-09):** en la rama *privado*, si iCloud tiene datos, se ofrece **«Restaurar mis datos»** además de borrar/cancelar. Quien llega aquí no es «nuevo» (entró por grupos
   y puede ser un usuario privado de antes); mandarlo a cerrar sesión → «Ya tengo cuenta → iCloud» →
   asociar de nuevo para conseguir lo mismo es un rodeo. Restaurar = el mismo recorrido de «Ya tengo cuenta → iCloud» (`WelcomeRestoreView`: resumen → continuar), terminando en D (privada + la cuenta de grupos asociada).

## Criterios de aceptación

- [ ] Desde solo-grupos, «Activar Yala completo» muestra el chooser antes de cualquier onboarding.
- [ ] Privado + iCloud con datos → alert con TRES salidas; borrar → onboarding limpio; restaurar → los datos
      de iCloud aparecen y la cuenta de grupos queda asociada; cancelar → vuelve al chooser.
- [ ] Privado + iCloud vacío → onboarding directo; al terminar, «¿Dónde viven tus datos?» muestra
      «iCloud privado» y la cuenta de grupos como **asociada**.
- [ ] Nube → al terminar, el backend devuelve `kind = complete` para la cuenta, `storageMode == .cloud`
      y el sync personal está vivo (mismos canarios que el born-cloud).
- [ ] Los grupos y sus gastos siguen intactos en los dos caminos; el bridge al Panel arranca solo
      DESPUÉS de completar [P].
- [ ] Ninguno de los 32 nudges lleva a un onboarding sin chooser.

## Cómo se prueba

- Unit: el ruteo (chooser → destino) como lógica pura; `OnboardingStepPlan` con prefill.
- XCUITest: el chooser aparece desde solo-grupos (seed uitest de solo-grupos + `-uitest-cloud-chooser`).
- Device-QA: las ramas privado (CloudKit) y nube (backend staging) enteras.

## Depende de

`welcome-private-fresh-start-skips-icloud-check` · `backend-account-kind-complete-or-groups-only` ·
`cloud-sign-in-discovers-account-kind`.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

- **El historial de grupos al Panel se PREGUNTA.** Al terminar el onboarding se le ofrece traer al Panel
  los gastos de grupo que ya existían. No se vuelca solo ni se ignora: son **dos caminos** y los dos se
  prueban. Cuida los duplicados en el que sí vuelca (el bridge SplitExpense ↔ TransactionItem es de los
  sitios donde un bug sale caro: review adversarial obligatoria).
- **Al restaurar de iCloud, gana lo restaurado.** El prefill de nombre y moneda que venía de Grupos **se
  descarta**: los datos de iCloud son la vida anterior del usuario en Yala y vuelven como estaban,
  preferencias incluidas. Sin mezclas.
- **La promoción a `complete` en el servidor es el ÚLTIMO paso.** El backend no se toca hasta que el
  onboarding personal termina; si el usuario abandona a mitad, sigue siendo solo-grupos y no queda una
  cuenta marcada «completa» sin datos personales detrás. Ordena el flujo para que sea así — no guardes
  un punto intermedio ni deshagas nada después.
- **La tarjeta de nube dice que es LA MISMA cuenta.** En este contexto el copy tiene que dejar claro que
  se usará la cuenta que ya tiene para grupos, no una segunda cuenta nueva. Es una variante de texto del
  chooser, en los 7 idiomas.

---

## Lo implementado (2026-09-11)

El árbol de decisiones entero, con lo medido que lo sostiene, está en el «Paso 0» del encargo
(`encargos/lanzados/2026-09-10-full-mode-activation-must-ask-where-personal-data-lives.md`) y en el PR.
Lo que cambia para quien usa la app:

- **«Activar Yala completo» pregunta primero «¿Dónde guardamos tus finanzas?»**, con las dos cards del
  Welcome. La de nube dice que es la misma cuenta que ya usa para sus grupos. Vale para las cinco entradas
  (Perfil, Más, Panel, Grupos y detalle de grupo): todas abren la misma sheet.
- **Privado** pasa por la puerta de iCloud del paso 4: «comprobando», y según lo que haya, sigue sola, avisa
  con cifras y tres salidas (restaurar, borrar con segunda confirmación, cancelar), avisa de que no hay
  iCloud o de que falló la red. Con el store en neutro pide reabrir Yala, y al reabrir sigue el onboarding
  —o Restaurar— donde lo dejó. **El borrado es solo de la zona de iCloud**: lo local de una sesión
  solo-grupos nunca vino de iCloud. Cancelar el onboarding tras reabrir devuelve a solo-grupos, con su
  mount sin espejo.
- **Nube**: consentimiento → onboarding → la pregunta del historial → «Activando tu cuenta…» → Panel. La
  cuenta se promociona al final; si la persona abandona antes, no se ha escrito nada, ni aquí ni en el
  servidor. Si la cuenta ya tenía lo personal reclamado, se bloquea sin escribir nada. Con la promoción en
  vuelo no hay forma de cerrar la sheet, tampoco con VoiceOver.
- **Restaurar**: los mismos screens de «Ya tengo cuenta → iCloud». Gana lo restaurado, y los gastos de
  grupo se re-puentean DESPUÉS de pasar a modo completo —en solo-grupos el bridge borraría las
  transacciones reales restauradas—, de forma que cada gasto sale una sola vez. Esa convergencia es
  durable: si el import no se asienta o la app muere, el arranque la reintenta, y lo que el bridge aún no
  puede atender pasa a su intención durable. **«Volver» una vez reabierta la app no deshace nada**: cierra
  la sheet y la activación queda a medias —el bridge cerrado, para que nada re-puentee encima del corpus
  que está bajando— y se reabre sola en el siguiente arranque hasta terminarla.
- **La pregunta del historial**, solo si hay gastos de grupo con filas en lo personal: «Sí» las deja como
  están; «No» apaga los tres toggles de Ajustes de Grupos y el «cuenta los gastos compartidos» de los
  presupuestos que el onboarding acaba de crear. Ninguno de los dos escribe una transacción.
- **Una instalación solo-grupos anterior al paso 5**, con el espejo de iCloud ya puesto, no ve el chooser:
  ve «Antes, vuelve a instalar Yala». Sobre ese store ninguna rama es segura.
- **La oferta**: quien entra por «Primera vez → nube» y resulta tener una cuenta solo-grupos ve la
  activación en cuanto su sesión de grupos queda montada (ADR §7).

## Los criterios, uno a uno

- [x] Desde solo-grupos, el chooser va antes de cualquier onboarding — XCUITest
      `FullModeActivationChooserUITests` + la tabla de `FullModeActivationFlowLogicTests` (ninguna
      combinación del gate abre el onboarding directo).
- [ ] **DEVICE** · Privado + iCloud con datos → tres salidas; borrar → onboarding limpio; restaurar → los
      datos vuelven y los grupos siguen; cancelar → vuelve al chooser. La puerta es la del paso 4, con su
      unit; lo que no se puede ver sin CloudKit es que la sonda, el borrado y el espejo hagan lo esperado.
- [ ] **DEVICE** · Privado + iCloud vacío → onboarding directo; «¿Dónde viven tus datos?» dice «iCloud
      privado». **Que la cuenta de grupos aparezca «asociada» en esa fila lo pinta el ticket 10**
      (`groups-account-association-in-storage-row`), no este.
- [ ] **DEVICE** · Nube → `kind = complete` en el backend, `storageMode == .cloud` y el sync personal vivo.
- [ ] **DEVICE** · Los grupos y sus gastos siguen intactos en los dos caminos. En unit, contra el bridge
      real (`GroupsBridgeRestoreConvergenceBehaviourTests`): tras restaurar, la transacción real sobrevive
      con su nota y el gasto cuenta una sola vez; y en `.groupInvite` el mismo re-puenteo la BORRA — por
      eso la activación va antes que la convergencia. La pregunta del historial no escribe filas.
- [x] Ninguno de los empujones lleva a un onboarding sin chooser — por construcción, fijada en
      `FullModeActivationWiringTests.singleFunnel`. ⚠️ Medido: de los 32 strings `groups.nudge.*`, solo
      los 4 `invited*` llevan a la activación (`NudgeType.swift`).

## Device-QA — lo prueba Jürgen (NO es simulable)

**Montaje.** Un iPhone con el build de este cambio (TestFlight contra producción, o Yala Dev contra
staging). **Si ese teléfono tiene una sesión solo-grupos creada con un build anterior al 10-sep, borra la
app y reinstálala antes de empezar**: si no, la activación enseña «Antes, vuelve a instalar Yala» —es
correcto, es el aviso nuevo— y no llegas al chooser. Luego, una sesión solo-grupos: «Vengo por un grupo» →
crea un grupo → registra un gasto que pagas tú y otro que paga el otro miembro. Para los recorridos 2, 3 y
4, el Apple ID del teléfono tiene que tener datos privados de Yala en iCloud; para el 1, no.

1. **Privado, iCloud vacío.** Perfil → «Activar Yala completo» → «¿Dónde guardamos tus finanzas?» con dos
   cards → «Tu cuenta en tu iCloud privado» → «Comprobando tu iCloud…» → «Un último paso: reabre Yala». Ve
   a la pantalla de inicio y vuelve a abrir. **Esperado**: sigue el onboarding (con tu nombre y la divisa
   del grupo ya puestos) → «¿Traemos tus gastos de grupo?» → «Sí» → Panel, con la cuenta «Grupos». Mata la
   app y reábrela: sigues en Yala completo y tus grupos están.
2. **Privado, iCloud con datos → borrar.** Igual hasta la puerta: aviso con cifras y tres botones. «Borrar
   mis datos de iCloud» → confirma → reabre. **Esperado**: onboarding limpio y, tras terminarlo y esperar
   un minuto, ningún dato viejo aparece. Los grupos, intactos.
3. **Privado, iCloud con datos → restaurar.** En el aviso, «Restaurar mis datos» → reabre → «Restaurar»
   encuentra tus datos → «Continuar». **Esperado**: tus datos de antes, con tu nombre y tu divisa de antes
   (no los de Grupos); los gastos de grupo aparecen **una sola vez** en Registros, y los que ya habías
   clasificado en tu vida anterior conservan su cuenta y su nota.
4. **Restaurar a medias.** Como el 3, pero en la pantalla «Restaurar», ya reabierta la app, toca «volver».
   **Esperado**: la sheet se cierra y sigues en solo-grupos. Mata y reabre la app: la activación se abre
   sola en «Restaurar». Termínala: todo como en el 3.
5. **Cancelar.** En el aviso de la puerta, «volver» → vuelves al chooser. En el chooser, «volver» → sale
   sin cambios.
6. **Nube.** «Tu cuenta en la nube» (debe decir «la misma cuenta que ya usas para tus grupos») →
   consentimiento → onboarding → pregunta → «Activando tu cuenta…» → Panel. **Esperado**: Ajustes →
   «¿Dónde viven tus datos?» dice «en la nube»; registra un gasto y comprueba que llega al backend; en
   Supabase, `select kind, personal_claimed_at from profiles where id = '<tu uuid>'` da `complete` y una
   fecha. Sin relanzar.
7. **Abandonar a mitad.** En la nube, cierra con la X durante el onboarding: sigues en solo-grupos y el
   backend sigue en `groups_only`. En privado, cierra con la X DESPUÉS de reabrir: sigues en solo-grupos, y
   al matar y reabrir la app no baja nada de iCloud.
8. **El historial.** Con gastos de grupo y un presupuesto creado en el onboarding, contesta «No, dejarlos en
   Grupos»: no salen en Registros, ni en el total del Panel, ni consumen el presupuesto; Ajustes de Grupos
   tiene los tres toggles apagados. Enciéndelos: aparecen. (Hoy «No» también oculta los gastos futuros —
   ver `groups-history-cutoff-needs-synced-state`.)
9. **Kills.** Mata la app en el terminal «reabre Yala» y en mitad del onboarding reanudado: al reabrir,
   la activación sigue donde estaba, y pasar a segundo plano durante el onboarding NO cierra la app.
10. **La oferta.** En otro teléfono sin Yala: «Es mi primera vez» → «Tu cuenta en la nube» → entra con la
    cuenta del recorrido de grupos. **Esperado**: tras la cadena de Grupos, se abre sola la activación con
    el chooser; «volver» te deja en solo-grupos.

## Residuales, y dónde quedaron

- **Instalaciones solo-grupos anteriores al paso 5** (con el espejo ya puesto): ya no eligen sobre ese
  store — ven el aviso de reinstalar. Anotado también en
  `groups-entry-on-a-mirrored-store-still-blocks-the-owner`.
- **Cancelar DESPUÉS de relanzar** a privado: el espejo adjunto en ese proceso puede exportar las filas de
  grupos a iCloud; una activación privada posterior las vería como «datos en tu iCloud». No borra nada.
- **Una marca de activación que sobrevive a un cierre de sesión** cierra la creación del bridge hasta el
  arranque siguiente, que la retira. No se pierde nada: lo que llega queda en la intención durable del
  bridge.
- **Restaurar → «Empezar desde cero»** hereda el defecto del Welcome: no borra lo importado →
  `restore-start-fresh-keeps-the-imported-corpus`.
- **«No» también oculta los gastos futuros** → `groups-history-cutoff-needs-synced-state`.
- **Cuenta ya completa en la nube** → bloqueo en vez de adopción →
  `full-activation-cloud-adopt-when-account-already-complete`.
- **Respuesta de la promoción perdida, o un kill entre la promoción y la primera escritura local**: la
  cuenta queda completa en el servidor sin nada personal detrás, y «Reintentar» bloquea →
  `claim-promotion-lost-response-blocks-the-retry`.
- **Un segundo dispositivo solo-grupos del mismo Apple ID** recibe el `.completed` por el iCloud-KV y
  queda en una shell completa sin espejo → `completed-mode-escalates-a-second-groups-only-device`. No lo
  introdujo este paso.
- **La sesión secundaria y quien redujo la app con «Seguir con mis grupos»** conservan el recorrido de
  antes, sin chooser: su «dónde» ya está decidido. Los retiran los pasos 12 y 9.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con el recorrido 3 (restaurar tus datos privados desde una sesión solo-grupos, con los gastos de grupo una sola vez en Registros). El 1 pide un iCloud vacío, y el resto queda cubierto por `FullModeActivationChooserUITests` y `GroupsBridgeRestoreConvergenceBehaviourTests`.
