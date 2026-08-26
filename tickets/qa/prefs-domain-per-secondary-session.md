---
id: prefs-domain-per-secondary-session
status: qa
priority: high
area: modo-nube
created: 2026-08-13
updated: 2026-08-26
source: YalaWiki/Backlog/qa_prefs-dominio-por-sesion-secundaria.md
---


# Un dominio de preferencias por sesión: que la visita escriba en su cajón y no en el del dueño

**Decisión del owner (2026-08-13): opción (a), el fix de raíz.** Se descartaron el guard por escritor
(«acordarse en N sitios», que ya falló tres veces) y el snapshot-y-restaura («deshace el daño, no lo
impide»). Este item existe porque el trabajo no cabe en una sesión de arreglo de bugs: es
arquitectura, y su riesgo no está en escribir, está en LEER.

## El problema, en lenguaje de usuario

Le prestas el móvil a alguien para que entre a Yala con su cuenta. Al devolvértelo, **tu Yala no está
como la dejaste**: tu barra de pestañas quedó como la puso ella, tu nombre y tu divisa pueden haber
desaparecido de este teléfono, tu permiso de Grupos se borró y vuelves a ver la pantalla del
consentimiento, y si ella pasó por «activar Yala completo» también te cambió la forma de la app.

Tus datos financieros **no** se pierden: viven en un store aparte y ahí la separación sí funciona. Lo
que se estropea es tu configuración.

## Dónde muerde

| Entorno | Estado |
|---|---|
| Producción | **DARK** (`SECONDARY_SESSION_ROLLOUT_PERCENT = 0`) — hoy no le pasa a nadie |
| Staging / `Yala Dev` | 100 % — alcanzable end-to-end |

⇒ **bloqueante del encendido**, no urgencia. El día que suba el percent, sube con esto dentro.

## La causa, medida

`PreferenceSyncService.local` está **hardcodeado a `UserDefaults.standard`** y su espejo local se
escribe SIEMPRE — también en la rama `.localOnly`, que es la que gobierna la sesión secundaria. No
existe ningún dominio de `UserDefaults` por sesión. Lo dice la regla de C1 en
`.claude/rules/swiftdata-cloudkit.md`: «la caché de una visita cae SIEMPRE en el dominio del dueño y
lo único que la hace inofensiva es que su `userID` no case» — cierto para lo que va sellado, falso
para todo lo demás.

**La otra mitad ya está cerrada** (2026-08-12, `25a36be2`): `OwnerKeyValueStore` es la única puerta al
iCloud KV, así que nada de la visita viaja ya a los OTROS dispositivos del dueño. Lo que queda es el
almacén local de este teléfono.

## Por qué es un proyecto y no un fix

**El riesgo no está en el escritor, está en los lectores.** `UserDefaults.standard` se lee
DIRECTAMENTE en cientos de sitios: `@AppStorage`, `AppPreferences`, los seams de tests, y código que
ni siquiera pasa por `PreferenceSyncService`. Si se cambia el escritor y se deja un lector atrás, la
app lee del cajón del dueño mientras escribe en el de la invitada:

- ella toca un ajuste y no pasa nada visible, o
- ve preferencias del dueño mezcladas con las suyas.

⇒ **una app incoherente durante toda la visita, que es peor que el problema actual.** Por eso el
trabajo empieza por el inventario de LECTORES, no por el de escritores.

## Alcance sugerido (a re-medir al abrir)

1. **Inventariar los lectores**, no solo los escritores: `UserDefaults.standard` directo, `@AppStorage`,
   `AppPreferences`, `SharedContainerService` (App Group — ojo: widgets y share extension leen del App
   Group, y esos procesos NO conocen la sesión secundaria).
2. **Decidir el reparto key por key.** No todo es del dueño: el nombre y la divisa de la invitada son
   suyos y tiene que poder escribirlos, o no puede ni completar su onboarding. Lo que es del
   DISPOSITIVO (p. ej. el sello de adopción de Grupos) probablemente no debe viajar a su cajón.
3. **Un solo punto que resuelva el dominio** (`PreferenceSyncService.local` y sus equivalentes), con
   un source-scan que prohíba `UserDefaults.standard` directo fuera de una lista declarada — molde
   exacto de `OwnerKeyValueWiringTests`, que ya hace esto para el iKV y cazó un fallo real el primer día.
4. **El caso de los procesos hermanos**: widget y share extension leen el App Group sin saber de
   sesiones. Decidir si se les congela lo del dueño o se les dice que no hay datos.

## Criterio de hecho

- Un test que enumere **todas** las escrituras a preferencias alcanzables con
  `SecondarySessionStore.isActive() == true` y exija que caigan en el dominio de la sesión, con
  **conteo esperado** (sin él, un escáner roto pasa en verde: familia de «Executed 0 tests»).
- **Mutación obligatoria**: devolver un escritor a `.standard` tiene que dar exit 65.
- E2E en staging (percent al 100): entrar de visita, tocar nombre / divisa / barra de pestañas /
  idioma / Grupos, cerrar sesión, y comprobar que el dueño recupera **todo** lo suyo.

## Relacionados

- [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]] — el bug del que sale, con las ocho vías medidas
- [[secundaria-salida-de-la-invitada-bloqueo-permanente-y-outbox-de-grupos]]
- [[widget-snapshot-sin-sello-la-visita-pisa-los-datos-del-dueno]] — el punto 4 de este item, sacado a ticket propio

---

# Plan (2026-08-13) · v2, tras revisión adversarial

Plan completo en `~/.claude/plans/scalable-foraging-koala.md`. **No implementado**: la v1 salió
NECESITA AJUSTES de una revisión de 5 lentes con refutación por hallazgo (55 hallazgos, 24 refutados,
31 supervivientes); la v2 los incorpora y está lista para ejecutar.

## El inventario de LECTORES, que era el paso 1 del ticket

| Superficie | Volumen medido |
|---|---|
| `UserDefaults.standard` directo | **256 usos · 65 ficheros · 106 keys distintas** |
| `@AppStorage` | **10 declaraciones en 4 ficheros** + 1 construcción manual de key dinámica = **11 sitios**. Cero en `YalaWidgets/` y `YalaShare/` |
| App Group | 22 usos en 18 ficheros |

**Y el hallazgo que hace el trabajo tractable, que el ticket no tenía:** el volumen NO es el trabajo.

1. **`AppPreferences` ya es inyectable** (`:832` `init(defaults:)`), 76 properties, y tiene **un solo
   constructor de producción** (`AppBootstrapper.swift:38`). El resto son `#Preview`.
2. **`defaultAppStorage(_:)` existe en el SDK y da CERO ocurrencias en el repo**: un modificador en la
   raíz cubre los 11 sitios `@AppStorage` sin tocar ninguno.
3. Las dos fronteras donde va el ciclo de vida **ya existen** y tienen variante inyectable:
   `performSecondaryEntryTasksIfNeeded` y `performSecondaryWipeIfArmed`.

⇒ el grueso son **cuatro consumidores**, no 256 sitios. El resto es un barrido gobernado por una
allowlist de keys.

## Las dos premisas que la revisión REFUTÓ, y que habrían costado caro

1. **«El dominio se fija una vez por proceso» era FALSO.** `SecondaryEntryLogic.begin` activa el
   descriptor **con el proceso del dueño vivo** (`WelcomeCloudSignInView.swift:801-805`); el
   relanzamiento es posterior (`:812`). En esa ventana se escriben `ContentView.swift:1584`
   (`.standard` clavado), su `@AppStorage` gemelo y —lo que importa— el **epoch RGPD del consent de
   la invitada** (`:810`). Un fix que no cubra la ventana deja el consent en el cajón del dueño.
2. **La destrucción del cajón, donde la v1 la ponía, era un no-op.** `SecondarySessionStore.clear`
   está en `:841`, **antes** de las tres escrituras (`:844-846`, la v1 decía `:843-845`), y borra el
   `userIDKey` ⇒ ahí ya no hay `sub` para componer el nombre del suite. Resultado: **cajón huérfano
   permanente** con los datos de la invitada en el móvil del dueño. Variante peor: llamar
   `removePersistentDomain` sobre lo que resuelva la puerta en ese punto **borra el `UserDefaults`
   entero del dueño**.

## Los cuatro bloqueantes que la revisión añadió

1. **`DataWipeService` es el CUARTO consumidor y no estaba.** `:438`
   `removeUserPreferenceKeys(from: .standard)` hardcodeado, **114** `removeObject` mezclando keys de
   persona y de dispositivo, alcanzable por la invitada sin un solo guard (`ProfileView.swift:961` es
   un `NavigationLink` incondicional). Y es **invisible para el escáner**: las keys se nombran contra
   el parámetro, y el `.standard` vive una capa más arriba en una línea que no nombra ninguna key.
2. **La puerta necesita contrato escrito**: instancia **cacheada** por suite (medido con sonda: dos
   `UserDefaults(suiteName:)` son objetos distintos y un observer con `object:` sobre uno no ve las
   escrituras del otro ⇒ construir inline mata la recarga de `AppPreferences` **en silencio** toda la
   sesión), nombre **resuelto por llamada**, lectores **congelados al arranque** (un `@AppStorage`
   reactivo produciría el brick del Welcome sobre store vacío).
3. **La red de completitud era el conjunto equivocado.** `synced: true` deja fuera `financialMindset`,
   `appLanguageOverride`, `onboardingMode` y —el síntoma titular del ticket—
   `tabBarConfiguration`, que es `synced: false`. Red correcta: `PrefSyncKey ∪ {synced: true}` más las
   que forman PAR, y el escáner por **N grafías** con conteo que las suma.
4. **El orden de fases commiteaba el split-brain.** Mover escritores antes del inventario y dos
   commits antes de los lectores produce exactamente lo que el ticket declara peor que el bug. Orden
   nuevo: puerta+ciclo de vida → inventario+escáner → consumidores **y lectores juntos** → barrido.

## Decisiones del owner tomadas en esta sesión

- **El cajón nace vacío con las keys de DISPOSITIVO sembradas** (no vacío del todo, no copia del
  dueño). La siembra copia el VALOR del dueño, no escribe `true` a ciegas, y su guard de idempotencia
  lee **del cajón** — si lee `.standard`, donde el dueño tiene `true`, el cajón no se siembra nunca.
- **El widget sale a ticket propio** con la medición de esta sesión, y su decisión es *sello + servir
  los datos de la invitada*.

## Decisiones del owner (2026-08-13) sobre los diferidos

**D2 · El idioma ENTRA como quinto consumidor.** `appLanguageOverride` vive en el App Group
(`L10n.swift:38-40`), no en `.standard`, así que ninguno de los otros cuatro lo alcanza: sin esto la
visita cambia el idioma y **el dueño recupera su móvil con la app en otro idioma**. Y el motivo de
peso no es el bug sino su verificación: el criterio E2E del ticket exige comprobar el idioma, y ese
paso **puede salir VERDE sin estar arreglado**, porque `applyRemoteValues` se lo restaura al dueño
desde su iKV intacto ⇒ un test que pasa por la razón equivocada, la familia de fallo que este repo ya
ha pagado varias veces.

**D4 · `hasShownYalaAIOnboarding` sale de la siembra obligatoria** (medido: no está en el healing de
hoy, que escribe dos keys en `:886-888`) y pasa a las ambiguas de F2.

**D6 · El reparto de los contadores, decidido:**

| Key | Para qué sirve (medido) | Decisión |
|---|---|---|
| `chatQuestionsToday` | Límite diario del chat de IA (`ChatAssistantService.swift:45`) | **PERSONA** — sin esto la visita se come el cupo del dueño y él se queda sin preguntas ese día sin entender por qué |
| `pro.upsell.sessionCount` | Cuenta arranques: cuándo mostrar la oferta Pro y cuándo re-expandir el checklist (`SetupChecklistManager.swift:168`/`:184`) | **PERSONA** — a la visita le saldría la oferta en su primera pantalla como si llevara meses |
| `transactionsSavedCount` | A las 3 transacciones, pedir permiso de notificaciones (`NewTransactionViewModel.swift:951-952`) | **PERSONA** |
| `needsPostOnboardingTrial` | One-shot del trial post-onboarding | **Como está** — ya hay decisión escrita: la invitada NO recibe la oferta del device del dueño (`ContentView.swift:1581-1583`) |
| `financialMindset` | Perfil financiero del onboarding | **PERSONA** (y de paso entra en la red, que hoy no lo alcanza: es `PrefSyncKey` sin property en `AppPreferences`) |

**La ventana de entrada · el cajón nace al ACTIVAR la sesión** (la última que faltaba). Entre que la
visita confirma y que el proceso muere hay unos segundos con su sesión ya activa y la app del dueño
todavía viva, y en ellos se escribe su **registro de consentimiento** (dato con implicaciones RGPD).
El cajón se crea ahí, en `SecondaryEntryLogic.begin`, y no en el arranque siguiente.

Sale casi gratis, y el porqué es una propiedad que el repo ya tiene: `PreferenceSyncService` resuelve
su destino **en CADA llamada** —su propio comentario (`WelcomeCloudSignInView.swift:806-809`) declara
que ese orden «ES el fix»— y escribir en un suite lo crea ⇒ **el consent de la invitada cae solo en su
cajón sin editar esa línea**. Contrapartida obligatoria: la siembra del arranque siguiente tiene que
ser **ADITIVA**, jamás borrar-y-reescribir, o pisaría lo que la ventana ya guardó. Va con su test.

Cabo suelto menor, a documentar y NO a «arreglar»: `ContentView.swift:1585` (el `@AppStorage` gemelo)
escribe en el store congelado del dueño, donde `hasCompletedOnboarding` ya vale `true` ⇒ no-op
inofensivo. Descongelar ese lector produciría el brick del Welcome sobre store vacío.

**Nota sobre el relanzamiento, porque la premisa engaña:** entrar a una cuenta de la nube **no**
relanza desde R2 (`requiresMirror` es `false` para `cloudSignIn`/`cloudAccount`). La sesión secundaria
sí, pero **no por el espejo de CloudKit**: hay que montar otro ARCHIVO de store (los `-Secondary`) y
`personalConfiguration` se evalúa una vez por proceso. Y desde R0 la app **se cierra sola** al ir a
background (`secondaryEntryArmedUnmounted`); no se le pide al usuario que la mate a mano.

**La puerta de Grupos (`GroupsOrganizerGateLogic`) NO hereda la señal de restauración por ahora.**
Es el mismo hecho mal clasificado, pero ahí el bloqueo solo aplaza crear un grupo —no cierra la
entrada a ninguna cuenta—, su copy ya es honesto y tiene salida. Se revisita cuando la señal lleve
tiempo verificada en device; hoy no ha corrido nunca en producción. Ver
[[qa_welcome-copy-acusa-al-dueno-de-traer-datos-ajenos]].


---

# Implementación

## F1 · La puerta, su contrato y el ciclo de vida — 2026-08-13, `2a773ed3`

**Qué cambia para quien usa la app: por ahora nada, y es a propósito.** El cajón separado ya existe
y sabe nacer y morir, pero todavía no escribe nadie en él. Mover a un escritor sin mover a la vez a
quien lee esa misma preferencia dejaría la app incoherente durante toda la visita, que es peor que el
problema de hoy — así que escritores y lectores viajan juntos en F3.

### Archivos

| Archivo | Qué cambia |
|---|---|
| `Yala/Services/CloudSync/SessionDefaults.swift` | **Nuevo.** La puerta: resuelve `.standard` (dueño) o `yala.session.<sub>` (visita), más la siembra y la destrucción del cajón |
| `Yala/Utils/SwiftDataConfiguration.swift` | Los dos hooks de frontera cablean el ciclo de vida: siembra en la entrada, destrucción en el paso **2.75** de la salida. Ganan seams inyectables. `isRunningTests`/`isUITesting` pasan a `nonisolated` |
| `Yala/Services/CloudSync/CloudSyncEngine.swift` | Dos canarios nuevos: `sessionDomainSeeded` y `sessionDomainUnavailable` |
| `Yala/Services/CloudSync/OwnerKeyValueStore.swift` | Su docblock decía que un dominio por sesión «hoy no existe». Ya existe; se corrige diciendo **exactamente** hasta dónde llega |
| `Yala/App/Views/Settings/CloudSyncDebugView.swift` | El copy de «Limpiar descriptor» ya avisa de que el cajón queda huérfano, junto a los archivos `-Secondary` |
| `Yala/App/Services/AppPreferences.swift` · `Yala/App/Models/UsageFocus.swift` | `Keys` y `userDefaultsKey` a `nonisolated` — constantes que no necesitan actor |
| `YalaTests/CloudSync/SessionDefaultsTests.swift` | **Nuevo.** 22 tests en 3 suites |

### Decisiones técnicas, con su porqué

**1 · La destrucción va en el paso 2.75, entre el guard de abort y `clear`.** `SecondarySessionStore.clear`
(`:856`) borra el `userIDKey`, y después de esa línea ya no hay `sub` con el que componer el nombre del
suite ⇒ el cajón quedaría **huérfano para siempre** en el móvil del dueño, con el nombre, la divisa y la
barra de la visita dentro. El `sub` va por parámetro **explícito** y el fallo es cerrado: resolver la
puerta en ese punto y llamar `removePersistentDomain` sobre lo que devuelva **borraría el `UserDefaults`
entero del dueño**.

**2 · La siembra es aditiva y su guard vive EN EL CAJÓN.** Entre que la visita confirma la entrada y que
el proceso muere hay unos segundos con su sesión ya activa, y en ellos se escribe su registro de
consentimiento: un borrar-y-reescribir lo pisaría. Y el guard de idempotencia leído de `.standard` —donde
el dueño tiene el flag a `true`— concluiría «ya sembrado» y el cajón **no se sembraría nunca**, con lo
que el brick del Welcome pasaría de caso raro a caso normal. Copia el **valor** del dueño, no escribe
`true` a ciegas.

**3 · La excepción de entorno cubre las TRES operaciones, no solo la resolución.** Decisión del owner que
**corrige al plan**, que prescribía excluir solo `isRunningTests`. Medido: `AppBootstrapper:658` planta el
descriptor en los XCUITest pero en el dominio **volátil**, mientras un suite **persiste**, y los dos
anclajes del ciclo de vida están apagados en ambos entornos (`:811` y `:888`) ⇒ nacería un cajón que nadie
siembra, nadie destruye y ninguna purga alcanza. Es el precedente exacto de `groupsDomainSealedForFreshStart`
(14 tests rojos «hasta que alguien borre el simulador»).

**4 · Degradación observable, no brick.** Si el suite no abre, la puerta devuelve el dominio del dueño y
emite un canario. Un store vacío dejaría la app sin preferencias y sin onboarding completado: un brick es
peor que el bug que esto cierra.

**5 · `nonisolated`, y costó tres intentos.** Copiar el `nonisolated` del vecino dio 7 avisos; `@MainActor`
rompió el build. La medición que decide: **el target `YalaTests` no lleva `SWIFT_DEFAULT_ACTOR_ISOLATION`**,
así que sus tests son `nonisolated` y son ellos quienes ejercitan los hooks. El arreglo correcto era marcar
`nonisolated` las **constantes inmutables en su origen** — que de paso resolvió dos avisos preexistentes de
`AccountEntitlementService`.

### Verificación

- **6 mutaciones a exit 65**, cada una cayendo solo en su test: resolución capturada · suite inline ·
  destrucción después de `clear` · sentinel leído de `.standard` · siembra no aditiva · excepción de entorno
  ausente en el ciclo de vida.
- Gate: 5855 unit + 4 XCUITest (`SecondarySessionGateUITests`), **7 warnings, ni uno nuevo**.
  (Corrección del 2026-08-13: el informe original dijo «5, dos menos que la baseline». Era un
  artefacto de build INCREMENTAL — `AccountEntitlementService` no se recompiló en esa corrida y sus
  dos avisos no se re-emitieron. Con recompilación forzada, 7 e idénticos a la baseline. Cuenta como
  recordatorio de que un conteo de warnings solo vale si el build tocó algo.)
- **Una trampa de test cazada por su propio mutante**: el pin de la instancia cacheada NO caía, porque
  `addObserver(forName:object:queue:)` **no retiene su `object`** ⇒ el primer handle se desalojaba y el
  segundo aterrizaba en la misma dirección, y el filtro por identidad casaba por accidente. Retener el
  handle lo vuelve determinista (2/2). Sonda de confirmación: dos instancias **vivas** del mismo suite no
  se ven las escrituras, y el control positivo sí dispara.

### Correcciones al plan, medidas al abrir

| Dato del plan | Medido en el árbol |
|---|---|
| `UserDefaults.standard`: 256 usos · 65 ficheros | **CORRECTA — ver la nota de abajo** |
| App Group: 22 usos · 18 ficheros | **34 · 22** |
| `transactionsSavedCount` en `NewTransactionViewModel:951-952` | `:951` es el **lector**; la escritura está en **`:564-565`** |
| — | Dos escritores que el plan no listaba: `ProUpsellService:44` y `SessionState:515-516` |

**Corrección del 2026-08-14, y la lección va en la dirección contraria a la esperada.** El informe de
F1 dijo que la cifra del plan (256/65) «ya era mala» porque midiendo daba 307/86. **Era mi corrección la
equivocada**, y lo destapó la sesión hermana al re-medirla: son **dos poblaciones distintas de la misma
cosa**, no una cifra buena y otra mala.

    en d3c14350 (la base del plan):
      307 líneas · 86 ficheros   ← `git grep -c`, INCLUYE las menciones en comentarios
      303 ocurrencias · 85 ficheros ← contando apariciones, no líneas
      256 usos · 65 ficheros     ← solo CÓDIGO (filtrando líneas `//`) — la del ticket

Y la del ticket es la **relevante para dimensionar el trabajo**: un `UserDefaults.standard` citado en un
docblock no hay nada que moverlo. ⇒ el plan medía bien; lo que faltaba era decir qué población contaba.
Se deja escrito así para que nadie vuelva a «corregirlo».

Todo lo demás del plan se confirmó **exacto**, incluidas las dos coordenadas que su revisión había
refutado (`:801-805`/`:812` de la ventana de entrada, y `clear` antes de las tres reposiciones).

### Decisiones del owner tomadas en esta sesión

- **La excepción de entorno incluye `isUITesting`** (ver §3).
- **`ProUpsellService` entra entero**: las 8 keys `pro.*` son de PERSONA. Todas describen la relación de
  una persona con la oferta Pro; ninguna es del dispositivo.
- **Los tres mirrors de `SessionState` pasan por la puerta**, `needsPostOnboardingTrial` incluido.

### Lo que queda

- **F2** · el inventario de keys y su escáner por N grafías.
- **F3** · los cinco consumidores **y los lectores de sus keys, en el mismo commit**; aquí se retiran las
  tres reposiciones (hoy `:871-873`) y se decide el idioma (D2).
- **F4** · el resto del barrido y las excepciones declaradas.


## F2 · El inventario de keys y su escáner — 2026-08-13, `de6a70d4`

**Qué cambia para quien usa la app: nada todavía.** Es la decisión escrita de qué ajuste es de la
persona y cuál del teléfono, más la red que avisa cuando falta clasificar uno.

### Archivos

| Archivo | Qué cambia |
|---|---|
| `Yala/Services/CloudSync/SessionPreferenceKeys.swift` | **Nuevo.** La allowlist de PERSONA (56 keys) y las excepciones de DISPOSITIVO, cada una con su porqué en el código |
| `YalaTests/CloudSync/SessionPreferenceKeysTests.swift` | **Nuevo.** 10 tests en 3 suites: completitud, grafías con conteo, y el caso invisible de `DataWipeService` |

### Decisiones técnicas, con su porqué

**1 · Allowlist de PERSONA, no denylist de DISPOSITIVO.** El sesgo es deliberado: una key olvidada
**aquí** sigue fugando exactamente como hoy, sin regresión. Olvidada en la lista contraria se llevaría
al cajón de la visita algo del teléfono del dueño, que es daño **nuevo**. Cuando haya que equivocarse,
que sea hacia el lado que ya conocemos.

**2 · La red del plan v1 era insuficiente por los DOS lados** — medido: seis keys son `PrefSyncKey` y
**no** `synced: true`; cinco son `synced: true` y **no** `PrefSyncKey`. Red final = la unión (42), más
los pares a mano.

**3 · Ninguna de las 42 necesitó excepción, y no por pereza:** estar en la red significa por definición
«esto viaja con la cuenta a los otros dispositivos de su dueño» ⇒ es de la persona por construcción. Lo
que sí quedó declarado como excepción son las cinco del teléfono que el cajón acabará conteniendo de
todos modos —porque en F3 los consumidores se mueven **enteros**, no key por key—, y eso es lo que
conecta este inventario con la siembra de F1.

**4 · El conteo por N grafías, y por qué suma.** La misma key se nombra como literal, como símbolo de
`AppPreferences.Keys`, como `PrefSyncKey.rawValue` o como constante privada de un servicio. Con el
conteo sobre una sola grafía, mover un sitio de literal a símbolo deja el escáner en verde sin
comprobar nada — y `DataWipeService` mezcla las dos **dentro de la misma función**. Los conteos van
**medidos** y con su desglose por fichero al lado: eso los hace auditables y es la lista exacta de
sitios que F3 tendrá que mover.

**5 · El escáner excluye el propio inventario del conteo.** Nombrar una key para declararla no es ser
su escritor, y contarlo ataría los números a la forma de la lista: añadir una key movería recuentos que
no tienen nada que ver con ella.

### Lo que este escáner NO cubre, medido

Añadir un `case` a `PrefSyncKey` **no llega** a la aserción de completitud: lo para antes el compilador
(`PreferenceMergeLogic.swift:130` tiene un `switch` exhaustivo). **La vía que nadie más cubre es la
property `synced: true` nueva**, que compila perfectamente y no rompe ningún `switch`. Ése es el hueco
que el escáner tapa, y su mutante da exit 65 con **cero errores de compilación**. Se descubrió porque
el primer mutante falló por la razón equivocada.

### Hallazgos de la medición

- **`transactionsSavedCount` se escribe también desde `DraftService` (×4)**, un segundo servicio que el
  plan no listaba — solo citaba `NewTransactionViewModel`.
- La barra de pestañas y el rango del período `.custom` no salen de ninguna red: entran por PAR.

### Verificación

5 mutaciones a exit 65: quitar una key de la lista · una excepción sin porqué · el escáner contando una
sola grafía · una property `synced: true` nueva sin clasificar · el instrumento dejando de leer el árbol.
Gate: 5865 unit + 4 XCUITest, 7 warnings (ni uno nuevo).


## F3 · Los consumidores y sus lectores — 2026-08-13, `35c1a016`

**Ésta es la que arregla el problema.** El dueño recupera su móvil con todo lo suyo intacto, y la
visita deja de ver cosas de él. 34 archivos, y no se podía partir: mover un escritor sin su lector
deja la app a medias, que el ticket declara peor que el bug.

### Los cinco consumidores

| Consumidor | Cambio |
|---|---|
| `AppPreferences` | `AppBootstrapper:40` — el único constructor de producción; sus 76 properties enteras |
| `PreferenceSyncService` | `local` pasa de `let .standard` a **computed** `{ SessionDefaults.current }` |
| Los 11 `@AppStorage` | `.defaultAppStorage(...)` en la raíz de `YalaApp` — uno solo cubre los 11 |
| `DataWipeService` | `:441` — «Vaciar mis datos» barre el dominio de quien lo pulsa |
| `LanguageManager` (D2) | gana `SessionDefaults.sessionSuite()`, que devuelve `nil` fuera de sesión |

`LanguageManager` es el único cuyo dominio normal **no** es `.standard` sino el App Group, así que
ninguno de los otros cuatro lo alcanzaba. Va contra el App Group **a propósito** y no contra
`.standard`: ahí es donde leen los procesos hermanos del dueño, y dejarles el idioma de ella sería el
mismo daño por la puerta de al lado.

### El riesgo nº1 del ticket, medido: **40 lectores desalineados**

El plan hablaba de «tres instancias». Eran cuarenta, y no eran teóricas:

- **`userName` en CINCO sitios** (`GroupFormView`, `GroupMembersView`, `GroupDetailViewModel`,
  `GroupService`, `GroupBackendInviteEntryHandler`) ⇒ la visita habría visto el nombre del **dueño**
  en sus propios grupos.
- **`defaultCurrencyCode`** en `ExchangeRateService` ⇒ conversiones con la divisa de él.
- `chatQuestionsToday` y `transactionsSavedCount` (D6) partidos entre dos cajones.

Se movieron **37 en 21 archivos**. Los 3 restantes son `WidgetDataCache` y quedan **declarados** con su
porqué: alimentan el snapshot del widget, proceso hermano del dueño, con ticket propio (D1).
`SessionState` va **entero** (16 sustituciones) porque todas sus keys son de persona — y de paso
`chat_draft_saved_signal` entra al inventario. Igual `YalaFormatterStatic` (6), cuyo docblock promete
output «byte-identical to `appPreferences.X`».

**La red que impide que esto vuelva a quedarse a medias** es un escáner que exige cero lectores de una
key de persona en `.standard`, con excepciones declaradas.

### Un falso verde cazado al escribirlo

La aserción de `FullModeActivationView` apuntaba a `Views/Onboarding/` cuando el archivo vive en
`Views/Groups/`: leía cadena vacía, el `!contains("UserDefaults.standard")` se cumplía trivialmente y
**el test pasaba sobre un archivo inexistente**. Familia de «Executed 0 tests». De ahí que el escáner
lleve ahora **control de instrumento**: todo archivo escaneado tiene que existir y tener contenido.

### Decisión del owner que corrige al plan

**Las tres reposiciones de `:871-873` NO se retiran.** El plan las daba por «compensación» del daño de
la visita; medido, son el **paso 3.5 del flujo de salida** (el device vuelve al Welcome), declarado a
propósito en el docblock y pinneado en `SecondaryBoundaryHooksTests:86-88`. Y ya antes del cajón no
compensaban nada: la invitada escribía `true` sobre el `true` que el dueño ya tenía. Retirarlas es un
cambio de **producto** que ni el ticket ni el plan justifican. El porqué queda escrito en el código.

#### RESUELTO (owner, 2026-08-14): se quedan, y hay un motivo más fuerte que el declarado

La pregunta abierta era «¿qué necesita ver el dueño al recuperar su teléfono?». **Respuesta: el
Welcome, y para el caso que importa NO es una molestia sino la única puerta.** Medido:

- **Dueño en modo PRIVADO** (el 100 % del parque hoy): sus datos siguen en disco —la salida solo borra
  los archivos `-Secondary`— y **no** ve la pantalla «borraste tus datos», porque el wipe secundario
  no pasa por `DataWipeService` y por tanto no marca `lastWipeTimestamp` (`RestoreOfferGate.wasWiped`
  no dispara). Y con el Modo Nube apagado, `visibleExistingOptions` devuelve **una sola** card ⇒
  «Ya tengo cuenta» hace **bypass directo a restaurar**. Un tap.
- **Dueño en MODO NUBE** —que es el único escenario donde la sesión secundaria existe—:
  `performSecondaryCloudSignOut` hace `CloudAuthService.signOut()` y **el Keychain es uno solo**, así
  que al cerrarse la sesión de la invitada el dueño se queda **SIN sesión de nube**. Su modo persistido
  sigue en `.cloud` (la salida no toca `StorageModePersistence`). ⇒ **tiene que volver a firmar, y el
  Welcome es el único sitio donde puede hacerlo.**

⇒ la opción «aterrizar directo en su app» queda **descartada con argumento**, no por conservadurismo:
le dejaría sin sesión de nube **sin saberlo**, con sus cambios sin subir y nada que se lo dijera.

**Residual que esto destapa, y que muerde al ENCENDER el Modo Nube (no ahora):** con la nube encendida
«Ya tengo cuenta» muestra **tres** cards, y para el dueño en Modo Nube la correcta es **«Entrar con
Apple»**, no «Restaurar de iCloud». Si se equivoca, el restore le busca en un iCloud donde sus datos
personales ya no se espejan (su store va mirror-off) y no le devuelve la sesión. El faro
(`CloudBeacon`) ya encamina en la rama «Soy nuevo» (`WelcomeNewBranchRouter`) pero **no** en «Ya tengo
cuenta» — ahí es donde habría que mirarlo si se decide cubrirlo.

### Verificación

**8 mutaciones a exit 65**: cada consumidor devuelto a `.standard` (5), el espejo local capturado en un
`let`, un lector desalineado de vuelta, y una excepción apuntando a un archivo inexistente.
Gate: 5878 unit + **29 XCUITest en 10 suites** de las áreas tocadas, 7 warnings idénticos a la baseline.

**La prueba que carga el peso**: con la visita dentro, el dominio del dueño no cambia **ni una key**, y
tras el wipe vuelve byte-idéntico — con la aserción gemela `persistentDomain(forName:) == nil`, sin la
cual pasaría en verde con la destrucción rota.

### Lo que queda

- **F4** · el barrido del resto (las `synced: false` de persona que no entraron en la red) y las
  excepciones declaradas.
- **E2E en device**, que lo corre el owner: staging al 100 %, entrar de visita, tocar nombre / divisa /
  barra / **idioma** / Grupos, cerrar sesión y comprobar que el dueño recupera todo. El paso del idioma
  es el que puede salir verde por la razón equivocada (`applyRemoteValues` lo restaura del iKV intacto),
  así que hay que mirarlo **durante** la visita, no solo después.


## F4 · El barrido y las excepciones declaradas — 2026-08-13, `d04fe0b6`

Cierra la frontera local. El inventario queda en **99 keys de persona + 3 familias dinámicas** y **10
excepciones de dispositivo**, cada una con su porqué en el código.

### Tres bloques

1. **Las 27 `synced: false` de `AppPreferences`.** Ya viajaban al cajón desde F3 (el consumidor se
   mueve entero); declararlas es lo que las mete en la red del escáner de lectores desalineados, que
   es donde estaba el trabajo: aparecieron **13**. Entre ellos los tres **consentimientos de IA**, que
   son de la persona por la razón más fuerte del inventario — un consentimiento es un hecho de quien
   lo da, y heredar el del dueño equivaldría a darlo por ella.
2. **Cuatro servicios con almacén propio** que ni el ticket ni el plan nombraban: `userTheme` (lo más
   visible de todo), `NudgeService` (23), `ReviewPromptService` (8) y `ThemeManager` (4).
3. **Las 8 keys literales sueltas** que quedaban.

### Familias dinámicas

`nudge.interacted.<tipo>`, `guide.<id>.dismissed` y `pro.*` componen su nombre en runtime, así que un
`Set` exacto las perdería **enteras** — y son justo las que registran «a esta persona ya se le enseñó
esto». De ahí `personPrefixes` y `belongsToPerson`.

### El hallazgo que más enseña: **F3 introdujo un bug y F4 lo encontró**

Al mover `chatQuestionsToday` al cajón sin su par `chatLastQuestionDate`, `ChatAssistantService` quedó
comparando la **fecha del dueño** contra el **contador de la visita** — el lector desalineado en su
forma exacta, creado por el fix que existe para evitarlo.

**Y el escáner de F3 no lo cazó, porque solo protege lo que está DECLARADO**: un par cuya otra mitad no
figura en el inventario le es invisible. ⇒ al añadir una key, la pregunta no es solo «¿de quién es?»
sino **«¿con qué se COMPARA?»**. Cerrado y con red: el mutante que vuelve a romper el par da exit 65.

### `yala.wasProUser` se queda en el teléfono, y el porqué no es obvio

Pro **no se compra con la cuenta de Yala** sino con el Apple ID del dispositivo, así que durante la
visita la app es Pro porque lo es el móvil del dueño — no porque ella haya comprado nada. Llevar el
espejo al cajón haría que StoreKit y el estado local discreparan, y al salir el dueño podría
encontrarse la app creyendo que dejó de ser Pro.

### La garantía de cierre, construida por el otro lado

Ninguna lista puede demostrar que está completa, así que la red se pone al revés:
`noUnclassifiedLiteralsRemain` cuenta las keys **literales** que quedan escribiéndose en `.standard` y
exige que todas estén clasificadas. Una key nueva sin dueño pone el test en rojo **y la nombra**. Lo
que queda ahí es infraestructura del aparato: centinelas de seed, interruptores de dev y los flags de
onboarding que la siembra hereda a propósito.

### Verificación

3 mutaciones a exit 65: una key nueva en `.standard` sin clasificar · la pérdida de una familia
dinámica · el par del chat roto otra vez. Gate: 5880 unit + 26 XCUITest en 10 suites, 7 warnings
idénticos a la baseline.

---

# Estado final

**Las cuatro fases están hechas y verdes.** 22 mutaciones verificadas a exit 65 en total.

Falta **solo el E2E en device**, que lo corre el owner y que quien escribió el fix no puede ejercitar
(producción es DARK y staging no ejerce la regla del mismo modo):

1. Staging con `SECONDARY_SESSION_ROLLOUT_PERCENT = 100`.
2. Entrar de visita con una segunda cuenta.
3. Tocar **nombre · divisa · barra de pestañas · idioma · tema · Grupos**.
4. Cerrar su sesión y comprobar que el dueño recupera **todo** lo suyo.

**El paso del idioma hay que mirarlo DURANTE la visita, no solo después**, y es el aviso más
importante de esta lista: puede salir verde por la razón equivocada, porque `applyRemoteValues` se lo
restaura al dueño desde su iCloud KV intacto — un test que pasa sin que el fix funcione es la familia
de fallo que este repo ya ha pagado varias veces.

Comprobación adicional que ahora es barata: durante la visita, el **tema** y los **permisos de IA**
deben ser los de ella; al salir, los del dueño intactos.

migrated from YalaWiki Backlog/qa_prefs-dominio-por-sesion-secundaria.md @ 1934e8ad
