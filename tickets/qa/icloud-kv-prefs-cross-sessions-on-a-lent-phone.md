---
id: icloud-kv-prefs-cross-sessions-on-a-lent-phone
status: qa
qa-status: needs-testing
implementation_date: 2026-09-14
updated: 2026-09-16
priority: high
area: "sesiones, modo-nube, settings"
created: 2026-09-14
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lente de producto"
---

# Las 37 preferencias siguen cruzando entre el dueño del teléfono y quien lo usa

## El síntoma, en lenguaje de usuario

Uso el móvil que me prestaron, con mi cuenta de grupos. La app me llega con el **idioma, la moneda, los
ajustes del panel y el interruptor de avisos de pagos del dueño**. Y si yo los cambio, **se los cambio a
él** en su iPad.

## Lo medido (2026-09-14)

`PreferenceSyncService.applyRemoteValues()` aplica las 37 keys del iCloud-KV del Apple ID a los
`UserDefaults` locales siempre que `behavior == .icloudKeyValue` —o sea, siempre hoy— y los `set(…)`
escriben de vuelta al KV. **Ninguno de los dos sentidos mira el eje de sesión.**

Lo notable es que el repo ya conoció este daño y creyó haberlo cerrado. La cabecera de
`OwnerKeyValueStore` documenta que la fachada nació como guard por el ticket
`secundaria-la-visita-escribe-en-el-dominio-del-dueno` —seis vías medidas, más dos que aparecieron
después: «el idioma que elegía la visita, y el interruptor maestro de avisos de pagos»— y que el guard
**se retiró** con esta premisa:

> «desde la retirada de la sesión de visita (ADR 2026-09-09) solo hay una sesión por teléfono y el KV
> siempre es suyo»

**La celda F del mismo ADR contradice esa premisa**: el móvil prestado con una sesión solo-grupos es
justo el caso de dos identidades sobre un mismo KV, y es el caso motivador del ticket del vaciado
remoto. El propio fichero deja escrito dónde reponerlo: «Si algún día vuelven a convivir dos identidades
sobre este store, el guard se repone AQUÍ y en ningún otro sitio.»

## Por qué no se hizo en el PR del vaciado

Es otro objeto —las preferencias, no la señal de vaciado— y su alcance es de 37 keys en los dos sentidos.
Pero es el mismo eje y la misma premisa caída, así que sale de ahí.

## Criterios de aceptación

- [ ] Decidido si el guard de `OwnerKeyValueStore` se repone y con qué predicado.
- [ ] Si se repone: las preferencias del dueño no se aplican ni se pisan desde una sesión que no es la suya.
- [ ] La premisa escrita en la cabecera de `OwnerKeyValueStore` queda al día en cualquier caso.

---

## Implementación (2026-09-14)

**Decisión de Jürgen (2026-09-14): cada cuenta, sus preferencias.** El guard vuelve a `OwnerKeyValueStore`, y
solo ahí.

- [x] Decidido: se repone, con el predicado de abajo.
- [x] Las preferencias del dueño no se aplican ni se pisan desde una sesión solo-grupos: verificado por unit y
      mutantes; el recorrido real es el device-QA de abajo.
- [x] La cabecera de `OwnerKeyValueStore` quedó al día: la premisa caída, el predicado, lo que no cubre, y que el
      escáner que citaba como red **no existía** desde el 2026-09-13.

**Dos correcciones a este ticket, medidas.** Son **36** preferencias, no 37: `PrefSyncKey` bajó a 36 el 13-sep y
la prosa de `PreferenceSyncService` sigue diciendo 37. Y el guard viejo no se retiró solo: se llevó con él el
escáner `OwnerKeyValueWiringTests`, que la cabecera seguía dando por vivo.

### Qué cambia para quien usa la app

Quien entra por un grupo en un móvil prestado ya no le cambia al dueño el idioma, la moneda, el nombre ni los
ajustes en sus otros dispositivos, y los cambios del dueño ya no le llegan mientras use ese teléfono. Para una
sesión privada —toda la población de producción— no cambia nada.

### La puerta

`OwnerKeyValueGate` cierra el iCloud-KV del Apple ID cuando el teléfono **afirma** no tener sesión privada (eje 1
en `false`), o cuando **empezó** un alta solo-grupos (la marca del neutro) y el eje todavía no tiene marca. Abre
con el eje en `true` y sin ninguna de las dos marcas. Cerrada, escrituras, borrados y `synchronize()` no llegan, y
las lecturas vuelven vacías **salvo las dos señales del Apple ID** (`lastWipeTimestamp`,
`lastOnboardingTimestamp`), que todo dispositivo tiene que ver para darlas por procesadas.

**La review adversarial (cuatro lentes) cambió el diseño dos veces, y las dos por algo que había escrito yo:**

1. La primera versión cerraba con «neutro armado y sin eje afirmado». «Activar Yala completo» levanta el neutro
   al relanzar y no enciende el eje hasta el final, y «volver» desde Restaurar deja la activación pendiente sin
   límite (`CancelEffect.keepPending`): la puerta quedaba **abierta** en una sesión solo-grupos, con el bug entero
   de vuelta.
2. La primera versión ocultaba también las señales del vaciado remoto. Un teléfono en solo-grupos ya no podía
   darlas por procesadas, y la sesión privada que naciera de la activación **obedecía el vaciado al abrirse la
   puerta**: se borraba recién creada. Lo cazaron dos lentes por separado.

Refutado midiendo: la lectura enmascarada del faro durante la promoción a nube no cambia el claim
(`AccountClaimDecision` solo consulta el faro en `.returningUser`).

### Ficheros

| Fichero | Qué cambia |
|---|---|
| `Yala/Services/CloudSync/OwnerKeyValueStore.swift` | `OwnerKeyValueGate` (la tabla, la lectura de las dos marcas y las señales legibles); la fachada resuelve la puerta en cada llamada; cabecera reescrita |
| `Yala/App/Services/PanelPreferencesMigration.swift` | `hasRemotePanelPreferences` lee por la puerta: con ella cerrada, el Panel del dueño hacía saltarse la siembra |
| `Yala/Utils/L10n.swift` · `Yala/Services/CloudSync/PrivateSessionMark.swift` | comentarios que el cambio volvía falsos |
| `YalaTests/CloudSync/OwnerKeyValueGateTests.swift` | nuevo: tabla de 6 celdas, las mismas leídas de un teléfono, fachada con espía y la lectura por defecto de `.standard` |
| `YalaTests/CloudSync/OwnerKeyValueWiringTests.swift` | repuesto: nadie más nombra el store crudo, los dos lectores declarados con sus sentencias fijadas, `shared` vivo, cuerpo entero de `readRemoteIKV`, señales = las del servicio, orden del `-uitest-reset` |
| `YalaTests/CloudSync/PrivateSessionMarkTests.swift` | censos: `confirmedPrivateSession(` 7→8 y `hasPrivateSession(` 17→18, con su porqué |
| `YalaTests/SharedStateIsolation.swift` · `SharedStateIsolationTests.swift` · `OnboardingResetHelperTests.swift` | el scope `.ownerKeyValueGateOpen`, su pin y su censo |

### Verificación

- Suite unitaria completa: **6893 tests en 705 suites, 0 fallos**.
- Mutantes: **19 mutantes, los 19 a exit 65**, uno por corrida y revertidos con `cp` + `cmp`: las tres ramas de la tabla y su ternaria, la lectura estricta cambiada por la permisiva, otro dominio por defecto, el guard de `setDouble` y el de `synchronize`, la máscara de `object`, las señales ocultas y una de más, `shared` siempre abierta, la decisión tomada en el `init`, la migración del Panel al store crudo, el `guard` de presencia dentro de una rama, un escritor crudo nuevo, una escritura cruda en `ContentView`, el observer de `AppPreferences` hacia la puerta, y el trait quitado de `OnboardingResetHelperTests`.
- Gate: **Gate en verde** (2026-09-15): build `Yala` y `Yala Dev` sin warnings en los ficheros tocados · unit 6893 tests en 705 suites · XCUITest de las áreas tocadas —`DeeplinkRoutingUITests`, `EdgeCasesUITests`, `PanelDashboardUITests`, `PaywallInboxAlertRoutingUITests`, `WelcomeFreshStartAlertUITests`, 10 casos— con el centinela sin intrusos · audit de las líneas añadidas limpio · índice QA con el ratchet OK. `test_freshInstallShowsFourSectionsByDefault` falló UNA vez, como primer caso tras una corrida que el harness mató por memoria, y pasó en las otras tres sobre el mismo árbol: es la intermitencia que ya registra `nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` (medición añadida allí).

### Lo que queda fuera, con ticket

- `neutral-boot-hands-owner-prefs-to-whoever-signs-in-next`: tras «Cerrar sesión», el primer arranque aplica las
  preferencias del Apple ID antes de que nadie elija. **Decisión de Jürgen pendiente.**
- `full-activation-local-state-never-reaches-the-apple-id-kv`: lo que «Activar Yala completo» escribe con la puerta
  cerrada no sube cuando nace la sesión privada. **Decisión de Jürgen pendiente.**
- `language-override-bypasses-the-cloud-prefs-channel`: en una sesión en la nube el idioma va al iCloud-KV y no al
  backend.
- Nota añadida a `borncloud-consent-epoch-written-before-the-guard-decides`: dos salidas más que dejan el epoch de
  otra persona en el iCloud-KV del dueño.

## Device-QA (Jürgen) — no simulable

El simulador no da dos dispositivos sobre el mismo iCloud-KV, así que esto va en dispositivos reales.

**Montaje**

1. Dos dispositivos con **el mismo Apple ID** en Ajustes → iCloud: **A** (el del dueño, con su sesión
   privada de siempre) y **B** (el «prestado»). Los dos con un build que traiga este PR.
2. En A, apunta tres cosas visibles: el **idioma** de la app (Ajustes → Idioma), la **moneda** por defecto y
   el **nombre** del perfil.
3. En B: Ajustes → «Cerrar sesión» y confirma. Al reabrir, en el Welcome elige **«Vengo por un grupo»** →
   crear un grupo → entra con **otra cuenta** (Google, o un Apple ID distinto del del teléfono) → escribe un
   nombre distinto del de A → termina el alta. B queda en la pestaña Grupos, sin vida personal.

**Qué comprobar**

1. **B no le pisa nada a A.** En B cambia el idioma de la app. Espera un minuto, trae A a primer plano y
   ciérrala y ábrela: el idioma de A **no cambia**, y el nombre de su perfil **no es** el que tecleaste en B.
2. **A no le llega a B.** En A cambia la moneda y el idioma. Espera un minuto, cierra y abre B: **no cambian**.
3. **Lo que se sabe que queda** (ticket `neutral-boot-hands-owner-prefs-to-whoever-signs-in-next`): justo
   después del alta, B puede verse en el idioma que tenía A. Anótalo, pero no es un FAIL de este ticket.
4. **La sesión privada sigue sincronizando.** Si tienes un tercer dispositivo del mismo Apple ID con sesión
   privada (o vuelves B a privado con «Activar Yala completo» → privado), cambia el idioma en A y comprueba que
   ahí sí llega. Si no llega, es un FAIL grave: la puerta estaría cerrada para el dueño.

**Veredicto**: PASS si 1, 2 y 4 se cumplen. Captura de Ajustes → Idioma en A y en B en cada paso.

## QA · 2026-09-16 — sigue aplicando tras el ADR del 2026-09-09 (cola de device)

El ADR «Sesiones — dos ejes» retiró la **palabra** «visita», no el estado: el «móvil prestado» es la celda
F de la matriz, una sesión de la nube solo grupos en un iPhone cuyo Apple ID es de otra persona, y se
llega a ella por «Vengo por un grupo». El KV es del Apple ID del aparato, no de la sesión de Yala.

El guion de arriba (Device-QA, :125) sigue valiendo, con los verbos de hoy: «Cerrar sesión» y «Vengo por
un grupo». Hacen falta dos aparatos con el mismo Apple ID y una sesión real de grupos; el simulador no da
ninguna de las dos.
