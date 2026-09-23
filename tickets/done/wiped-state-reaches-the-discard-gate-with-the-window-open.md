---
id: wiped-state-reaches-the-discard-gate-with-the-window-open
status: done
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
updated: 2026-09-23
source: "lente 2 de la review adversarial de `restore-session-window-has-no-reachable-ceiling`, 2026-09-21"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - el dueno no ve nada y pide dos iPhone con el mismo Apple ID; ICloudRestoreSignalTests
---

# El estado `.wiped` llega a la puerta de descarte con la ventana de sesión abierta

## El problema, en lenguaje de usuario

No hay síntoma para el dueño legítimo. En un teléfono con los datos de otra persona hay un camino
—estrecho— por el que se llega a la puerta de «Empezar desde cero» **sin que la ventana que abre el
guard de frontera de cuenta se cierre**, y se queda abierta hasta diez minutos mientras la persona
está parada en esa pantalla. Es el mismo agujero que la review del 2026-09-21 cerró para el botón
de al lado, por el único camino que no pasa por su diálogo.

## Medido (2026-09-21)

`WelcomeRestoreView.wipedView` llama a `onStartFresh()` **directo**, sin diálogo de confirmación y
sin tocar la señal:

```swift
primaryTitle: L10n.Welcome.Restore.startFresh,
primaryAction: onStartFresh
```

Los otros seis caminos a «Empezar desde cero» pasan todos por `showStartFreshConfirm`, cuya
confirmación llama a `ICloudRestoreSessionSignal.noteRestoreDiscardRequested` — que apaga la ventana
aparcando su reloj. `.wiped` no.

**Por qué normalmente no muerde, y por qué a veces sí.** `.wiped` sale de un `return` temprano de
`startSearch()`, que corre **antes** de encender la señal: en la primera entrada no hay ventana que
cerrar. Pero la pantalla ofrece «volver a buscar», y `RestoreOfferGate.wasWiped` lee
`PreferenceSyncService.lastWipeTimestamp`, **una preferencia sincronizada**: puede llegar de otro
dispositivo entre la primera búsqueda y el reintento. Recorrido:

1. Entra a Restaurar con iCloud disponible → la señal se enciende, `restoreStartedAt = T0`.
2. Llega el sello del wipe desde el otro dispositivo.
3. Toca «volver a buscar» → `startSearch()` sale por `.wiped` → la señal **no se toca**.
4. «Empezar desde cero» → `onStartFresh()` directo → la puerta.
5. El `.onDisappear` **suelta** la titularidad (`noteRestoreAbandoned`) y **no toca el reloj**: la
   ventana queda HUÉRFANA y VIVA hasta el tope duro de 600 s.

⇒ con la persona declarando que descarta el import, el guard de frontera de cuenta sigue entornado.

## Re-medido el 2026-09-22, antes de tocar nada

El ticket se escribió el 21-sep y desde entonces entró #206, que añadió `noteRestoreUnavailable()`
a los dos `return` tempranos de `startSearch()`. **El agujero seguía abierto**: ese verbo tira el
reloj aparcado y el ancla de la gracia **y nada más** —está escrito en su docblock, «no toca la
ventana ni la titularidad»—, así que `restoreStartedAt` y `currentFlow` llegaban vivos al botón, y
`wipedView` seguía con `primaryAction: onStartFresh`.

## Lo que hay que decidir

- **Si `.wiped` debe confirmar como los otros seis.** Su copy dice que el usuario ya borró sus datos
  aquí, así que el diálogo puede sobrar — pero entonces el apagado tiene que ir en el propio
  `onStartFresh` de ese estado, no en la confirmación.
- **O si el apagado sube un nivel**, a un punto por el que pasen los siete caminos. Ojo: el que se
  elija tiene que seguir dejando que el `cancel` del diálogo vuelva sin haber apagado nada.

## Lo que se hizo (2026-09-22)

**El apagado subió un nivel.** Existe un punto único, `WelcomeRestoreView.discardImportAndStartFresh()`,
que apaga la ventana aparcando su reloj (`noteRestoreDiscardRequested`) y **entonces** llama a
`onStartFresh()`. Los siete caminos pasan por él: los seis que confirman, desde el botón destructivo
del diálogo, y `.wiped`, desde su `primaryAction`. **El `cancel` no pasa**, que es el segundo
criterio.

**`.wiped` NO confirma, y eso se decidió y se deja escrito.** Su búsqueda concluye por acto de la
propia persona —acaba de borrar en este dispositivo— y el escáner
`bothStatesThatClaimDataStillConfirm` ya fija ese criterio por escrito. Añadirle diálogo sería
preguntar por algo que ella misma decidió hace un momento, y copy nuevo que nadie pidió.

**La red es el CUERPO ENTERO del punto único, más un conteo del IDENTIFICADOR.** Las dos mitades
las trajo la review adversarial, en rojo:

- **El cuerpo se fija completo y normalizado**, no con `contains` sueltos. Con cuatro `contains`
  sobrevivían tres mutantes —medidos, no razonados— y los tres reabren el ticket: un
  `noteRestoreAbandoned(flowToken)` antepuesto (deja el dueño en `nil` y el descarte se cae por su
  propio `guard`), un `flowToken = nil` antes del `if let`, y una sentencia cualquiera de más. En los
  tres, el conteo daba 1, el orden era correcto y los cuatro literales estaban. Es la regla de
  `.claude/rules/testing.md` para cuando el source-scan es la única red posible.
- **El conteo va sobre `onStartFresh`, no sobre `onStartFresh()`.** Contando solo la llamada,
  `YalaPrimaryButton(titulo, action: onStartFresh)` —minúscula, que es la firma interna de
  `emptyStateView`—, `primaryAction: self.onStartFresh` y `.onTapGesture(perform: onStartFresh)`
  pasaban los dos escáneres: ahí el callback no se llama, se **entrega**. Sobre el identificador, las
  dos apariciones legales son la declaración y la llamada del punto único, y cualquier tercera cae.

**Y el conteo NO es lo que caza este ticket, aunque el primer docblock lo decía**: sobre el árbol de
antes del arreglo el conteo también daba 2. Lo que cae en el árbol viejo son los dos literales y el
`#require` del propio punto, que no existía. El conteo cubre el octavo camino de mañana.

**El ORDEN se fija dentro del cuerpo, y su daño está INFERIDO.** Dos lentes lo midieron por separado:
hoy invertirlo también funcionaría, porque los dos consumidores navegan mutando estado y el
`.onDisappear` corre en el ciclo siguiente —y aunque corriera, llegaría con el dueño ya en `nil`—. Se
fija igual porque depende de cómo navegue un consumidor futuro, no de este código.

## Criterios de aceptación

- [x] Ningún camino a la puerta de descarte deja la ventana de sesión viva.
- [x] El `cancel` del diálogo sigue sin tocarla.
- [x] Un test que recorra el camino de `.wiped`: hay dos capas, y ninguna sola basta.
      `everyPathToTheDiscardGateClosesTheSessionWindow` (source-scan) es lo único que ancla la
      VISTA —los dos lados son closures de SwiftUI que ningún unit test invoca— y
      `theWipedRetryReachesTheDiscardGateWithTheWindowClosed` (comportamiento) mide lo que ningún
      escáner puede: la INTERACCIÓN de `noteRestoreUnavailable` con `noteRestoreDiscardRequested`.

## La review adversarial cazó ocho defectos MÍOS

Tres lentes independientes. Todo lo de abajo salió de ellas, y **cuatro mutantes solo mueren por lo
que pidieron**:

1. **Tres mutantes vivos** en el cuerpo del punto único, por fijarlo con `contains` en vez de entero.
2. **El conteo miraba `onStartFresh()`**, así que tres formas de ENTREGAR el callback pasaban.
3. **Mi docblock decía «la red es el CONTEO, no el literal»**, y para este ticket es al revés: el
   conteo también daba 2 en el árbol con el bug dentro.
4. **Mi test de comportamiento no mata ningún mutante que la suite no matara ya** —los pasos 1, 2 y 4
   son `discardingTheImportClosesTheWindow` y el 3 es `droppingTheParkedClockLeavesALiveWindowAlone`—
   y su docblock afirmaba lo contrario. Se queda, porque es el recorrido del ticket de punta a punta y
   el criterio 3 lo pide; lo que cambia es que ahora dice la verdad sobre qué añade.
5. **El escáner de call-sites del descarte cuenta FICHEROS**, así que un segundo `noteRestoreDiscard
   Requested(` dentro de esta misma vista —la forma exacta del defecto que se cerró— pasaba en verde.
   Ahora cuenta ocurrencias dentro de la pantalla.
6. **El docblock del orden presentaba como medida una causalidad inferida.**
7. **El aparcado que escribe el camino `.wiped` es INERTE**, y el docblock lo justificaba con la
   herencia del reloj, que por ese camino no ocurre: la vuelta sale por el mismo `return` y
   `noteRestoreUnavailable()` lo tira.
8. **Ocho docblocks decían que el verbo lo llama «la confirmación»**, y `.wiped` no confirma.

Y un residual con ticket propio: **`discard-gate-cannot-close-an-orphan-session-window`**. El punto
único solo apaga si ESTA instancia de la vista tiene el token y sigue siendo el dueño; quien sale de
Restaurar y vuelve a entrar llega con `flowToken == nil` y el descarte es un no-op sobre una ventana
huérfana todavía viva. No es regresión —es la exposición que ya acepta `noteRestoreAbandoned`— y
cerrarlo es una decisión: apagar una ventana que no es de este intento es justo lo que ese verbo
existe para no hacer.

## Mutantes verificados (compilados y corridos, 67 casos en 3 suites)

| # | mutante | fallos |
|---|---|---|
| 1 | `wipedView` vuelve a `primaryAction: onStartFresh` (el bug original) | 4 |
| 2 | `wipedView` con `primaryAction: { onStartFresh() }` (llama directo sin apagar) | 4 |
| 3 | el punto único llama al callback ANTES de apagar | 3 |
| 4 | el punto único apaga con `noteRestoreFinished` (olvida el reloj) | 7 |
| 5 | el punto único sin el `if let flowToken` | 3 |
| 6 | `noteRestoreUnavailable` se lleva también la titularidad | 8 |
| 7 | la confirmación del diálogo se salta el punto único | 7 |
| 8 | un `noteRestoreAbandoned(flowToken)` antepuesto dentro del punto único | 3 |
| 9 | `flowToken = nil` antes del `if let`, así que ni entra | 3 |
| 10 | un octavo camino ENTREGA el callback (`secondaryAction: onStartFresh`) | 3 |
| 11 | un segundo call-site del descarte dentro de la misma pantalla | 5 |

Los cuatro últimos son los que la review encontró VIVOS; los siete primeros se re-corrieron contra la
red endurecida. El (6) es el único que cae por un test de comportamiento y no por el escáner.

## Relación con otros tickets

- `discard-gate-cannot-close-an-orphan-session-window` — el residual que deja: el mismo daño por el
  camino del remontaje, donde el punto único no puede apagar.

- `restore-session-window-has-no-reachable-ceiling` — de donde sale; cerró el mismo agujero para los
  seis caminos que sí confirman.


---

## QA en el teléfono (Jürgen)

**Por qué el simulador no llega.** El recorrido necesita dos cosas que ahí no existen: un import de
CloudKit vivo, y que el **sello del wipe llegue de otro dispositivo** mientras la pantalla de
Restaurar está abierta. Ese sello viaja por el iCloud-KV del Apple ID
(`PreferenceSyncService.lastWipeTimestamp`), así que hacen falta **dos teléfonos con el mismo Apple
ID**: el A restaurando y el B borrando.

**Y no hay síntoma visible para el dueño legítimo.** Lo que se comprueba es lo contrario: que el
guard de frontera de cuenta **vuelva a bloquear** en un teléfono con el corpus de otra persona.

### Montaje

1. En el **iPhone A** (el de pruebas), instala el build de TestFlight que salga de este merge.
2. Ajustes de iOS → tu nombre → **iCloud** → la cuenta con el histórico grande activa y **iCloud
   Drive encendido** (apagado, la app cae en `.iCloudDisabled`, que es otro camino).
3. Borra Yala del A y vuelve a instalarla: el claim local tiene que desaparecer, que es justo lo que
   hace falta que falte.
4. En el **iPhone B**, con el mismo Apple ID, ten Yala instalada y con datos.
5. Abre la del A y déjala en el Hero.

### Caso 1 · El reintento que cae en `.wiped` ya no deja la ventana abierta

6. En el A: Hero → «Ya tengo una cuenta» → «Restaurar desde iCloud». La app se relanza sola: normal.
7. Ábrela otra vez. Verás «Buscando tus datos…» con los conteos subiendo. **Apunta la hora exacta.**
8. Espera a que salga **«Seguimos trayendo tus datos»** (o la pantalla con los conteos) **con el
   import todavía en marcha**: los números tienen que seguir moviéndose.
9. **Sin tocar el A**, ve al **iPhone B** → Perfil → Datos → **«Borrar todos mis datos»**, y
   confírmalo. Espera un minuto a que el sello viaje.
10. Vuelve al A y toca el botón de **recargar** (la flecha circular, arriba a la derecha).
    - La pantalla cambia a **«Borraste tus datos»** (icono de papelera tachada). Ése es `.wiped`, y
      es el estado del ticket. Si sigue enseñando los conteos, el sello aún no ha llegado: espera y
      repite el toque.
11. Toca **«Empezar desde cero»**. Llegas a la puerta que enseña las cifras de iCloud.
12. **No borres nada.** Toca atrás (o «Traer mis datos»), y luego el chevron hasta salir del Welcome.
13. Entra por la card de tu cuenta, **antes de que pasen diez minutos desde el paso 7**.
    - ✅ **Esperado**: la app te dice que **los datos son de otra persona** y no te deja firmar sin
      aviso. El paso 11 cerró la ventana.
    - ❌ **Fallo**: te deja entrar sin avisar. La ventana llegó viva a la puerta — el ticket entero.

### Caso 2 · El primer `.wiped` sigue siendo un no-op limpio (que no se rompió nada)

14. Repite del 3 al 5, con el borrado del B **ya hecho** (o sea, `.wiped` desde la primera búsqueda).
15. Hero → «Ya tengo una cuenta» → «Restaurar desde iCloud» → tras el relanzamiento, la pantalla
    sale directamente en **«Borraste tus datos»**.
16. Toca **«Empezar desde cero»** → llegas a la puerta → sal de ella y haz el onboarding normal.
    - ✅ **Esperado**: todo funciona como siempre. Aquí no había ventana que cerrar y el apagado es
      un no-op.

### Caso 3 · El `cancel` del diálogo sigue sin tocar nada

17. Repite del 3 al 8 (sin borrar en el B: la pantalla se queda en «Seguimos trayendo tus datos»).
18. Toca **«Empezar desde cero»** → en el diálogo, **«Cancelar»**.
19. Sal de Restaurar y entra por la card de tu cuenta, con el import todavía bajando.
    - ✅ **Esperado**: **te deja entrar**. Arrepentirse del diálogo no apaga la ventana de nadie.

### Si algo sale raro

- **Los conteos salen en cero** en el paso 8: el import no arrancó. Comprueba la red y repite desde
  el 3 — sin import el fix no participa.
- **La pantalla no cambia a «Borraste tus datos»** en el paso 10: el iCloud-KV tarda. Deja el A en
  primer plano un par de minutos y vuelve a tocar recargar.
- **Sale «Necesitas tener iCloud activado»**: es el paso 2 sin hacer, y es otro camino (ése sí
  confirma con diálogo).

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). El dueño no ve nada distinto y pide dos iPhone con el mismo Apple ID. Lo cubre `ICloudRestoreSignalTests`.
