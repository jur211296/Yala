---
id: beacon-routes-only-never-blocks
status: qa
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-09
updated: 2026-09-10
source: "ADR 2026-09-09 «Sesiones — dos ejes» §10"
---

# El faro de iCloud-KV solo encamina: nunca impide crear otra cuenta con otro usuario

## El problema, en lenguaje de usuario

Este Apple ID ya tuvo una cuenta de Yala en la nube (con Apple). Ahora quiero crear otra con mi
Google, por la razón que sea. «Es mi primera vez» no me deja elegir nada: me manda a entrar con la
cuenta de Apple. Y si voy por «Ya tengo cuenta → Google», Yala me dice «Esa cuenta usa otro método —
vuelve atrás y entra con Apple». No hay forma de crear la segunda cuenta desde este móvil.

## Lo que Jürgen decidió (ADR §10)

El faro **encamina, nada más**: si el Apple ID ya tiene cuenta en la nube, «Primera vez» propone
entrar con ella. Pero el usuario **conserva la libertad de crear otra cuenta con otro proveedor u
otro usuario**.

## Lo medido (2026-09-09, árbol `3a94604e`)

- `WelcomeAccountChoiceLogic.routeNewBranch` (`Yala/App/Logic/WelcomeAccountChoiceLogic.swift`): con
  `beaconLinked && cloudEntryAvailable` devuelve `.cloudSignIn(provider)` **antes** del chooser ⇒ la
  elección privado/nube ni se muestra. Motivo escrito (A26, 2026-08-09): que un nacido-en-nube no
  arranque un dataset privado divergente en su segundo móvil.
- `ProviderMismatchLogic.decide` (`Yala/App/Logic/ProviderMismatchLogic.swift`): con la cuenta
  inexistente, faro puesto y sub distinto ⇒ `.mismatch` ⇒ pantalla «Esa cuenta usa otro método» y
  `signOut`, sin camino hacia el alta. Copy en `welcome.cloud.providerMismatch*`.
- `Sign in with Apple` solo ofrece el Apple ID del teléfono, así que «otro Apple» no se plantea aquí;
  el caso real es **Google** (u otro usuario en general).

## Alcance

1. **«Primera vez» con faro:** encaminar sigue siendo el default, pero la pantalla de sign-in a la que
   llega tiene que ofrecer **«Crear otra cuenta»** (vuelve al chooser privado/nube con la card nube
   activa) además de «Entrar con Apple». El texto dice de dónde viene: «Este Apple ID ya tiene una
   cuenta de Yala con Apple».
2. **Provider mismatch:** deja de ser una pared. Con cuenta inexistente y proveedor distinto al del
   faro, la pantalla informa («Tu cuenta de Yala se creó con Apple») y ofrece las DOS salidas:
   «Entrar con Apple» y «Crear una cuenta con Google» (→ «Primera vez → nube» con Google preelegido,
   que pasa por [I] y crea).
3. El faro se sigue escribiendo y leyendo igual (`CloudBeacon`); no cambia su semántica ni su wire. Con dos
   cuentas creadas desde el mismo Apple ID guarda la **última reclamada**: encamina a esa y sigue
   ofreciendo «crear otra». No se guardan dos.
4. Ticket relacionado que NO se resuelve aquí: `restore-beacon-outlives-account-deletion` (el faro
   puede sobrevivir al borrado de cuenta; con «solo encamina» su daño baja, pero el mensaje bajo el
   kill-switch sigue afirmando de más).

## Criterios de aceptación

- [x] Con faro puesto, «Primera vez» encamina y la pantalla de destino tiene «Crear otra cuenta».
      *Verificado en simulador*: `WelcomeChooserUITests.testNewBranch_withBeacon_routesToSignIn_andCreateAnotherOpensTheFullChooser`
      (faro fingido SOLO en lectura) + su control en la re-entrada normal, que no lo ofrece.
- [ ] «Crear otra cuenta» → chooser → nube → Google → [I] `nueva` → se crea una segunda cuenta
      (`kind=complete`) sin tocar la primera. *Hasta el chooser, verificado en simulador; el alta con
      Google real es device-QA (recorrido 3).* `claim_account` estampa `kind='complete'` por defecto
      (`qa/cloud/g15_01_account_kind.sql`) y la variante B del claim es solo de la re-entrada, así que el
      alta nunca choca con el faro.
- [ ] Provider mismatch ofrece entrar con el proveedor del faro o crear con el elegido; ninguna de las
      dos deja al usuario con solo «volver». *En código y verificado por unit + scan; la pantalla con
      sign-in real es device-QA (recorrido 2).*
- [x] `WelcomeAccountChoiceLogicTests` y `ProviderMismatchLogicTests` actualizados: el resultado
      `.cloudSignIn` sigue existiendo; `.mismatch` lleva ahora las dos salidas.

## Cómo se prueba

Unit sobre las dos lógicas puras; device-QA con un Apple ID que ya tiene faro (el de Jürgen lo tendrá
tras el primer alta en nube) y una cuenta Google nueva.

## Depende de

`cloud-sign-in-discovers-account-kind` (para que «crear con Google» pase por [I]).

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

- **«Crear otra cuenta» muestra la pantalla de elegir ENTERA** —«Elige dónde quieres guardar tus datos»
  con sus dos tarjetas (`welcome.new.privateTitle` / `welcome.new.cloudTitle`)— y **sí se puede elegir
  iCloud privado**. El alcance §1 decía «con la card nube activa»: eso queda **derogado**, no se
  preselecciona ni se recorta nada.
  **Consecuencia aceptada a sabiendas:** vuelve a ser posible que alguien nacido en la nube arranque en su
  segundo móvil unos datos privados en iCloud que nunca se juntarán con los de su cuenta. Es exactamente
  lo que A26 (2026-08-09) evitaba, y el ADR §10 pesa más: el faro **solo encamina**. No lo «protejas» por
  tu cuenta con avisos que nadie pidió.
- **El faro huérfano se cubre AQUÍ.** Tras el fresh start del ticket 2 el faro de iCloud-KV apuntará a una
  cuenta borrada, así que este ticket añade: **un faro que apunta a una cuenta inexistente se limpia solo
  —o al menos no bloquea— en cuanto [I] lo descubre**. Con eso se cierra de paso
  `restore-beacon-outlives-account-deletion`; márcalo como resuelto por éste cuando lo esté.
- **El copy nombra el proveedor y nada más**: «Este Apple ID ya tiene una cuenta de Yala creada con
  Apple». Sin correo, ni enmascarado.

## Lo que se hizo (2026-09-10)

**Para quien usa la app:**

- Con el faro puesto, «Es mi primera vez» sigue llevando a entrar con la cuenta de ese Apple ID, pero la
  pantalla dice de dónde viene —«Este Apple ID ya tiene una cuenta de Yala creada con Apple»— y ofrece
  **«Crear otra cuenta»**, que abre «Elige dónde quieres guardar tus datos» entero, privado incluido.
- «Esa cuenta usa otro método» dejó de ser una pared: dice con qué método se creó la cuenta y ofrece los
  dos botones —**Iniciar sesión con <ese método>** y **Crear cuenta con <el que usaste>**—.
- Un faro que apunta a una cuenta **borrada** se apaga solo en cuanto el sign-in lo demuestra, así que
  tras el fresh start la app deja de proponer entrar a una cuenta que ya no existe.

**Lo que cambió por dentro**, con el porqué de cada decisión en el `## Paso 0` del PR:

- `NewBranchRoute.cloudSignIn(accountProvider:)` transporta el método del faro SIN fallback (el
  `?? .apple` pasa a `signInProvider(forBeaconAccount:)`), para que el destino no afirme un método que
  el faro no dice. `WelcomeCloudSignInView.Entry.beaconRouted` es la entrada propia del faro.
- `ProviderMismatchLogic.Verdict.mismatch(Exits)`: `accountProvider`, `signInWith` y `createWith`. Las
  cinco reglas no cambian. «Iniciar sesión con…» relanza el sign-in sin volver a pedir el consentimiento
  (misma ruta ya consentida); «Crear cuenta con…» comparte helper con el CTA de «No encontramos una
  cuenta» y pasa por el consentimiento del alta.
- `BeaconOrphanLogic` + `CloudIdentityDiscovery`: el faro se limpia cuando la respuesta de [I] PRUEBA que
  su cuenta no existe. La convención vive en `.claude/rules/swiftdata-cloudkit.md`.
- Seam DEBUG `-uitest-fake-beacon` (solo lecturas de `CloudBeacon`, no persiste) para el XCUITest.

## Lo medido que cambió el trabajo

- **El hash del faro es del uuid de Supabase**, y el fresh start borró `auth.users`: volver a firmar da
  OTRO uuid. Una regla «mismo hash + no existe» —la lectura literal de la decisión— **no habría detectado
  nunca** el faro huérfano del fresh start. Lo que sí lo prueba es el método: SIWA solo firma con el Apple
  ID del teléfono, que es el mismo cuyo iCloud-KV guarda el faro (y Yala / Yala Dev no comparten KV:
  `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` en los dos `.entitlements`).
- **Con Google no hay prueba posible**: otro hash puede ser otra cuenta de Google de la misma persona.
  Ahí el faro se queda, y basta con que no bloquee.
- **El freno de adopción de Ajustes** (`StorageMigrationSignInLogic`, regla 2) solo consulta el faro con una
  sesión ya viva —la que deja la puerta de Grupos—, y ahí SÍ bloqueaba: con un faro huérfano, para siempre,
  porque ninguna sesión puede tener ya el hash de una cuenta borrada. Limpiar el huérfano lo levanta y el adopt
  sigue como migración a la cuenta nueva (`.proceedMigration`), que es la recuperación que se quiere para una
  cuenta que ya no existe. *(La primera versión de esto decía que limpiar no retiraba ninguna protección que
  funcionara; la corrigió la lente B de la review.)*
- **`restore-beacon-outlives-account-deletion` NO se cierra**: su §1 ocurre bajo el kill-switch, donde no
  corre ningún [I]; su §2 y su §3 no los toca este ticket. Detalle en el propio ticket.

## Lo que cazó la review adversarial (4 lentes, 2026-09-10)

Nada grave. Lo que tocaba este cambio se arregló aquí; lo que es otro objeto, o una decisión de copy de
Jürgen, quedó en ticket.

- **Arreglado en este PR:**
  1. Un cierre de la app en el chooser de «Crear otra cuenta» abría el onboarding privado directo, sin
     elegir y sin la comprobación de iCloud del paso 4, porque el faro dejaba `hasShownWelcomeChooser` en
     `true`. Ahora vuelve a `false`, como en el recorrido normal.
  2. En sesión secundaria, el faro del DUEÑO encaminaba a la visita y el mismatch le hablaba de la cuenta
     del dueño. La visita ya no lo lee (criterio de `WelcomeRestoreEmptyOutcome`, `WelcomeRestorePauseLogic` hasta el 2026-09-17).
  3. «Iniciar sesión con…» del mismatch: si se cancela la hoja de Apple/Google, vuelve a las dos salidas; y
     para un mismatch que llegara desde el alta (hoy inalcanzable), suelta la sesión viva y pide otra vez el
     consentimiento del adopt.
  4. Si otro dispositivo reescribe el faro mientras [I] pregunta, ya no se limpia.
  5. El Welcome le pasa al motor el método con el que acaba de firmar, en vez de fiarse del Keychain.
  6. El rastro `CloudBeacon orphan CLEARED` solo sale si el faro de verdad se apagó.
  7. El seam de UITest ya no puede escribir ni borrar el iCloud-KV real del simulador.
  8. Tres huecos de test que ninguna mutación tumbaba: el método de sesión del motor, la línea de origen
     (XCUITest nuevo con un faro sin método) y el emparejamiento botón↔`case` del mismatch.
  9. Dos docblocks falsos, y mi afirmación sobre el freno de Ajustes (corregida arriba).
- **A ticket:** `welcome-cloud-back-leaves-chooser-marked-seen` (el defecto del punto 1 en el `onBack` de
  todas las entradas, anterior a este cambio); `welcome-beacon-origin-contradicts-not-found-copy` y
  `born-cloud-signup-lands-on-existing-account-silently` (copy: son decisiones de Jürgen).
- **Residuales escritos** en `.claude/rules/swiftdata-cloudkit.md`: si el faro nuevo de otro dispositivo
  todavía no ha llegado a éste, se puede borrar igual (el iCloud-KV no tiene compare-and-delete); y en un
  móvil de desarrollo que alterne Debug-Dev y Release-Dev, la prueba de Apple puede limpiar el faro de una
  cuenta del otro entorno.

## Qué verificó el simulador

- Unit: `ProviderMismatchLogicTests` (las dos salidas + un invariante sobre toda la tabla),
  `BeaconOrphanLogicTests` (lo que prueba y lo que parece prueba y no lo es), `CloudIdentityDiscoveryTests`
  (el motor limpia en los casos probados, también desde Grupos, y NO en Google/otro hash, cuenta
  existente, red caída ni sesión que cambia a mitad), `WelcomeAccountChoiceLogicTests` (payload de la ruta
  y el cableado de «Crear otra cuenta» a `.newChooser`), `WelcomeSignInVerbTests` (cada salida del mismatch
  con su verbo, emparejado), `CloudConsentRegistrationTests` (la entrada del faro tampoco escribe el
  consentimiento al aceptar).
- XCUITest: el recorrido «Primera vez → encamina → Crear otra cuenta → chooser con las dos cards», y el
  del faro sin método conocido (el origen es el genérico).
- **Cifras, sobre el árbol final:** 6768 unit en 691 suites, en verde; 50 casos de XCUITest en 21 suites
  (Welcome, onboarding, sesión secundaria y las áreas que cruzan `ContentView`), en verde y sin reinicios.
  Otras 14 suites de esas áreas (divisas, deeplinks, bandeja, paywall, Grupos) corrieron en verde (39 casos)
  sobre el árbol ANTERIOR a los arreglos de la review, que no tocan sus caminos.
- **Mutantes: 20 de 20 caen**, cada uno en un test que solo él tumba —19 unitarios en tres tandas (las
  mutaciones del motor que se tapaban entre sí fueron por separado) y uno de UI: tomar el nombre del origen
  del botón en vez del faro pone rojo el XCUITest del faro sin método—.

## Guion de device-QA (iPhone real — lo que exige un sign-in de verdad)

**Por qué no vale el simulador para esto:** el sign-in con Apple/Google no corre en simulador, y las tres
cosas que faltan —limpiar el faro huérfano, la pantalla de mismatch y crear la segunda cuenta— ocurren
DESPUÉS de firmar. Lo que ocurre antes ya lo cubre el XCUITest.

**Montaje (una vez):**

1. Instala el TestFlight con este cambio en tu iPhone.
2. Ten a mano **una cuenta de Google que NO tenga cuenta de Yala** (una secundaria vale).
3. Ojo: todo esto va contra **producción** y crea cuentas reales. Al terminar, bórralas desde Más → Tu
   cuenta de Yala → Eliminar mi cuenta.

**Ojo con el orden, si vas a recrear los grupos del paso 3.** El recorrido 1 necesita el faro que dejó el
fresh start. Con el build 13, recrear los grupos no lo toca: una cuenta solo-grupos no escribe el faro y
cerrar sesión no lo borra. Con el TestFlight de este cambio, entrar con Apple por Grupos ya lo limpia —a
propósito: el motor lo hace en toda puerta—, y entonces el recorrido 1 se comprueba en Console.app
(`CloudBeacon orphan CLEARED proof=appleIdentityHasNoAccount`) en vez de en pantalla. Crear una cuenta
COMPLETA nueva lo reescribe con cualquier build.

**Recorrido 1 — el faro huérfano del fresh start (tu iPhone tal como está):**

4. Borra Yala del teléfono (mantener pulsado → Eliminar app) e instálala otra vez.
5. «Empezar» → «Es mi primera vez».
   - Si aparece **«Entra a tu cuenta»** con la línea «Este Apple ID ya tiene una cuenta de Yala creada
     con …» y el botón **«Crear otra cuenta»** debajo: es el faro que dejó el fresh start. Sigue.
   - Si aparece directamente «Elige dónde quieres guardar tus datos», tu Apple ID no tiene faro: salta
     al recorrido 2.
6. Si la línea dice **«creada con Apple»**: toca «Iniciar sesión con Apple» → acepta el consentimiento →
   firma. **Tiene que salir «No encontramos una cuenta».** Toca la flecha de atrás y otra vez «Es mi
   primera vez»: **ahora tiene que salir directamente «Elige dónde quieres guardar tus datos»**. Si
   vuelve a salir «Entra a tu cuenta», el faro huérfano no se limpió: FAIL.
7. Si la línea dice **«creada con Google»**: el faro NO se limpia solo con Google (no hay forma de probar
   que tu cuenta de Google es la misma), y es lo esperado. Comprueba solo que «Crear otra cuenta» te
   lleva al chooser con sus dos tarjetas.

**Recorrido 2 — el mismatch con sus dos salidas:**

8. Crea una cuenta con Apple: «Es mi primera vez» → «Tu cuenta en la nube» → Apple → completa el
   onboarding. Borra Yala e instálala otra vez.
9. «Ya tengo una cuenta» → **Google** → firma con la cuenta de Google SIN cuenta de Yala.
10. **Tiene que salir** «Esa cuenta usa otro método» con el texto «Tu cuenta de Yala se creó con Apple.» y
    DOS botones: **«Iniciar sesión con Apple»** y **«Crear cuenta con Google»**. Si solo hay la flecha de
    atrás, FAIL.
11. Toca «Iniciar sesión con Apple» y **cancela** la hoja de Apple: tienes que volver a la pantalla de los
    dos botones, no a «Entra a tu cuenta». Vuelve a tocar «Iniciar sesión con Apple» y firma esta vez.
    **Tiene que entrar a tu cuenta de Apple sin volver a pedirte el consentimiento.** Comprueba que ves lo
    del paso 8.
12. Borra Yala e instálala otra vez; repite el paso 9. Esta vez toca **«Crear cuenta con Google»**: tiene
    que pedirte el consentimiento del ALTA y crear la cuenta. **Es la segunda cuenta del mismo Apple ID.**

**Recorrido 3 — «Crear otra cuenta» desde «Primera vez», y que la primera siga viva:**

13. Borra Yala e instálala otra vez. «Es mi primera vez» → tiene que salir «Entra a tu cuenta» con
    **«creada con Google»** (el faro guarda la ÚLTIMA cuenta reclamada, la del paso 12).
14. Toca «Crear otra cuenta» → **tiene que salir el chooser con sus DOS tarjetas**, privado incluido. Toca
    la de iCloud privado solo para comprobar que avanza (sale la comprobación de iCloud del paso 4) y
    vuelve atrás.
15. Flecha atrás hasta el primer nivel → «Ya tengo una cuenta» → **Apple** → firma. **Tiene que entrar a
    la cuenta de Apple del paso 8, intacta**: crear la de Google no la tocó.

**Si algo falla, lo que hay que capturar:** la captura de la pantalla, y el log de Console.app filtrado
por `CloudBeacon` — la línea `CloudBeacon orphan CLEARED proof=…` dice si el faro se limpió y con qué
prueba.
