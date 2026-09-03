---
id: prefs-synced-keys-upload-not-download
status: qa
created: 2026-08-06
updated: 2026-09-03
source: YalaWiki/Bugs/prefs-cinco-keys-synced-suben-y-no-vuelven.md
---

# Cinco ajustes suben y no vuelven, y un sexto baja y no sube

## El síntoma, en lenguaje de usuario

Cinco ajustes se guardan en la nube pero **nunca se leen de vuelta**. En un solo dispositivo no se nota nada.
En cuanto haya un segundo —o el usuario reinstale— esos cinco ajustes **no viajan**: la app los muestra en su
valor por defecto aunque en la nube esté guardado otro. No se pierde dinero ni datos financieros; se pierde
configuración, y de forma silenciosa.

Y hay un sexto con el defecto **al revés** —el perfil financiero del onboarding: entra desde el otro
dispositivo, pero no hay camino de salida— que hasta hoy no tenía ticket propio. Está abajo, en «El
sexto caso».

## Lo medido

**5 de las 37 keys marcadas `synced: true` NO son `PrefSyncKey`**, así que el canal las **empuja** a iKV y al
outbox y **no tiene forma de aplicarlas al bajar**. *(Re-medido el 2026-09-02 y sigue en pie: 37 llamadas
`persist*(…, synced: true)` en `AppPreferences.swift`, y `moreSectionOrder` `:632`, `sankeyLabelMode` `:660`
y las tres de `panelHeroKPIs` `:675`/`:682`/`:689` no aparecen en `enum PrefSyncKey`.)*

| Key | Qué controla |
|---|---|
| `moreSectionOrder` | orden de las tarjetas de la pestaña «Más» |
| `sankeyLabelMode` | modo de etiqueta del diagrama Sankey |
| `panelHeroKPIs` (×3) | qué KPIs muestra el hero del Panel |

⇒ el viaje es **de ida y sin vuelta**: se sube, ocupa cuota y tráfico, y el device receptor jamás lo materializa.

## El sexto caso: `financialMindset`, el mismo defecto por el lado contrario

**Para el usuario:** el perfil financiero que eligió en el onboarding —«Día a día» o «Control total»,
que cambia los textos educativos y la calculadora de saldo— **sí llega** desde su otro dispositivo.
Lo que no existe es el viaje de vuelta: cualquier valor que ese dispositivo tenga o reciba **no se
publica nunca**. Hoy no se nota porque sólo se puede elegir una vez, al final del onboarding. El día
que haya una pantalla para cambiarlo —o cualquier otro camino que lo escriba— el cambio se queda en
el teléfono, en silencio, exactamente igual de silencioso que las cinco de arriba.

### Lo medido (árbol de hoy, lectura de código)

| Mitad | Dónde | Qué hace |
|---|---|---|
| **Bajada — funciona** | `Yala/App/Services/PreferenceSyncService.swift:468-470` | aplica el valor remoto (`SessionState.shared.financialMindset = mindset`) |
| **Subida — un solo emisor** | `Yala/App/Views/Onboarding/OnboardingView.swift:1793` | `sync.set(string: selectedMindset, forKey: "financialMindset")`, al cerrar el onboarding |
| **El espejo — no publica** | `Yala/App/Models/SessionState.swift:128-133` | el `didSet` sólo escribe local (`SessionDefaults.current.set(...)`); no toca el canal |

- Es **`PrefSyncKey`** (`Yala/Services/CloudSync/PreferenceMergeLogic.swift:81`, familia
  `.stringGuardNonEmpty` en :130-134), así que el canal sabe aplicarlo al bajar — por eso baja.
- **No tiene property en `AppPreferences`**: sólo la constante `Keys.financialMindset`
  (`Yala/App/Services/AppPreferences.swift:1311`). Sin property no hay `persist*(…, synced: true)`, y
  el push automático de `:1182-1204` no se dispara nunca por él.
- **Emisores medidos: uno.** `OnboardingView.swift:1793` es el único `sync.set` con esa key en todo
  `Yala/`. Escritores de la propiedad: dos, y ninguno publica — el propio onboarding (`:1794`, justo
  después de publicar a mano) y el merge remoto (`PreferenceSyncService.swift:470`).
- El repo ya lo sabía y lo dejó dicho en tres sitios, todos coincidentes con lo medido:
  `AppPreferences.swift:945-952` («…y por eso `financialMindset`, de forma idéntica y sin mirror,
  lleva sin sincronizar desde siempre»), `Yala/Services/CloudSync/SessionPreferenceKeys.swift:22-23`
  («Seis keys son `PrefSyncKey` y **no** son `synced: true`… entre ellas `financialMindset`») y
  `docs/aprendizajes-tecnicos.md:251`.

**Matiz que corrige a la documentación, medido:** `docs/aprendizajes-tecnicos.md:251` dice que
«`SessionState:131` escribe `.standard`». La línea es la correcta, el dominio ya no: hoy escribe en
`SessionDefaults.current`, que bajo sesión secundaria **no es** `.standard`. Quien vaya a buscar el
fallo por el dominio equivocado pierde una vuelta.

**Publicar desde el `didSet` NO es el arreglo, y esto es lo que hay que saber antes de tocarlo:** a
ese espejo llegan también el merge remoto y el reset de los tests de UI, así que publicar ahí
devolvería el eco —re-encolar con HLC fresco un valor recién bajado— y haría que un XCUITest encolara
preferencias. Está escrito, con el porqué entero, en el espejo gemelo de al lado
(`SessionState.swift:140-148`, sobre `isExpensesOnlyMode`). **Se paga en el punto de intención**, como
ya hace el onboarding.

### Es la MISMA decisión que las otras cinco

O se sincroniza de verdad —y entonces todo punto de intención nuevo publica, como el onboarding—, o
se deja de fingir y sale del canal. Lo que no es defendible es el estado de hoy: una key que el enum
de sync promete y que nadie publica salvo una pantalla que se ve una vez en la vida.

### Por qué llega aquí ahora

Este caso **no tenía ticket**. Vivía dentro de otro: `tickets/blocked/apppreferences-rewritten-on-launch.md:152`
lo declara residual abierto y lo marca literalmente «**Sin ticket**». Ese ticket **acaba de moverse a
`blocked`** en este mismo commit, y un residual dentro de un ticket bloqueado es un residual que nadie
vuelve a leer. La decisión, en cambio, no depende de que se desbloquee nada: no necesita móvil, ni
device-QA, ni el canal encendido. Por eso se traslada aquí, que es donde vive su familia.

## Por qué importa ahora y no antes

Salió al arreglar el eco de `AppPreferences` (`05c44cf4`). Antes de ese fix, la **recarga** al arrancar era un
puente accidental que tapaba parte del problema; el fix lo quitó a propósito —cargar ya no escribe— y con él
desapareció la casualidad que disimulaba estas cinco. Es el mismo mecanismo por el que `financialMindset`
lleva sin sincronizar desde siempre sin que nadie lo notara (el sexto caso, con su medición arriba).

**Y es el canal que el Modo Nube enciende.** Hoy el daño es invisible porque el multi-device de prefs está
dark; el día que se encienda, estas cinco se estrenan como pérdida de configuración entre dispositivos.

## La decisión pendiente (esto es lo que hay que resolver, no un fix mecánico)

Para cada una de las cinco, elegir:

1. **Añadirla a `PrefSyncKey`** — sincroniza de verdad, en las dos direcciones. Cuesta definir su forma en el
   wire y su resolución LWW; `moreSectionOrder` y los tres `panelHeroKPIs` son colecciones/orden, así que hay
   que decidir si el merge es LWW del blob entero o algo más fino.
2. **Bajarla a `synced: false`** — deja de subir. Es local por dispositivo, que para un orden de tarjetas o un
   modo de etiqueta puede ser lo correcto y lo más barato.

**No es «añadirlas todas al enum» por inercia:** un ajuste de presentación por dispositivo es una decisión de
producto legítima. Lo que NO es defendible es el estado actual —subir y no volver—, que tiene el coste de las
dos opciones y el beneficio de ninguna.

**Y para el sexto, las mismas dos con los papeles cambiados:** (1) que sincronice de verdad —publicar
desde cada punto de intención, nunca desde el espejo— o (2) que salga de `PrefSyncKey` y sea del
teléfono. Se decide igual y en la misma sentada; lo único que cambia es cuál de las dos mitades del
viaje falta.

## Criterio de hecho

- Ninguna key `synced: true` fuera de `PrefSyncKey`. Un test que lo pinnee **por source-scan o por tabla**, con
  su mutación a exit 65 (añadir una key `synced: true` sin entrada en el enum tiene que poner rojo).
- Si alguna baja a `synced: false`, comprobar que deja de aparecer en el outbox de prefs y en iKV.
- **Ese criterio, tal como está escrito, NO alcanza al sexto caso** — y es el mismo agujero que ya
  documenta `SessionPreferenceKeys.swift:20-28`: la red «`synced: true`» es insuficiente por los dos
  lados. `financialMindset` es `PrefSyncKey` y **no** es `synced: true`, así que ningún pin sobre
  `synced: true` lo ve. Si se decide sincronizarlo de verdad, el pin que hace falta es el simétrico:
  **ningún caso de `PrefSyncKey` sin al menos un emisor** (`persist*(…, synced: true)` o un `set` a
  mano en un punto de intención), con su mutante — quitar el `sync.set` de `OnboardingView` tiene que
  poner rojo.

## Relacionado

- Regla durable: `.claude/rules/swiftdata-cloudkit.md` § «CARGAR una preferencia no puede ESCRIBIRLA» (donde
  vive el invariante y los otros tres residuales de la misma familia).
- Detalle del diagnóstico del eco: `.claude/rules/testing.md`, bullet del lavado general.
- Commit del fix que lo destapó: `05c44cf4`.
- **Duplicado, ya archivado:** `synced-prefs-outside-prefsynckey` (`created: 2026-08-29`) abrió estas
  mismas cinco keys sin ver que este ticket existía desde el **2026-08-06**. Se mueve a
  `tickets/discarded/synced-prefs-outside-prefsynckey.md` en este mismo commit. Este es el dueño; si
  vuelve a aparecer una tercera vez, es que el residual se está leyendo desde
  `docs/aprendizajes-tecnicos.md` sin pasar por el tablero.
- Origen del sexto caso: `tickets/blocked/apppreferences-rewritten-on-launch.md:152`, donde figuraba
  como residual «Sin ticket».

migrated from YalaWiki Bugs/prefs-cinco-keys-synced-suben-y-no-vuelven.md @ 1934e8ad

---

## 2026-09-03 (noche) · decidido y aplicado

**Decisión del owner (2026-09-02): las cinco pasan a `synced: false`; `financialMindset` sincroniza
de verdad.**

### Las cinco — hechas

Son las cinco ajustes de PRESENTACIÓN (orden de las tarjetas de «Más», modo de etiqueta del Sankey y
los tres de los KPIs del hero del Panel). Que cada dispositivo tenga el suyo es una decisión de
producto legítima; lo que no era defendible es el estado en que estaban, con el coste de las dos
opciones y el beneficio de ninguna.

`Yala/App/Services/AppPreferences.swift` — `synced: true` → `synced: false` en `:632`, `:660`,
`:675`, `:682`, `:689`.

**Y la red, que es lo que impide la sexta copia:** `YalaTests/CloudSync/SyncedKeysArePrefSyncKeysTests.swift`
compara por source-scan las keys marcadas `synced: true` contra los `case` de `PrefSyncKey` y falla si
alguna sube sin que el merge sepa bajarla. Lleva **control positivo** en los dos escáneres (si
cualquiera deja de leer, la resta daría vacío y el test pasaría en verde sin comprobar nada — el modo
de fallo clásico de un source-scan). Cubre el primer punto del criterio de hecho.

### `financialMindset` — el diagnóstico cambia el arreglo, y conviene leerlo antes de tocarlo

Al medirlo se cae la formulación de arriba. **Hoy NO está roto**: baja bien (es `PrefSyncKey`, y
`PreferenceSyncService.swift:468-470` lo aplica) y sube bien por el único camino que existe, que
publica a mano en el punto de intención (`OnboardingView.swift:1793`).

**El defecto es futuro, no presente.** No tiene property en `AppPreferences`, así que no hay
`persist*(…, synced: true)` y el push automático no se dispara nunca por él. Mientras el perfil sólo
se pueda elegir una vez, al final del onboarding, no se nota. El día que exista una pantalla para
cambiarlo —o cualquier otro camino que lo escriba— ese cambio se queda en el teléfono, en silencio.

**Y el arreglo que parece obvio es el equivocado:** publicar desde el `didSet` del espejo devolvería
el ECO —re-encolar con HLC fresco un valor recién bajado— y haría que un XCUITest encolara
preferencias. El porqué entero está escrito en el espejo gemelo de al lado (`SessionState.swift`,
sobre `isExpensesOnlyMode`). **Se paga en el punto de intención**, que es justo lo que el onboarding
ya hace.

⇒ «Que sincronice de verdad» se traduce, con la medición delante, en **conservar la publicación en el
punto de intención y poner una red que impida que aparezca un escritor sin publicar**. No hay cambio
de comportamiento que hacer hoy.

### Lo que queda

- **El criterio de hecho declara que su primer punto NO alcanza al sexto caso**, y sigue siendo
  cierto: el escáner nuevo comprueba «`synced: true` ⇒ `PrefSyncKey`», y `financialMindset` es el
  caso contrario (`PrefSyncKey` sin `synced: true`, a propósito). Su red propia —contar los
  escritores de la propiedad y exigir que cada uno, salvo el merge remoto, publique— **no está
  escrita**: exige distinguir el escritor legítimo del eco, y eso es más que un conteo.
- Comprobar en un aparato real que las cinco **dejan de aparecer** en el outbox de prefs y en el
  iCloud KV. Es el segundo punto del criterio de hecho y necesita device-QA del owner.
