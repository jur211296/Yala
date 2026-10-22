---
id: device-qa-activation-restore-start-fresh
status: done
priority: high
area: "onboarding, modo-nube, grupos"
created: 2026-09-14
source: "device-QA del PR de `activation-restore-start-fresh-keeps-the-imported-rows` (2026-09-14)"
updated: 2026-09-23
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - variante de Empezar desde cero que se ve en restore-start-fresh-keeps-the-imported-corpus; el recorrido que borra pide datos desechables y otro aparato
---

# Device-QA · «Activar Yala completo → Restaurar → Empezar desde cero» ya borra de verdad

## Qué se arregló, en lenguaje de usuario

Usaba Yala solo para grupos y decidí activar Yala completo. Elegí «mi iCloud privado», la app encontró
mis datos de antes y toqué «Traer mis datos». Los vi, cambié de opinión y toqué «Empezar desde cero».
**Hasta hoy no se borraba nada**: terminaba el onboarding y mis datos viejos seguían ahí — y si tenía
Yala en otro teléfono, allí también, porque volvían a subir desde éste.

Ahora ese botón lleva a la misma pantalla que ya usa el Welcome: la app **le pregunta a iCloud** qué hay,
me enseña las cifras y me deja elegir entre traérmelo, borrarlo (con una segunda confirmación) o volver.

**Y mis grupos no se tocan**, que es para lo que estaba activando. Mi nombre y mi divisa tampoco: el
onboarding de después no me los vuelve a pedir.

## Por qué NO es simulable

`ICloudPersonalCorpusProbe` —la sonda que pregunta a CloudKit— **no tiene ni un seam de `uitest`**
(medido: cero ocurrencias de `uitest` en el fichero), así que el estado «Encontramos tus datos» de la
puerta no existe en simulador. Y como a la pantalla de Restaurar de la activación **solo se llega desde
ese estado** (`onRestore` de la puerta → relanzamiento → `.restore`), el recorrido entero queda fuera.

## Antes de empezar

- **Build de TestFlight**, no de Xcode: el contenedor que se va a borrar es el de producción.
- **Un iPhone con una sesión SOLO-GRUPOS** (al menos un grupo con gastos) y, en el **mismo Apple ID**, un
  iCloud privado **con meses de datos personales** de antes.
- Anotar antes de tocar nada: cuántos movimientos y cuántas cuentas hay en iCloud, el mes del más
  antiguo, **y el estado de los grupos** (nombres, gastos, saldos, la cuenta de liquidación de cada uno).
- El recorrido 2 borra de verdad. Si el Apple ID no es desechable, hacer antes el 1 y el 4.

## Los recorridos

### 1 · Llegar a la pantalla, y que el botón lleve a la puerta

1. Desde la sesión solo-grupos: **«Activar Yala completo»** → **«Mi iCloud privado»**.
2. La app pide reabrirse (relanzamiento). Reabrir.
3. Sale «Encontramos tus datos en iCloud» con sus cifras → **«Traer mis datos»** → reabrir si lo pide →
   sale la pantalla de **Restaurar** con el resumen.
4. **«Empezar desde cero»** → confirmar el diálogo.

**PASS** exige las tres:
- Sale **la puerta** («Revisando qué hay en tu iCloud…» y después el aviso con cifras), **no el
  onboarding**. Que salga el onboarding directo es el bug original.
- El aviso ofrece **tres** salidas: «Traer mis datos», «Empezar de cero» y el chevron de volver.
- El chevron **devuelve a la pantalla de Restaurar**, no cierra la activación. *(Si cierra la activación
  entera, el `onBack` volvió a `backFromRestore()`.)*

### 2 · Borrar → onboarding limpio, iCloud a cero, y **los grupos intactos**

Desde el aviso: «Empezar de cero» → «¿Seguro? Esto es definitivo.» → «Borrar todos los datos».

- Sale «Borrando lo que había en iCloud…» y el chevron desaparece mientras dura.
- Al terminar, arranca el **onboarding de la activación**, no el Welcome. Esto es lo que la restricción
  del paso 8 protege: si acabas en el Welcome, el borrado se llevó `hasCompletedOnboarding`.
- **El onboarding NO pide el nombre** (llega prefijado) y la divisa sigue siendo la del grupo. Es
  deliberado (decisión 2.3A): son tuyos, no del corpus que descartaste.
- **NO sale ningún alert extra** pidiendo borrar otra vez, ni el aviso de «te borraron los datos en otro
  dispositivo». Si sale ese segundo, la gracia del wipe remoto no se canceló a tiempo — y ese alert
  **desmonta la sheet de la activación**, así que se ve como una pantalla que se cierra sola.

Al terminar el onboarding:
- **Los grupos siguen enteros**: los mismos, con sus gastos y sus saldos. *(La cuenta de liquidación de
  cada grupo sí puede haberse perdido: el borrado se lleva todas las cuentas. Eso es lo mismo que hace
  hoy «Vaciar mis datos» de Ajustes, y no es un fallo de este PR — anótalo si pasa.)*
- **Hay categorías.** Abre «Nueva transacción» y despliega el selector: tiene que haber la lista
  completa por defecto, **y «Ajuste de saldo»**. Si está vacío, el centinela del seed no se reabrió, y
  sin «Ajuste de saldo» el saldo inicial de la cuenta nueva falla en silencio. **Es el fallo más
  probable de todo este PR: míralo siempre.**
- **Tu foto de perfil sigue puesta** (Ajustes → Perfil). Va con el nombre, no con las filas.
- **Los gastos de tus grupos vuelven a verse en el Panel y en Registros AL REABRIR LA APP**, no antes. El
  borrado se lleva su copia personal —son `TransactionItem` como cualquier otra— y quien la repone es la
  convergencia del bridge, que este PR deja PEDIDA y ejecuta el arranque siguiente. Cierra la app,
  reábrela y compruébalo: si a la segunda apertura siguen sin aparecer, la intención durable no se está
  recogiendo. *(Lo que NO vuelve es la pregunta «¿traemos tus gastos de grupo?»: tiene ticket propio,
  `activation-discard-loses-the-group-history-question`.)*

**La verificación que de verdad cierra el criterio del ticket no está en esta pantalla**: instalar Yala
en OTRO dispositivo con el mismo Apple ID, «Restaurar desde iCloud», y comprobar que **no encuentra
nada**. Y en éste: dejar la app abierta un rato con red y comprobar que **no reaparece ningún dato
previo**. Ese es el bug — el corpus se re-exportaba a la zona recién creada.

**Y hazlo con un corpus GRANDE, que es donde la review dejó una duda que el simulador no puede resolver.**
Este es el único borrado que corre con el espejo de CloudKit adjunto *por definición* (los cierres de
sesión pagan un relanzamiento entero para no hacerlo). La zona se borra ANTES que las filas, así que los
deletes que el espejo exporte van a una zona ya vacía — pero `wipeAllUserData` recorre ~14 guardados por
lotes, y lo que haga `NSPersistentCloudKitContainer` con una zona recién borrada durante esos segundos no
está escrito en ninguna parte. **FAIL si**, tras esperar a que sincronice, la zona vuelve a tener filas.

### 3 · «Traer mis datos» desde la puerta → vuelve a Restaurar, y lo restaurado SE QUEDA

Repetir el recorrido 1 y, en el aviso de la puerta, tocar **«Traer mis datos»**.

- Vuelve a la pantalla de **Restaurar**. Continuar y terminar la activación.
- Los datos vuelven, completos, **y los grupos siguen**.
- **Y al día siguiente, o tras cerrar y reabrir la app un par de veces, siguen ahí.** Ésta es la prueba
  del arm huérfano: sin retirarlo al salir por ahí, el arranque siguiente los borraba enteros y sin
  preguntar. *(El ticket hermano lo midió en el camino del Welcome; aquí se retira en el `onRestore`.)*

### 4 · Volver atrás sin borrar nada

Repetir el 1 y salir por el **chevron**. Después cerrar la activación (la X) y reabrir la app.

- La activación se retoma donde estaba (queda pendiente a propósito: `cancelEffect == .keepPending`).
- **No se ha borrado nada**: ni en iCloud, ni los grupos, ni el nombre.

### 5 · Matar la app a mitad del borrado

En el recorrido 2, entre «Borrar todos los datos» y el final, forzar el cierre.

Al reabrir, **la puerta vuelve a MEDIR**: si la zona ya se borró, sigue al onboarding limpio; si no, el
aviso otra vez con las cifras. **FAIL si** arranca borrando sin decir nada, si se lleva los grupos, o si
el onboarding se monta sobre datos que siguen en iCloud.

## Qué NO cubre este device-QA

- El camino del Welcome («Ya tengo una cuenta → Restaurar → Empezar desde cero»): tiene su propia ficha
  en `tickets/qa/restore-start-fresh-keeps-the-imported-corpus.md` y **no cambia en este PR**.
- La puerta privada de la activación **antes** del relanzamiento: sigue borrando solo la zona, y eso
  tampoco cambia.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). La pantalla que revisa tu iCloud antes de empezar de cero se ve en `restore-start-fresh-keeps-the-imported-corpus`, que sigue en `qa`. El recorrido que borra de verdad pide datos desechables y un segundo aparato.
