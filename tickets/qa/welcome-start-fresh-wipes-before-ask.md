---
id: welcome-start-fresh-wipes-before-ask
status: qa
created: 2026-08-12
updated: 2026-08-26
source: YalaWiki/Bugs/qa_welcome-empiezo-de-cero-borra-antes-de-preguntar-y-falla-mudo.md
---


# «Es mi primera vez» borra dos preferencias antes de preguntar, y si el borrado falla no te lo dice nadie

## El síntoma, en lenguaje de usuario

**Defecto 1.** Tengo Yala con mis datos. Salgo de la app (o llego al Welcome por cualquier vía) y tapeo
«Es mi primera vez en Yala» por curiosidad. Sale un alert avisándome de que se van a borrar mis datos y
le doy a **Cancelar**. Todo parece intacto. **Dos días después abro la app y mi nombre ya no está** — y
la divisa por defecto tampoco.

**Defecto 2.** Ese mismo alert, aceptado: si el borrado falla, la app **sigue adelante igual** y me mete
en el onboarding «de cero» sobre datos que no se borraron. Ni un mensaje.

## Lo medido

### Defecto 1 · el borrado va ANTES del `if`

`ContentView.startFreshPrivateOnboarding()`:

```
1611     OnboardingResetHelper.clearResidualPreferencesForFreshStart()
1616     if hasExistingData {
1617         showFreshStartWipeAlert = true
```

La limpieza corre **antes** de decidir si se pregunta, así que «Cancelar» no la deshace.
`OnboardingResetHelper.swift:25` quita `userName` y `defaultCurrencyCode` de `UserDefaults` y escribe
`""` en los dos del iKV.

**Y el efecto es diferido, que es lo que lo hace desconcertante**: `AppPreferences.loadFromDefaults()`
solo corre en el `init` y descarta los valores vacíos (`AppPreferences.swift:972`, el `!raw.isEmpty`), así
que el nombre en memoria sobrevive hasta el siguiente arranque en frío. Lo que la persona percibe es que
su nombre desaparece **solo**, un arranque después de haber cancelado un alert.

### Defecto 2 · el `catch` es mudo fuera de Debug

`ShellDataAlertsModifier.swift:83-89` — si `wipeAllUserData` o `wipeLocalGroupsDomain` lanzan, el `catch`
imprime bajo `#if DEBUG` y el flujo continúa igual a `showWelcomeFlow = false; showOnboarding = true`.
**No hay canario ni alert para este caso.**

> Nota de coordenadas para quien lo ataque: `ContentView.swift:1616` es solo el disparador. El alert con
> su copy, su botón destructivo y los DOS wipes (personal + dominio Grupos local) vive en
> `ShellDataAlertsModifier.swift:64-97`, extraído de `ContentView` por presupuesto del type-checker.
> Citar 1616 como «el alert» lleva a un `if` sin copy.

### Dato de contexto: hay DOS entradas al onboarding privado y solo una lleva alert

El «Empezar desde cero» de la pantalla de restauración (`ContentView.swift:668-676`) llama a la misma
limpieza de residuales y abre el onboarding **sin consultar `hasExistingData` y sin alert**.

## El fix, que es pequeño

1. Mover `clearResidualPreferencesForFreshStart()` **dentro** de la rama que de verdad procede al
   borrado (o al `onConfirm` del alert). Hoy hay dos llamadas más en otros caminos
   (`ContentView.swift:1530` en el portal del relanzamiento y `:668` en restaurar); las tres tienen que
   quedar coherentes: **se limpia cuando se borra, no cuando se pregunta**.
2. Dar superficie al fallo del wipe: un alert («No pudimos borrar tus datos») + **canario**, y NO seguir
   al onboarding. Hoy la app miente sobre un borrado que no ocurrió.

## Criterio de hecho

- Un test que ejercite «tapear → Cancelar» y verifique que `userName` y `defaultCurrencyCode` **siguen**
  en `UserDefaults` y en el iKV. Hoy ese test no existe y por eso el defecto lleva vivo lo que lleve.
- Un test del camino de fallo del wipe que exija que NO se navega al onboarding.
- Canario del wipe fallido, fuera de `#if DEBUG` (misma familia que
  `attestKeyDiscardedAfterAssertFailure`).

## Relacionados

- [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]] — el mismo alert visto desde la sesión de visita, donde además el detector mide el store equivocado
- [[welcome-copy-acusa-al-dueno-de-traer-datos-ajenos]] — otra salida del mismo Welcome

## Implementación

**2026-08-12 · `73ab6134`** (branch `2.0.5`). Re-medido contra el árbol: las coordenadas del ticket
(`ContentView.swift:1611`/`:1616`, `ShellDataAlertsModifier.swift:83-89`) estaban **exactas**.

### Archivos

| Archivo | Qué cambia |
|---|---|
| `Yala/App/ContentView.swift` | La limpieza baja de la primera línea de `startFreshPrivateOnboarding` a la rama `else`; `@State showFreshStartWipeFailedAlert` + su cableado a los dos observadores de readiness |
| `Yala/App/Views/Shared/ShellDataAlertsModifier.swift` | Limpieza dentro del confirm destructivo; los DOS `catch` emiten canario y presentan alert en vez de navegar; alert nuevo de fallo |
| `Yala/App/Logic/ContentViewReadinessLogic.swift` · `ReadinessGateObservers.swift` | El alert nuevo es blocker de la matriz |
| `Yala/Services/Metrics/MetricsService.swift` | Canario `freshStartWipeFailed`, con `detail` que separa los dos caminos |
| `Yala/Utils/L10n.swift` + 16 `.strings` | `welcome.freshStart.failedTitle` / `failedMessage` |
| `YalaTests/FreshStartWipeAlertTests.swift` (nuevo, 7 tests) · `ContentViewReadinessLogicTests.swift` | El pin |

### Decisiones, con su porqué

1. **La limpieza va DESPUÉS del wipe dentro del confirm, no antes.** Si el wipe lanza, las prefs no
   se tocan: sería el mismo defecto del ticket movido de sitio (borrar residuales de unos datos que
   siguen ahí).
2. **Los otros dos call-sites de `clearResidualPreferencesForFreshStart` NO se tocan.** `:672`
   («Empezar desde cero» de la pantalla de restauración) y `:1530` (portal del relanzamiento) son
   fresh-starts YA confirmados por el usuario y ninguno tiene alert que cancelar. El ticket pedía
   «que las tres queden coherentes»: lo son bajo la regla «se limpia cuando se borra», porque en esas
   dos el borrado ya se decidió.
3. **Un solo alert de fallo para los dos wipes**, no uno por camino: lo que la persona necesita saber
   es idéntico (sus datos siguen aquí, no la hemos movido) y el `detail` del canario ya distingue el
   origen. Sin botón de reintento — un segundo wipe sobre el mismo store fallaría igual; la salida
   honesta es cerrar y volver a abrir.
4. **El pin es un source-scan del ORDEN y no un test de comportamiento.** La tabla de decisión nunca
   estuvo mal: mal estaba dónde caía la llamada respecto del `if`, y los dos lados viven en vistas
   SwiftUI no invocables desde un unit test. Molde `SecondaryOwnerDomainWiringTests`. Los 7 tests
   estaban **rojos** contra el árbol anterior (exit 65) — esa corrida es la mutación.

### Barrido del patrón (regla «todas las instancias»)

Los otros dos `wipeAllUserData` del repo NO comparten el defecto: `UserDataResetView:266` ya expone
`errorMessage`, y el de `ContentView:1219` es el wipe **remoto reactivo** (lo dispara una señal de
otro dispositivo, no hay navegación detrás que pueda mentir). Anotado, no tocado.

### Gate

Build `Yala` ✓ · `Yala Dev` ✓ (0 warnings nuevos) · unit 75/75 en 3 suites (incl.
`LocalizationParityTests`) · XCUITest 4/4 (`OnboardingFlowUITests`, `InboxNewItemsModalUITests`) ·
`validate-coverage.sh` OK. `lastVerified` de `onboarding-flow` e `inbox-new-items-modal` al 2026-08-12
en el mismo commit.

### Lo que falta (QA visual)

El alert de fallo **no se ha visto en pantalla**: forzar que `wipeAllUserData` lance exige un store
bloqueado y no hay seam para inyectarlo desde XCUITest. El canario es su superficie de observación.

---

## QA Visual · 2026-08-14 · simulador iPhone 17 Pro (iOS 26.5), scheme Yala Dev

**Defecto 1 — PASS.** **Defecto 2 — NO VERIFICABLE aquí** (ver abajo).

### Método, porque el primer diseño estaba contaminado

El primer intento metió el cierre de sesión en el recorrido para llegar al Welcome — y `.privateReset`
toca las MISMAS keys que el alert, así que un «desaparecio» no habria distinguido quien lo hizo. Y
`userName` ni siquiera estaba en disco de partida: el seed no lo escribe, asi que medir su ausencia no
probaba nada.

Se rehizo aislado, con una **sonda que ningun seed puede producir** (`userName = QA-SONDA-99`,
`defaultCurrencyCode = CHF`), plantada en el plist REAL del contenedor + kickstart de `cfprefsd`, y
**verificada antes de correr nada**.

### Los tres pasos, y sus dos controles

| Paso | userName | defaultCurrencyCode | Control |
|---|---|---|---|
| Plantado (ANTES) | `QA-SONDA-99` | `CHF` | `lastSeenAppVersion = 2.0.5` presente ⇒ el instrumento lee |
| «Es mi primera vez» → **Cancelar** | `QA-SONDA-99` | `CHF` | **intactas** |
| «Es mi primera vez» → **Borrar todo y continuar** | `<AUSENTE>` | `<AUSENTE>` | **control NEGATIVO**: el instrumento SI detecta el borrado |

El control negativo es lo que hace que el PASS signifique algo: sin el, «la sonda sobrevive» seria
compatible con «el alert no hace nada en este escenario». Aceptar ademas aterriza en el onboarding con
`onboarding_name_field` VACIO, que es la confirmacion en pantalla del borrado.

⇒ **el fix de `73ab6134` hace lo que promete: Cancelar conserva, Aceptar borra.**

### Lo que NO se pudo verificar, y no es un FAIL

El **defecto 2** (si el wipe LANZA, el alert de fallo en vez de navegar en silencio) — que es
literalmente lo que el `status` del ticket decia que faltaba. Forzar el throw de `wipeAllUserData` o de
`wipeLocalGroupsDomain` no tiene seam de test, y sin el no hay forma de llegar a esa rama desde la UI.

**Opciones para cerrarlo**, en orden de coste: (a) un seam `-uitest-fail-wipe` que haga lanzar al
servicio, y entonces es un XCUITest determinista y no QA manual; (b) dejarlo como residual declarado,
apoyado en los 7 tests de `FreshStartWipeAlertTests` que ya pinnean el orden y el cableado del alert.

### Nota para el indice de QA

El recorrido del defecto 1 es **determinista** y lo acabo de repetir a mano dos veces: es candidato a
XCUITest (plantar la sonda desde un seam, tapear, afirmar). Eso valdria mas que esta captura.

> [!warning] Precision sobre el ENTORNO de este QA (anotado el 2026-08-14)
> La corrida se hizo con el scheme «Yala Dev» pero **configuracion `Debug`**, y esa combinacion produce
> el bundle de **PRODUCCION** (`com.jurgenschmidt.yala`), no el `.dev`. Medido despues con
> `xcodebuild -showBuildSettings`: `Debug` → `com.jurgenschmidt.yala`; `Debug-Dev` →
> `com.jurgenschmidt.yala.dev`. Fue un error de configuracion mio, no del proyecto.
>
> **Por que lo verificado SIGUE VALIENDO**: los seams `-uitest-*` viven bajo `#if DEBUG` y el build era
> Debug, asi que funcionaron (se vieron en pantalla); y las mediciones de `UserDefaults` se hicieron
> sobre el plist del bundle QUE CORRIA, con control positivo y negativo. Lo que NO tuvo el build es
> `DEV_BUILD`, que enciende por defecto algunos flags remotos ⇒ **la corrida fue en el entorno MAS
> restrictivo**, no en uno mas permisivo.

migrated from YalaWiki Bugs/qa_welcome-empiezo-de-cero-borra-antes-de-preguntar-y-falla-mudo.md @ 1934e8ad
