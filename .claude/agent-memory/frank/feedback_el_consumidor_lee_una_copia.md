---
name: el-consumidor-lee-una-copia
description: Actualicé el `@State` fuente y el lector siguió con el valor viejo — lo recibe por VALOR, no por binding, y sin suspensión de por medio nadie re-evalúa el body. Mi source-scan lo daba por cerrado.
metadata:
  type: feedback
---

**Antes de «arreglar» algo escribiendo en una fuente de estado, comprueba cómo la RECIBE quien la lee.**
Un `let` capturado en el `body` de SwiftUI no se entera de que la fuente cambió.

**Why:** el 2026-09-14, en `restore-start-fresh-keeps-the-imported-corpus`, cerré un alert espurio
bajando dos `@State` de `ContentView` tras el borrado. El que levanta ese alert vive en un
`ViewModifier` que recibe la señal como **`let hasExistingData: Bool`** —sus catorce vecinos sí son
`@Binding`, ése no— y entre mi escritura y su lectura **no hay un solo punto de suspensión**, así que
SwiftUI no re-evalúa el `body` y el modifier sigue con el valor que capturó. El arreglo no arreglaba
nada, y el defecto solo se veía en el camino nuevo: con el mount neutro la salida relanza y el proceso
muere, así que nunca se notó. La lente de presentaciones lo cazó leyendo la declaración; yo lo había
razonado desde el lado del escritor.

**Y la segunda mitad:** mi source-scan lo daba por cerrado. Comprobaba que las líneas
`hasExistingData = false` y su orden estaban — no que el valor llegara a nadie. Un scan puede afirmar
que escribí; nunca que alguien lo lee.

**How to apply:**

- **Escribir en el estado y leerlo son dos sitios, y el cable entre ellos tiene tipo.** Antes de
  apoyarte en una escritura, `grep` de la **declaración** en el consumidor: `@Binding` lee vivo, `let`
  es una foto del último render. Si la cadena no tiene `await` en medio, la foto no se refresca.
- **El repo suele tener ya la respuesta escrita.** Aquí el propio fichero llevaba un `hasLocalDataNow`
  —el fetch vivo— con un docblock que decía, textual, «no el snapshot `hasExistingData`». La corrección
  no era inventar un mecanismo: era usar el que ya existía por este mismo motivo.
- **El fallo se ve en el camino que no relanza.** Un estado stale se disimula cuando el proceso muere
  entre la escritura y la lectura. Si tu cambio quita un relanzamiento —o abre un camino que no lo
  tiene—, todo lo que se apoyaba en «el arranque siguiente lo recalcula» pasa a ser tuyo.
- **Y un scan no cierra esto.** El pin correcto es sobre el PREDICADO del lector (que lea la señal
  viva), no sobre las asignaciones del escritor.

**Y la cara contraria, medida el 2026-09-15: no todo lo que alimenta una decisión va al `@State`.** Para el
aviso de la pestaña Grupos metí sus cuatro entradas en un `@State` que se recalculaba en cinco momentos, y con
eso congelé tres que SÍ eran reactivas: iniciar sesión desde el CTA de la lista no sacaba el aviso —ese sheet
se cierra en sitio, sin `onAppear`— y una sesión que el SDK borra en caliente lo dejaba puesto, culpando al
attest de una sesión caducada. **Al `@State` va solo lo que no se puede leer reactivamente** —aquí,
`UserDefaults` más el reloj—; lo demás se lee vivo en el body, como ya hacían sus vecinas de la misma vista.
Un `@State` de más no da un valor viejo por un cable mal tipado: lo da porque nadie lo actualizó.

Relacionado: [[mi-arreglo-rompe-la-premisa-de-otro-guard]] (la premisa que se rompe suele estar en un
docblock ajeno) · [[el-source-scan-de-dos-literales-no-es-una-red]] · [[mi-fix-hereda-la-forma-del-bug]].
