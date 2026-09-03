---
id: apppreferences-rewritten-on-launch
status: blocked
priority: high
created: 2026-08-05
updated: 2026-09-02
source: YalaWiki/Backlog/qa_apppreferences-lavado-general.md
---


# Las preferencias se volvían a guardar solas cada vez que se abría la app

## Qué lo desbloquea

**Dos aparatos reales con la misma cuenta de iCloud, y nada más.** El arreglo ya está en el
código desde el 2026-08-05; lo que falta es la única comprobación que no cabe en un test: que un
ajuste cambiado en un aparato aparezca en el otro. Los tres casos de «QA pendiente» son los tres
de la misma forma —tocar en A, mirar en B—, así que **con un solo dispositivo no se puede cerrar
ninguno**, ni siquiera parcialmente. Un simulador no le propaga a otro aparato lo que guarda en
iCloud, y por eso esto no es cuestión de dedicarle más tiempo a la suite.

Mientras eso no ocurra el ticket se queda aquí. **Lo que sí se puede avanzar sin dispositivos son
sus residuales**, y por eso dos de ellos ya salieron a tickets propios (ver la sección de
residuales, al final): quedarse colgando de este bloqueo los congelaba sin motivo.

## Descripción

`AppPreferences` es el objeto que la app usa para leer y escribir todos los ajustes del
usuario (divisa, formato, orden de cuentas, secciones del Panel, alertas…). Cada vez que la
app arrancaba —y cada vez que algo cambiaba en `UserDefaults`— releía los ~70 ajustes, y al
releerlos **los volvía a escribir**.

Para un ajuste que ya estaba guardado eso no se nota: escribir lo mismo encima deja el disco
igual. Por eso nadie lo vio en once meses. Pero tenía tres consecuencias reales:

1. **Ajustes que debían ser temporales se volvían permanentes.** Es el bug que ya se había
   arreglado a medias: tras correr un test de UI, abrir Yala Dev a mano en ese simulador se
   saltaba el onboarding. El arreglo de `ebb6fd46` (sin ticket propio en el vault) hizo que
   esos valores vivieran solo en memoria… y esta relectura los devolvía al disco.
2. **Se re-subían ajustes a iCloud en cada arranque.** Medido sobre el archivo real de
   preferencias del simulador: 6 ajustes se volvían a subir cada vez que se abría la app, con
   una sincronización dedicada por cada uno. Y peor: eso pasa **antes** de que la app se baje
   lo que hubiera cambiado en otro dispositivo, así que podía pisar un cambio hecho en el
   iPad mientras el iPhone estaba cerrado.
3. **Con el Modo Nube, un ajuste recién bajado del servidor se volvía a subir** con marca de
   tiempo nueva, dejando a este dispositivo como «autor» de algo que no había cambiado.
   Todavía no está encendido, pero era un agujero esperando.

Y en la dirección contraria: al vaciar los datos, cinco ajustes volvían a aparecer con su
valor por defecto justo después del borrado, y encima se propagaban a los otros dispositivos.

## Implementación

**2026-08-05 · `05c44cf4` · rama 2.0.5**

| Archivo | Qué cambia |
|---|---|
| `Yala/App/Services/AppPreferences.swift` | El arreglo: un interruptor interno (`isLoadingFromDefaults`) hace que **cargar no escriba nada**, ni al disco ni a iCloud. Se retiran los dos parches locales que `ebb6fd46` había puesto en las dos preferencias del onboarding. Reescritos 6 comentarios que habían quedado mintiendo. |
| `Yala/App/Views/Notifications/NotificationPrimerSheet.swift` | Al conceder permisos de notificación, activar las alertas de presupuesto ahora se publica a iCloud a propósito. |
| `Yala/App/Views/Settings/PersonalizationSettingsView.swift` | El interruptor «Solo gastos» publica a iCloud a propósito. |
| `Yala/App/Models/SessionState.swift` | Comentario que deja escrito que ese espejo **no** publica, y por qué (a él llegan también los cambios que vienen de otro dispositivo). |
| `Yala/App/UITestEphemeralDefaults.swift` | Su documentación apuntaba al parche retirado. |
| `YalaTests/UITestSeamPersistenceIsolationTests.swift` | 3 pruebas nuevas + 2 escáneres de código; la matriz existente pasa de 2 a 14 preferencias. |
| `.claude/rules/testing.md` | Residual cerrado y los cuatro que siguen abiertos. **Ya no están ahí** — ver el aviso bajo la tabla. |
| `qa/coverage-index.json` | 3 áreas actualizadas. |

> **Dónde están hoy los cuatro residuales (medido el 2026-09-02, árbol `553b91c9`).** Esa última
> fila describe lo que el commit hizo en su día, no dónde buscar ahora: `.claude/rules/testing.md`
> tiene hoy 102 líneas y **cero** menciones de `AppPreferences`, del lavado, de `financialMindset`
> o de `ProTourManager` — el commit `9e7e8d6c` («las reglas de Yala dejan de inyectar 220 KB por
> sesión») lo adelgazó después. El diagnóstico completo y los cuatro residuales viven en
> **`docs/aprendizajes-tecnicos.md`**, en los apartados (a)-(d) de la entrada del lavado general
> (hoy `:255`; la regla de sync que la acompaña arranca en `:215`). **No se copia aquí su
> contenido a propósito**: duplicarlo en dos superficies es exactamente cómo divergen.

### Decisiones técnicas y su porqué

**El diagnóstico del ticket era incorrecto, y la corrección importa.** Se creía que el guard
`oldValue != nuevo` «solo protege a los valores que coinciden con el default hardcoded». Lo
que pasa de verdad es más simple: ese guard **corta el bucle pero no el primer rebote**, y
el primer rebote es justo el que escribe. Escrito mal, el arreglo se habría buscado en el
sitio equivocado.

**El interruptor va en los tres helpers de persistencia, no en cada `didSet`.** Así una sola
condición gatea la escritura local **y** el envío a iCloud. Eso es lo que permite probarlo
contando escrituras sobre un almacén de juguete: `PreferenceSyncService` es un singleton
atado a `UserDefaults.standard` y espiarlo exigiría tocar sus ~20 construcciones de la
suite. Como la garantía es estructural y no observable, va fijada además por un escáner de
código; el mutante que lo justifica —dejar el envío fuera del guard— deja los tres tests de
conteo en verde y solo cae en el escáner.

**Se retiran los dos parches locales de `ebb6fd46`.** Un cinturón que tapa el fallo del
mecanismo general es peor que no llevarlo: dejaba a la prueba sin caer con el mutante,
precisamente sobre las dos preferencias que nombra.

**El puente hacia iCloud se corta y se paga en el punto de decisión.** Hasta ahora, quien
escribía un ajuste «a pelo» llegaba a iCloud de rebote, por esta misma relectura. Era un
accidente y no un mecanismo: `financialMindset` tiene la forma idéntica, no tiene espejo en
`AppPreferences`, y **lleva sin sincronizar desde siempre sin que nadie lo notara**. Los dos
que sí dependían de él se cablearon donde el usuario decide, igual que ya hacía el
onboarding. Publicar en el espejo de `SessionState` habría sido la trampa: a ese `didSet`
llegan también el cambio bajado de otro dispositivo y el reinicio de los tests de UI.

**La matriz de la prueba va por FORMA de carga, no por preferencia** (enum, entero, booleano
con default `true`, texto, listas por coma y por barra…). Medido con un meta-mutante: con la
matriz vieja —dos preferencias, las dos booleanas— romper el guard de los textos o de los
enteros dejaba el test **en verde**.

### Verificación — foto del 2026-08-05, NO es el estado de hoy

- Gate completo **del 2026-08-05**: `Yala` ✓ / `Yala Dev` ✓ (0 warnings nuevos), 5564 unit en 520
  suites, 11 XCUITest en 6 suites, audit limpio, ratchet OK.
- **9 mutantes a exit 65**, cada uno cayendo solo en su mitad.

> **Este «verde» no se puede reusar como estado actual.** Es una medición de hace casi un mes, y
> además un verde ya no significa lo que parece: `tickets/backlog/ci-verde-con-la-suite-en-rojo.md`
> documenta que los pasos de test del CI llevan `continue-on-error`, así que el run sale marcado
> como correcto aunque `xcodebuild` termine en error — llevaba semanas ocultando ocho tests en
> rojo. Quien retome este ticket **vuelve a correr el gate**; no da por bueno lo de arriba.

## QA pendiente

Lo único que no se puede probar desde un test, y hay que hacerlo con **dos dispositivos** y
la misma cuenta de iCloud:

1. Activar **«Solo gastos»** desde Ajustes → Personalización en el dispositivo A y comprobar
   que el B lo recoge.
2. Conceder permisos de notificación desde el primer aviso en el A (activa las alertas de
   presupuesto) y comprobar que el B las tiene activadas.
3. Comprobar que **abrir la app no pisa** un ajuste cambiado en el otro dispositivo mientras
   ésta estaba cerrada (cambiar la divisa en el B con el A cerrado, abrir el A).

## Residuales, medidos y NO cerrados

Los cuatro se midieron el 2026-08-05 y **el detalle vive en `docs/aprendizajes-tecnicos.md:255`**
(apartados a-d), no aquí ni en `.claude/rules/testing.md`. Abajo solo queda quién los lleva.

- **Las dos preferencias del onboarding se quedan escritas en el simulador tras una corrida de
  tests** — y si lo que se escribe es `false`, el aislamiento se desarma a mitad de camino.
  **Tiene ticket propio desde el 2026-09-02 y NO necesita dos móviles:**
  `tickets/backlog/appstorage-onboarding-desarma-el-aislamiento-de-tests.md`. Es código de la app
  y se comprueba con la suite, así que no tiene por qué esperar a este bloqueo.
  **Corrección de este residual, re-medida el 2026-09-02 en el árbol `553b91c9`:** decía
  «`ContentView`/`GroupReconnectView` escriben», y `GroupReconnectView` **no escribe** — sus dos
  únicas apariciones son la declaración (`Yala/App/Views/Groups/GroupReconnectView.swift:15`) y
  una lectura en un `guard` (`:69`). Lo que contamina está todo en `ContentView`.
- **5 de las 37 preferencias marcadas como sincronizadas no existen en `PrefSyncKey`**: suben a
  iCloud y no vuelven jamás. **Ya tiene dueño:**
  `tickets/backlog/prefs-synced-keys-upload-not-download.md`. No lo abras otra vez — ya se abrió
  dos veces, y el duplicado (`synced-prefs-outside-prefsynckey`) acaba de moverse a
  `tickets/discarded/`.
- `financialMindset` sigue sin sincronizar fuera del onboarding (preexistente). **Sin ticket.**
- `ThemeManager.resetToDefaults` y `ProTourManager.reset` vuelven a escribir tras el vaciado
  lo que el vaciado acaba de borrar — mismo molde, inofensivo hoy porque ninguna de esas
  preferencias se sincroniza. **Sin ticket**; importa sobre todo a quien escriba un test que
  afirme «esta preferencia no existe tras el vaciado».

migrated from YalaWiki Backlog/qa_apppreferences-lavado-general.md @ 1934e8ad
