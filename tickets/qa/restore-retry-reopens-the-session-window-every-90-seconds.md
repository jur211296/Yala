---
id: restore-retry-reopens-the-session-window-every-90-seconds
status: qa
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
source: "lente 2 de la review adversarial de `restore-session-window-has-no-reachable-ceiling`, 2026-09-21"
---

# «Volver a buscar» reabre la ventana de sesión cada 90 s, y es más barato que la puerta

## El problema, en lenguaje de usuario

No hay síntoma para el dueño legítimo. Quien tiene en la mano un teléfono con los datos de otra
persona puede mantener abierta la ventana que permite entrar en la cuenta sin aviso **con UN toque
cada minuto y medio**, sin pasar por ninguna puerta y sin que haga falta que baje nada.

## Medido (2026-09-21)

Es el camino más barato de los que quedan, y lo destapó la review del ticket del techo mientras medía
otro. La población es la que **no tiene ningún `.importEvent` en el proceso**: el teléfono cuyo corpus
ajeno ya se importó en un arranque anterior.

1. Entrar a Restaurar → `restoreStartedAt = T1`. `isRestoringNow` da `true` durante los **60 s de
   gracia** de `ICloudRestoreInProgressLogic` (sin actividad observada, la ventana vive hasta ahí).
2. La espera agota su tope de 90 s sin un solo evento.
3. `closesTheSessionWindow(settled: false, hasObservedImportActivity: false)` da `true` ⇒
   `noteRestoreFinished` apaga la ventana y suelta el dueño.
4. Un toque en «Reintentar» del estado terminal → `restoreStartedAt = T2 ≈ T1 + 91` ⇒ **otros 60 s de
   gracia**.

⇒ guard abierto ~60 s de cada ~91, indefinidamente, **un toque por vuelta**. Ni el aparcado de la
puerta de descarte interviene (el apagado del paso 3 lo consume) ni hace falta descarga viva.

**Esto no es una regresión: es el precio declarado de la gracia.** El apagado del paso 3 existe a
propósito —es la PRECISIÓN que cierra la ventana del usuario realmente nuevo antes de los 60 s— y el
estreno del paso 4 es lo único que hace útil la señal. Lo que nadie había medido es lo que cuesta
ponerlos en ciclo.

## Lo que haría falta

Las dos piezas están documentadas y ninguna es obviamente la que sobra:

- **La gracia de 60 s** existe porque al principio `hasObservedImportActivity` también es `false`:
  apagar ahí le devolvería el bloqueo al dueño legítimo que sí está restaurando y solo espera al
  primer evento. Acortarla muerde a esa población.
- **El estreno tras un final** es la puerta grande de la señal y tiene que seguir abierta.

Un camino posible, sin diseñar: que un estreno que sigue a un `noteRestoreFinished` **sin un solo
import observado** herede la gracia en vez de estrenarla —o sea, que la gracia se cuente una vez por
proceso y no una por entrada—. Hay que medir antes a quién deja fuera: el que enciende iCloud y
reintenta con razón entra por ahí.

## Criterios de aceptación

- [ ] El ciclo reintentar-reintentar deja de mantener el guard abierto de forma continua, **o** está
      escrito por qué se acepta.
- [ ] El dueño legítimo que reintenta con razón sigue teniendo su ventana completa.
- [ ] Un test que recorra el ciclo con el reloj, midiendo el veredicto del guard y no el campo.

## Relación con otros tickets

- `restore-session-window-has-no-reachable-ceiling` — de donde sale; cerró el ciclo de la puerta de
  descarte, que cuesta 3 toques y 600 s de espera. Éste cuesta 1 toque y 91 s.
- `leaving-and-reentering-restore-renews-the-hard-cap` — cerró el ciclo de salir-y-volver.

---

## Paso 0 · La decisión, tomada el 2026-09-22 (Frank, modo nocturno)

**La gracia de 60 s se cuenta UNA VEZ POR PROCESO, no una por entrada.** El estreno de
`noteRestoreStarted` sigue dando reloj nuevo —tope duro completo de 600 s— pero el término de la
gracia deja de medirse desde ese reloj: lo mide desde un **ancla de proceso** que se pone en el
primer estreno y que `noteRestoreFinished` **no borra**. Así el ciclo reintentar-reintentar deja de
comprar 60 s de ventana por cada 91.

**Por qué el ancla es una FECHA y no un `Bool` «ya se usó»**: la gracia real consumida no es siempre
60 s. Una búsqueda que se rinde a los 3 s sin un solo evento apaga la ventana en el acto
(`closesTheSessionWindow(settled: false, hasObservedImportActivity: false)` no espera a la gracia),
y con un `Bool` su reintento se quedaría sin los 57 s que nadie gastó. Con la fecha, la gracia es un
presupuesto de 60 s repartido entre las entradas que haga falta.

**Por qué el ancla NO es el reloj entero** (la alternativa barata: heredar `restoreStartedAt` como
hace el aparcado del descarte): heredar el reloj recorta también el tope duro, y el criterio (b) del
ticket dice que el dueño legítimo que reintenta con razón conserva su **ventana completa**. Con el
ancla separada, lo único que no se renueva es la gracia; los 600 s son enteros.

### A quién deja fuera, medido

La gracia solo decide mientras `hasObservedImportActivity` sea `false`, y ese latch es **monótono en
el proceso** (`iCloudSyncService:385`; solo lo apaga `_testReset`). En cuanto llega UN `.importEvent`
—con error o sin él— el término (3) de `isRestoringNow` deja de cerrar y la ventana **se reabre
sola**, porque el getter se recalcula vivo. ⇒ el alcance del recorte es exactamente «quien no ha
visto ni un import en todo el proceso», que es la población del ticket.

Los tres recorridos del dueño legítimo que reintenta con razón:

| Recorrido | Qué le pasa |
|---|---|
| Entró sin iCloud (`.iCloudDisabled`), lo enciende y reintenta | **Gracia completa.** Ese camino no estrena: pasa por `noteRestoreUnavailable()`, que ahora tira también el ancla — misma razón por la que ya tiraba el aparcado: lo de antes no describe nada de la descarga que viene |
| Entró con iCloud, el primer intento no vio ningún evento, reintenta y ahora SÍ baja | Sin gracia hasta su primer `.importEvent`; **con él la ventana se reabre** dentro de su tope duro completo. Es el residual, y tiene test |
| Reintenta con la descarga viva | La gracia no decide nada: el latch está encendido |
| **No reintenta nada: solo necesita la ventana para firmar** | Esta fila la añadió la review, y es la que de verdad se paga. Su único intento de 60 s es el primero del proceso; el remedio siguiente es matar la app, que es el baseline declarado de la señal. **Se acepta:** esa población y el teléfono con el corpus ajeno son literalmente la misma —el claim murió con la reinstalación, que es la mitad del escenario— y la señal no tiene ningún término que las separe. El copy que ve al bloquearse (`welcome.cloud.blockedRestoreHint`) sigue siendo cierto: habla de «si acabas de pedir una restauración», y quien no ha visto un solo import no tiene ninguna en curso |

**El `min(ancla, reloj)` del término no salía del árbol de decisiones y se añadió al implementar**: es
defensa fail-closed —la gracia se agota antes, nunca después— para el ancla que quedara por delante del
reloj si el del sistema corre hacia atrás. Tiene test propio. Conviene saber que el tope duro tiene el
sesgo CONTRARIO ante la misma anomalía (un `elapsed` negativo no caduca), y que eso ya era así.

**Lo que el abusador conserva** es el baseline declarado de esta señal: matar la app estrena todo.
Apagar y encender iCloud en Ajustes del sistema también reinicia el ancla, y es una salida más cara
que aquélla — no añade exposición sobre el baseline.

---

## Lo que cazó la review adversarial (2026-09-22)

Tres lentes independientes. **Todo lo de abajo son defectos MÍOS**, no del código que había:

1. **Una aserción que no podía fallar.** El escáner de «el ancla no tiene valor por defecto» miraba el
   fichero de la señal, y el parámetro vive en la lógica pura: el literal no aparecía ahí ni con el
   mutante puesto. Copié el molde de su hermano —que sí funciona, porque su función vive en ese
   fichero— sin comprobar dónde vivía la mía. Arreglado con la constante del fichero correcto y un
   control positivo delante.
2. **Mi test del recorrido «enciendo iCloud y reintento» medía el caso fácil.** Apagaba el reloj antes
   (`noteRestoreFinished`), y ahí los dos operandos del `??` coinciden. El recorrido REAL —irse de
   Restaurar sin que nadie apague, que deja la ventana viva— no lo tocaba nadie, y por ahí sobrevivía
   el mutante que re-deriva el ancla de `now`. Test nuevo.
3. **La puerta de descarte solo estaba medida a los 40 s**, donde el aparcado todavía se hereda y el
   ancla se re-deriva de él: un `graceStartedAt = nil` en ese verbo era indistinguible. A los 700 s sí
   se ve. Test nuevo.
4. **La frontera exacta de la gracia no estaba**: `>=` por `>` no ponía nada rojo. 59/60 desde el ancla.
5. **Un dato falso en un docblock mío**: «seis vueltas, que son más de los 600 s del tope duro». Son
   546 s. Ahora son siete (637 s) y la frase es cierta — que además es lo que hace que el test demuestre
   que el ciclo sobrevive al tope duro.
6. **Mi test del criterio 2 era insensible al diff**: todas sus aserciones pasaban con el fix revertido.
   Le falta(ba) la mitad que discrimina, el residual con `conImports: false`.
7. **Cuatro docblocks que pasaron a mentir** y uno malformado: la cabecera decía «cuatro verbos» y son
   cinco —falta justo `noteRestoreUnavailable`, el único que borra el ancla—; «`isRestoringNow` mide
   TODOS sus plazos desde este instante, gracia incluida» dejó de ser cierto; y el `- Parameters:` de
   `isRestoringNow` abría con un parámetro inexistente y metía el `- Returns:` en medio, así que mi
   párrafo nuevo no se renderizaba como parámetro.
8. **El rescate de #205 queda colgado de un invariante implícito**: solo es alcanzable con el latch
   encendido, y eso lo decide `closesTheSessionWindow`, un verbo que cambió dos veces en 24 h. No se
   toca el código —mover el ancla ahí sería una línea sin test posible— pero queda anclado por escrito
   con un test que cruza rescate × gracia agotada en las dos direcciones.

**Refutado:** la lente 3 avisó de que el copy del bloqueo (`welcome.cloud.blockedRestoreHint`) prometía
una salida que el fix quita. Medido: dice «**si acabas de pedir una restauración** desde iCloud, espera
a que termine y vuelve a entrar», y quien no ha visto un solo import no tiene ninguna en curso, así que
su premisa no describe a esta población. El copy no caduca.

## Mutantes compilados (12/12 muertos, 2026-09-22)

Cada uno aplicado al árbol, compilado y corrido contra las cinco suites de restore:

| Mutante | Lo mata |
|---|---|
| `graceStartedAt ?? restoreStartedAt` → `?? now` | la ventana viva con el ancla tirada (test de la review) |
| → `= restoreStartedAt` | el ciclo de siete vueltas (18 casos) |
| borrar la línea del ancla | el ciclo (27 casos) |
| quitar el `min(...)` | el ancla posterior al reloj |
| `min(...)` → `restoreStartedAt` (revertir el fix) | la tabla de la gracia de proceso (22 casos) |
| `graceStartedAt = nil` en `noteRestoreFinished` | el ciclo + el source-scan (16 casos) |
| quitar el `nil` de `noteRestoreUnavailable` | el recorrido de encender iCloud |
| quitar el `nil` de `_testReset` | la contaminación entre tests |
| getter de producción → `graceStartedAt: nil` | el source-scan del cableado |
| `>=` → `>` en la gracia | la frontera 59/60 desde el ancla (aserción de la review) |
| `graceStartedAt = nil` en `noteRestoreDiscardRequested` | la puerta a los 700 s (test de la review) |
| default `graceStartedAt: Date? = nil` en la lógica pura | el source-scan, ya con el fichero correcto |

**Cuatro de los doce solo mueren por tests que escribió la review** (filas 1, 10, 11 y 12). Antes de
ella sobrevivían los cuatro.

## QA en el teléfono (Jürgen)

**Por qué no vale el simulador.** El ciclo son minutos de reloj real por vuelta, y la población exige un
teléfono en el que CloudKit **no baje nada**: si el espejo emite un solo `.importEvent`, el término de
la gracia deja de decidir y el fix no participa.

### Montaje

1. En el **iPhone de pruebas**, instala el build de TestFlight que salga de este merge.
2. Ajustes de iOS → tu nombre → **iCloud** → la cuenta con el histórico y **iCloud Drive** encendido.
3. Borra Yala y vuelve a instalarla: el claim local tiene que desaparecer, que es la mitad del escenario.
4. Ábrela, Hero → «Ya tengo una cuenta» → «Restaurar desde iCloud» (la app se relanza sola, es normal).
5. **Espera a que la restauración TERMINE** — los conteos dejan de moverse y sale la pantalla final.
6. **Mata la app** deslizando hacia arriba en el selector de apps. Esto es lo que monta el escenario: en
   el proceso siguiente ya no baja nada, así que no habrá ningún `.importEvent`.

### Caso 1 · El primer minuto sigue funcionando (control positivo: el fix no se comió la gracia)

7. Abre Yala. Hero → «Ya tengo una cuenta» → «Restaurar desde iCloud». **Apunta la hora exacta.**
8. **Dentro del primer minuto**, toca atrás y entra por la card de tu cuenta.
   - ✅ **Esperado**: te deja seguir. Es el margen que cubre a quien acaba de pedir restaurar.
   - ❌ **Fallo**: dice que los datos son de otra persona. El fix se comió la gracia inicial.

### Caso 2 · El ciclo de «volver a buscar» ya no reabre nada (lo que cierra el ticket)

9. Mata la app y vuelve a abrirla (para empezar un proceso limpio). Hero → «Ya tengo una cuenta» →
   «Restaurar desde iCloud». **Apunta la hora.**
10. Espera **sin tocar nada** a que la búsqueda se rinda: sale una pantalla terminal con un botón de
    **«Volver a buscar»** (tarda minuto y medio).
11. Toca **«Volver a buscar»**. Vuelve a esperar a que se rinda. Hazlo **tres veces**.
12. Justo después del tercer toque —sin esperar—, toca atrás y entra por la card de tu cuenta.
    - ✅ **Esperado**: te dice que **los datos son de otra persona** y no te deja firmar sin aviso.
    - ❌ **Fallo**: te deja seguir. Cada toque sigue comprando un minuto de permiso.

### Caso 3 · Encender iCloud y reintentar sí da margen nuevo

13. Mata la app. Ajustes de iOS → tu nombre → iCloud → **apaga iCloud Drive**.
14. Abre Yala. Hero → «Ya tengo una cuenta» → «Restaurar desde iCloud».
    - Sale «Necesitas tener iCloud activado» (o equivalente). Es el camino correcto para este caso.
15. Sin cerrar Yala, ve a Ajustes de iOS y **enciende iCloud Drive** otra vez. Vuelve a Yala y toca
    **«Volver a buscar»**. **Apunta la hora.**
16. **Dentro del primer minuto**, toca atrás y entra por la card de tu cuenta.
    - ✅ **Esperado**: te deja seguir. Su búsqueda arrancó de verdad ahora, y el margen se le estrena.
    - ❌ **Fallo**: dice que los datos son de otra persona. El margen no se reinició al recuperar iCloud.

### Si algo sale raro

- **En el paso 10 no sale ningún botón de «Volver a buscar»**: la búsqueda encontró datos y está
  bajando algo. Entonces este caso no aplica — vuelve al paso 5 y deja que termine del todo.
- **En el paso 12 te deja entrar y los conteos se estaban moviendo**: hubo un import de verdad y el
  término de la gracia no participa. No es un fallo; repite desde el 9 con el teléfono en reposo.
- **Si en cualquier punto matas la app, todo se estrena**: es el baseline declarado de esta señal, no
  un fallo. Los tres casos empiezan desde su propio arranque a propósito.
