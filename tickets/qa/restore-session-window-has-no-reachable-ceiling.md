---
id: restore-session-window-has-no-reachable-ceiling
status: qa
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `leaving-and-reentering-restore-renews-the-hard-cap`, 2026-09-21 — se implementó un techo y la review lo tumbó midiendo sus dos mitades"
---

# La ventana de sesión del restore no tiene techo alcanzable

## El problema, en lenguaje de usuario

No hay síntoma para el dueño legítimo. Quien tiene en la mano un teléfono con los datos de otra
persona puede mantener abierta —todo el tiempo que quiera— la ventana que permite entrar en la cuenta
sin que la app avise de que ese corpus es ajeno. No hay un número que lo limite.

## Medido (2026-09-21): por qué el techo obvio no funciona

`leaving-and-reentering-restore-renews-the-hard-cap` cerró la mitad monótona del agujero: el re-ancla
ya exige una descarga VIGENTE, no una histórica. Su tercer criterio pedía además **un techo acotado y
medible**, y ahí se implementó uno —`reanchorChainStartedAt`, el reloj de la cadena de re-anclas, que
ningún re-ancla movía— que **la review tumbó midiendo sus dos mitades**. Se retiró antes de commitear.

### Mitad 1 · No acotaba, porque `noteRestoreFinished` es alcanzable desde la UI con el import vivo

Recorrido medido, tres toques y sin esperar nada:

1. En `.restore` con la ventana abierta, estado `.importIncomplete` o `.found` —los dos ofrecen
   «Empezar desde cero» (`WelcomeRestoreView:560` y `:381`).
2. «Empezar desde cero» → confirmar. Su confirmación llama a `noteRestoreFinished`
   (`WelcomeRestoreView:222-225`), que apaga la ventana **con el import todavía bajando** — y apagaba
   también la cadena. Después, `onStartFresh()` → `FullModeActivationView:216` `go(to: .restoreDiscardGate)`.
3. En la puerta, «Volver» → `FullModeActivationView:174` `go(to: .restore)`. **La puerta solo pregunta:
   no ha borrado nada.**
4. Remonta `WelcomeRestoreView` → `.task { startSearch() }` → `restoreStartedAt == nil` ⇒ **ventana
   nueva de 600 s**, y con el techo puesto, cadena nueva también.

En `ContentView` el bucle es el mismo (`:902` → `WelcomeFlowContainer:264-267`).

**Y hay un baseline por debajo que ningún techo puede tocar**: la señal vive en memoria a propósito
—su sesgo fail-closed—, así que **matar la app y volver a entrar estrena todo**.

### Mitad 2 · Y sí bloqueaba al dueño legítimo, de forma permanente en el proceso

Con el techo puesto:

- `t=0` entra a Restaurar con un corpus de 15 minutos. `restoreStartedAt = 0`, cadena `= 0`.
- `t=100` toca atrás → la ventana queda huérfana (el reloj sigue puesto: el import baja).
- `t=650` vuelve: `chainAge ≥ 600` ⇒ no re-ancla, hereda `restoreStartedAt = 0`; `elapsed ≥ hardCap`
  ⇒ `isRestoringNow == false` ⇒ **`.blockedForeignData` sobre su propia cuenta con sus datos bajando**.

Y peor: a partir de ahí **nada vuelve a armar la cadena en ese proceso**. Con `restoreStartedAt != nil`
la rama del estreno no corre, y la única que lo limpia es `noteRestoreFinished`, que en ese desenlace
(`!settled && sawImport`) no se llama por diseño. No es «una ventana cada 600 s»: es **una
oportunidad, y solo una**, hasta que la persona mate la app.

⇒ El techo **no frenaba a quien quisiera saltárselo y sí castigaba a quien no**. Por eso se retiró en
vez de apuntalarse.

## Lo que haría falta para que un techo signifique algo

Cualquier intento tiene que empezar por cerrar —o aceptar— las dos puertas libres:

- **El estreno** (`restoreStartedAt == nil`) es la puerta grande y tiene que seguir abierta: es lo que
  hace útil la señal. Un techo que viva dentro de `noteRestoreStarted` no puede acotarla.
- **`noteRestoreFinished` desde la UI**: hoy lo llaman la pantalla de progreso y la confirmación de
  «Empezar desde cero». La segunda es la del recorrido de arriba.

Tres caminos posibles, ninguno decidido:

1. **Un presupuesto de tiempo abierto por PROCESO**, leído dentro de `isRestoringNow` en vez de en el
   re-ancla. Acota también los estrenos, y por eso hay que medir antes a quién deja fuera: tocaría el
   corazón del guard.
2. **Que volver desde la puerta de descarte NO estrene**, distinguiendo «volví sin descartar» de una
   entrada nueva. Cierra el recorrido de tres toques y deja intacto el baseline de relanzar.
3. **Aceptar que no hay techo y declararlo**, apoyándose en que el baseline de relanzar la app lo hace
   inalcanzable de todos modos, y gastar el esfuerzo en que la ventana sea más estrecha por otras vías.

## Criterios de aceptación

- [ ] El recorrido «Empezar desde cero» → «Volver» → Restaurar no estrena ventana nueva, **o** está
      escrito por qué se acepta que lo haga.
- [ ] Ningún camino deja al dueño legítimo sin poder abrir ventana durante el resto del proceso
      (la mitad 2 de arriba no se reintroduce).
- [ ] Lo que se elija se mide con un test que recorra el ciclo completo, incluido el paso por
      `noteRestoreFinished`.

## Relación con otros tickets

- `leaving-and-reentering-restore-renews-the-hard-cap` — de donde sale; cerró la mitad monótona.
- `abandoned-restore-no-longer-clears-the-session-window-clock` — el re-ancla que no se puede deshacer.
- `restore-timeout-closes-the-session-window-with-the-import-still-running` — la misma familia por el
  eje del desenlace.

---

## Resuelto (2026-09-21)

### Qué cambia para quien usa la app

No hay síntoma para el dueño legítimo, y sigue sin haberlo. Lo que cambia está en el teléfono que
tiene los datos de otra persona: **hasta hoy, pedir «Empezar desde cero» y arrepentirse renovaba el
permiso que deja firmar sin aviso.** Tres toques —«Empezar desde cero», confirmar, «Volver»— y la
cuenta atrás empezaba de cero, sin esperar nada y sin que hiciera falta que bajara nada. Ahora
volver de esa pantalla continúa la cuenta donde estaba: la puerta solo pregunta, no borra nada, así
que arrepentirse no es empezar de nuevo.

Y de paso se arregla algo que nadie había notado y que sí muerde al dueño legítimo: **con una
descarga larga, «volver a buscar» no podía reabrir el permiso una vez agotado.** Quien traía un
histórico grande se quedaba, a partir de los diez minutos, con la app diciéndole que sus propios
datos eran de otra persona, con las filas entrando en ese momento y sin ninguna forma de salir de
ahí salvo cerrar la app. Ahora ese botón vuelve a servir.

### El mecanismo: apagar y OLVIDAR eran dos cosas distintas

La confirmación de «Empezar desde cero» llamaba a `noteRestoreFinished`, que apaga la ventana y
borra su reloj. Eso dejaba el estado **idéntico** al de «nadie ha pedido restaurar en este proceso»,
y la vuelta —que remonta `WelcomeRestoreView`, cuyo `.task` llama a `startSearch()`— estrenaba 600 s
enteros por la puerta grande del estreno, que no pregunta por ningún testigo.

Entra `noteRestoreDiscardRequested`: apaga igual **y aparca el reloj** en `parkedStartedAt`. El
estreno lo hereda mientras siga vigente (`ICloudRestoreInProgressLogic.resumableParkedWindowStart`,
edad en `[0, 600)`) y lo consume siempre.

| | Antes | Ahora |
|---|---|---|
| Confirmar el descarte | apaga y olvida | apaga y APARCA el reloj |
| Volver sin haber borrado | estrena 600 s | hereda: el tope sigue contando desde donde contaba |
| Agotado el tope | — | la entrada siguiente ESTRENA con normalidad |

**Esa última fila es lo que lo distingue del techo de cadena que la review tumbó el día anterior.**
Aquél, agotado, no dejaba ni re-anclar ni estrenar en el resto del proceso. Aquí el aparcado caduca
con el mismo tope duro de la ventana —y esa simetría ya no es prosa: los tres `600` del subsistema
salen de `ICloudRestoreInProgressLogic.sessionWindowHardCap`, una constante única—.

### Lo que cazó la review, que es la mitad del ticket

**Tres lentes, y las tres encontraron defectos míos.** Dos eran caros:

- **Mi primera versión le quitaba al dueño legítimo su única salida.** Con un import de doce minutos:
  el tope de 90 s se rinde con las filas entrando, descarta a los 100 s, vuelve a los 300 heredando
  el reloj de t0, y a los 600 la ventana muere **con la descarga viva**. A partir de ahí,
  `noteRestoreStarted` no entraba ni al estreno (`restoreStartedAt != nil`) ni al re-ancla
  (`currentFlow != nil`): **ningún reintento en pantalla la resucitaba.** El callejón ya existía para
  quien se quedaba 600 s en la pantalla; lo que mi cambio hacía era quitarle la salida, porque antes
  el descarte apagaba y la vuelta estrenaba limpio. Es la mitad 2 del techo tumbado, entrando por la
  caducidad en vez de por un presupuesto. Lo cierra una rama nueva —el RESCATE— y **su alcance costó
  una segunda iteración**: tratar «ventana agotada» como «apagada» para cualquiera deshace
  `leaving-and-reentering-restore-renews-the-hard-cap`, porque el ciclo salir-volver suelta la
  titularidad en cada vuelta y pasaba a estrenar sin necesitar descarga viva. Lo cazó su propio test,
  en rojo. El rescate va con `currentFlow != nil`: quien salió tiene el re-ancla, que le exige una
  descarga real; quien sigue dentro no tiene ninguna otra salida y su gesto es explícito.
- **El reloj aparcado se quedaba VARADO** cuando la vuelta caía en `.iCloudDisabled` o `.wiped`: los
  dos `return` tempranos de `startSearch()` no encienden la señal, así que nadie lo consumía. La
  persona enciende iCloud, toca «volver a buscar», y esa descarga **nueva** nace con un tope que
  puede tener un segundo de vida. Lo cierra `noteRestoreUnavailable()` en los dos `return`.

Y tres más, de verificación:

- **`parkedStartedAt = nil` en `noteRestoreFinished` era inalcanzable** —aparcar apaga en el mismo
  acto, y recuperar el dueño exige pasar por el estreno, que lo consume— y encima **enmascaraba** al
  mutante que le quita el consumo al estreno. Retirada, ese mutante pasa a morir por comportamiento.
- **Al verbo nuevo le faltaba la red que sus hermanos sí tienen**: el fichero pinneaba a un solo
  call-site los verbos que ENCIENDEN y SUELTAN, y ninguno de los dos que APAGAN. Peor: la enmienda D2
  (`GroupsOrganizerBranchTests`) prohíbe apagar el latch desde `WelcomeGroupsGateView` porque ahí el
  import sigue bajando y nadie lo vuelve a encender — **y solo conocía uno de los dos verbos**.
- **Un docblock mío afirmaba una premisa falsa**: «desde el borrado no hay vuelta a Restaurar sin
  pasar por el onboarding». En la activación sí la hay — borrar, llegar al onboarding, cancelarlo, y
  reabrir «Activar Yala completo» aterriza en `.restore` directo.

### Los tres criterios

- **Criterio 1 · el recorrido de tres toques**: CERRADO para el caso que el ticket nombra. No es un
  techo absoluto y el ticket ya sabía que no puede haberlo: por debajo sigue el baseline de matar la
  app. Lo que se cierra es el estreno **inmediato y a voluntad**; renovar pasa a costar esperar a la
  caducidad. La review midió además que **hay una vía más barata que ésta y que no pasa por aquí** —un
  toque cada 91 s en la población sin ningún import—, y tiene ticket propio:
  `restore-retry-reopens-the-session-window-every-90-seconds`.
- **Criterio 2 · nadie se queda sin ventana**: CERRADO, y mejor que antes del ticket — el rescate
  cierra también el callejón preexistente de quien agota el tope sin moverse de la pantalla.
- **Criterio 3 · el test de ciclo completo**: hay doce, y siete recorren el paso por el descarte.
  Seis mutantes aplicados y los seis muertos.

### Residual, con ticket

- `wiped-state-reaches-the-discard-gate-with-the-window-open` — el séptimo camino a la puerta, el
  único que no pasa por el diálogo, no apaga nada.
- `restore-retry-reopens-the-session-window-every-90-seconds` — la vía barata de arriba.

---

## QA en el teléfono (Jürgen)

**Por qué no vale el simulador ni un restore pequeño.** El fix solo muerde con la **descarga viva**:
si el import asienta antes de que llegues al botón, `RestoreProgressView` ya cerró la ventana por sus
propios méritos y el descarte es un no-op. Hace falta un corpus que tarde — varios minutos de bajada.

### Montaje

1. En el **iPhone de pruebas**, instala el build de TestFlight que salga de este merge.
2. Ajustes de iOS → tu nombre → **iCloud** → comprueba que la cuenta con el histórico grande está
   activa y que **iCloud Drive** está encendido (si está apagado, la app cae en `.iCloudDisabled`,
   que es otro camino).
3. Borra Yala del teléfono y vuelve a instalarla, para que el claim local desaparezca: ese claim es
   justo lo que hace falta que falte.
4. Ábrela y **no toques nada más**: déjala en el Hero.

### Caso 1 · El recorrido de tres toques ya no renueva (lo que cierra el ticket)

5. Hero → «Ya tengo una cuenta» → «Restaurar desde iCloud». La app se relanza sola: es normal.
6. Ábrela otra vez. Verás «Buscando tus datos…» con los conteos subiendo. **Apunta la hora exacta.**
7. Espera a que salga «Seguimos trayendo tus datos» o la pantalla con los conteos, **con el import
   todavía en marcha** (los números tienen que seguir moviéndose).
8. Toca **«Empezar desde cero»** → **Confirmar**. Llegas a la puerta que enseña las cifras de iCloud.
9. **No borres nada.** Toca **«Traer mis datos»** (o el chevron de atrás, da igual: los dos valen).
10. Vuelves a Restaurar. Espera a que pasen **más de diez minutos desde la hora del paso 6**.
11. Toca atrás y entra por la card de tu cuenta.
    - ✅ **Esperado**: la app te dice que **los datos son de otra persona** y no te deja firmar sin
      aviso. La cuenta atrás no se reinició al volver de la puerta.
    - ❌ **Fallo**: te deja entrar sin avisar. El paso 9 renovó el permiso.

### Caso 2 · El dueño legítimo no se queda encerrado (lo que arregló la review)

12. Repite del 3 al 9.
13. Quédate **en la pantalla de Restaurar** y espera a que pasen diez minutos desde el paso 6, con el
    import todavía bajando.
14. Toca el botón de **recargar** (la flecha circular, arriba a la derecha).
15. Ahora toca atrás y entra por la card de tu cuenta.
    - ✅ **Esperado**: **te deja entrar**, porque tus datos siguen bajando y acabas de pedir que
      busque otra vez.
    - ❌ **Fallo**: te dice que los datos son de otra persona. Eso es el callejón sin salida.

### Caso 3 · Arrepentirse pronto sigue funcionando (que no se rompió nada)

16. Repite del 3 al 9, pero en el paso 10 **no esperes**: entra y sal de Restaurar una vez, y a los
    dos o tres minutos toca atrás y entra por la card de tu cuenta.
    - ✅ **Esperado**: **te deja entrar**. Tu descarga sigue viva y el reloj heredado aún tiene margen.

### Si algo sale raro

- **La app se relanza sola** entre el paso 5 y el 6: es el montaje del espejo de iCloud, esperado.
- **Los conteos salen en cero** en el paso 7: el import no arrancó. Comprueba la red y repite desde
  el 3 — no sigas, porque sin import el fix no participa.
- **Sale «Necesitas tener iCloud activado»**: es el paso 2 sin hacer. Ese camino tiene su propio
  arreglo en este PR, pero no es el que se prueba aquí.
