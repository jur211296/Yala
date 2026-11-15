Yala
# Fallos altos: hoja de éxito en blanco al deslizar, patas de grupo reimportadas como transferencias y adopt sin salida
---
card: tablero-fallos-altos-hoja-de-exito-en-blanco-al-hq7p
toca: Yala/App/Views/Inbox/, Yala/App/Logic/, Yala/App/ViewModels/, YalaTests/
esfuerzo: high
cierre: cierra-sola
---

Base: origin/2.3 en jur211296/Yala (2.2 está publicada: no se toca). Un solo PR a 2.3. Commits y PR sin firma de IA. No tocar producción, datos reales, marketing, trabajo de otras sesiones ni colas. Antes de actuar, revisa PRs mergeados y abiertos y el tablero: si algo ya está hecho, verifícalo y documéntalo sin duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3. Simuladores: en la Max puedes usar un segundo simulador (además del de otra sesión) o el iPhone 14 por DeviceMCP; en la Mini, uno. Da siempre una descripción corta en español a cada comando Bash. Si te falta un acceso, credencial o decisión fuera de tu autoridad, no lo saltes ni lo inventes: márcalo con `BLOQUEANTE:` y sigue lo posible.

Dependencias: si otra sesión viva toca las mismas carpetas, ponte al día con origin/2.3 antes del gate y conserva el trabajo de las dos ramas; no reviertas lo de otra sesión.

## Contexto
Jürgen aprobó el 12-nov meter en 2.3 los tres fallos de prioridad alta del backlog, en un solo lote. Las fichas completas están en el repo; léelas, porque mandan sobre este resumen:
- `tickets/backlog/inbox-swipe-save-success-sheet-shows-blank.md`: al guardar deslizando en la Bandeja, la hoja de éxito sale en blanco.
- `tickets/backlog/reimported-group-legs-become-transfers.md`: al reimportar, las patas de un gasto de grupo quedan como transferencias.
- `tickets/backlog/adopt-over-a-device-already-in-cloud-mode-has-no-exit.md`: hacer adopt sobre un dispositivo que ya está en modo nube deja al usuario sin salida.
Si uno ya está arreglado en 2.3, compruébalo contra la versión publicada, documéntalo y no lo dupliques.

## Que se pide
1. Arreglar los tres, con la causa raíz explicada en el PR.
2. En el adopt, el usuario siempre tiene una salida clara y no pierde datos. Si la salida correcta es una decisión de producto que no está escrita, sepárala con su pregunta y una recomendación, y no elijas por tu cuenta.
- Un test de regresión por fallo que falle sin el arreglo. Review adversarial obligatoria. Gate del proyecto en verde.
- Haz tú el QA en el simulador o en el iPhone 14 con capturas antes y después en `capturas/` del worktree, y mueve las fichas y la card a done con evidencia. Solo deja en qa lo que de verdad necesite la mano de Jürgen.

Presupuesto de pruebas de interfaz:
  - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
  - Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
  - Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
  - Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva); nada de bucles de 10 min ni comandos que se pasen del límite y queden en segundo plano a ciegas.
  - Antes de compilar en iOS mira la carga: si otra sesión compila con xcodebuild en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.

## Que NO hay que tocar
El formato de exportación (lo cambia otro lote de Importar), Grupos fuera del reimport, y nada de producción ni de iCloud o Supabase reales: usa staging.

## Como se sabe que esta bien
Los tres fallos con test que falla sin el arreglo, QA con evidencia, gate verde, PR mergeado a 2.3.

Cierre: cierre autónomo (cierra-sola) con `/cerrar-total` solo si el trabajo queda completo y el modo de la sesión lo permite. En modo nocturno, una decisión vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.

## Paso 0 — decisiones (resueltas en autónomo, modo nocturno)

Medido en `origin/2.3` (84dea882c) antes de tocar nada.

1. **Hoja de éxito en blanco al deslizar.** Causa medida en el código: `InboxView` presenta `.sheet(isPresented:
   $showSwipeSuccessView)` con el contenido sacado de otro `@State` (`swipeSuccessData`), los dos escritos en el mismo
   toque. Es la trampa de `swiftui-ds.md`. **Decisión:** `.sheet(item:)` con un valor que lleva los datos y el registro
   guardado (el molde de la regla). Va en 2.3, no como arreglo urgente sobre 1.0: el encargo dice «2.2 publicada, no se
   toca» y un solo PR a 2.3. Test: XCUITest que desliza un borrador completo y exige «Aceptar» y el resumen; el caso de
   «Guardar de todas formas» vuelve a esperar «Aceptar», como pedía la ficha.
2. **Patas de grupo reimportadas como transferencias.** **Ya arreglado** desde el 29-oct (commit 38575a52e9, «Grupos
   fuera»), y está en `1.0` (lo publicado) y en `2.3`: `ImportGroupRowFilter` salta las filas de Grupos por nombre en 16
   idiomas antes de resolver nada, la vista previa las cuenta y `split_total`/`split_portion` se ignoran. El test pedido
   por la ficha existe: `ImportRoundTripAndAccountsTests` (ida y vuelta CSV y Excel con una pata del puente). **Decisión:**
   no se duplica; se corre su test como verificación, se comprueba con un mutante que caza el fallo, y la ficha va a
   `done` con la evidencia.
3. **Adopt sobre un teléfono que ya está en `.cloud`.** El disparador que queda vive en el código: «Empezar de cero» del
   Welcome retira la sesión y olvida los sellos del claim, pero no devuelve el modo a `.icloud`. La salida correcta es
   una **decisión de producto que la ficha deja abierta** («Qué falta decidir», puntos 1 y 2) y que no está escrita en
   ningún sitio (buscado en `docs/`, `tickets/` y el tablero). El encargo pide no elegirla. **Decisión:** se separa con
   su pregunta y una recomendación; en nocturno eso es checkpoint (`checkpoint_nocturno.py preservar`): PR en borrador
   con los fallos 1 y 2 terminados y probados, card «Espera decisión», sin mergear.
4. **Asumido sin preguntar:** QA en el simulador (iPhone 17 Pro, Mini, uno solo); el fallo 1 se ve, así que lleva
   capturas antes y después; el fallo 2 no cambia nada visible.
