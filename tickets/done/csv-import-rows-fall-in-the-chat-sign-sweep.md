---
id: csv-import-rows-fall-in-the-chat-sign-sweep
status: done
priority: high
area: "data, import"
created: 2026-09-08
source: review adversarial de chat-rows-with-unsigned-amount-have-no-repair-path (2026-09-08)
updated: 2026-09-23
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - limpieza de una sola vez que ya corrio en tu iPhone con el build 13; ChatUnsignedExpenseRepairTests
---

# El barrido del signo del chat también alcanza a lo que se importó por CSV, y eso no es lo que se aceptó

## La decisión que hay que revisar

Jürgen aprobó el 2026-09-08 migrar a ciegas el corpus del chat, **aceptando expresamente un daño
concreto**: «los reembolsos legítimos en esa ventana también se voltean». La review adversarial midió
que el criterio alcanza a más que eso, y el resto no cae bajo esa frase.

## Lo medido (2026-09-08, en este árbol)

**1. Una fila importada por CSV/XLSX toma como `createdAt` el instante del import, no la fecha de sus
datos.** Los cuatro sitios de creación de `Yala/Utils/TransactionCSVImportService.swift` (`:187`,
`:1107`, `:1502`, `:1663`) **no asignan `createdAt`**, así que toma el default `Date.now`. Las cuatro
apariciones de `createdAt` en ese fichero son lecturas (`$0.createdAt >= importStart`), lo que además
confirma la semántica: el propio importador lo usa como «cuándo se importó».

⇒ **Un CSV con años de historia importado dentro de la ventana entra ENTERO en el criterio**, sin que
importe la columna `date`.

**2. El importador reusa categorías por nombre sin mirar `isIncome`.** En modo estricto
(`TransactionCSVImportService.swift:492-508`) busca por nombre con un `#Predicate` que solo compara
`cat.name`, y su propio comentario lo dice: «sin filtrar por isIncome para soportar categorías
"neutrales" como "Otros"». Ése es además **el modo por defecto**
(`ImportIntroSheet.swift:104`: `allowCreatingNewCategories = false`). El modo permisivo hace lo mismo
(`CategoryImportHelper.swift:45-66`).

**3. Ninguna de esas filas lleva marcador de sistema.** El importador solo escribe
`balanceAdjustmentType` cuando la subcategoría `isAnySystem` (`:203`), que compara contra 16 cadenas
literales de «Ajuste de saldo» y «Transferencia entre cuentas». Una subcategoría normal no lo es.

## Qué le pasa al usuario

Dos formas, y **la segunda no es un reembolso bajo ninguna lectura**:

1. Un abono archivado bajo la categoría de gasto que compensa (devolución, cashback). El barrido lo
   voltea y el saldo se mueve el doble, en la dirección contraria. Esto sí cae dentro de lo aceptado.
2. **Un ingreso cuyo nombre de categoría colisiona con una de gasto.** «Otros», «Salud»,
   «Educación» y «Viajes» están sembradas con `isIncome: false`. Una fila
   `2026-05-10, 1500.00, PEN, Otros, Bonificación` se cuelga de la «Otros» de gasto, y el barrido la
   deja en −1500. Es un ingreso convertido en gasto.

El cambio es silencioso y solo se deshace editando fila a fila.

## Por qué no se resolvió en el PR del barrido

Porque **no hay señal estructural que separe una fila del chat de una del CSV** — que es el corazón
del ticket padre: `TransactionItem` no tiene campo de origen. Las alternativas evaluadas (acotar
también por `date`, o por la distancia entre `date` y `createdAt`) son heurísticas frágiles: el chat
admite dictar «un café en marzo» y un CSV puede traer fechas recientes.

## Qué necesita decidir Jürgen

- **¿Se acepta también este daño?** Es más ancho que el que aprobó, y su tamaño depende de si ha
  importado CSV/XLSX desde el 2026-04-27.
- **¿O se acota el barrido de otra forma?** Por ejemplo, no volteando filas cuya `date` diste mucho de
  su `createdAt` (que es la firma de un import histórico) — con el coste de perder alguna del chat.
- **¿O se arregla antes el importador**, para que estampe `createdAt` coherente y no reuse categorías
  de la naturaleza contraria? Eso es un arreglo bueno por sí mismo, pero no cura lo ya importado.

## Criterio de hecho (AC)

- [x] Decisión de Jürgen sobre las tres salidas.
- [x] Si se acota: criterio nuevo con test que fije qué sobrevive.
- [x] Ticket aparte para que el importador estampe `createdAt` y valide la naturaleza de la categoría → `csv-import-leaves-no-origin-mark-and-reuses-opposite-categories` (2026-09-16).

---

# Resuelto: el barrido no toca lo importado (2026-09-08)

## Decisión de Jürgen

**Acotar: el barrido no debe tocar filas importadas por CSV.**

## La señal, y por qué existe pese a lo que decía este ticket

Este ticket afirmaba que no hay forma de separarlas, y **campo a campo es cierto**: no hay modelo de
sesión de import, el importador no deja nada en `UserDefaults` y construye el `TransactionItem` con
exactamente los mismos campos que el chat. Lo que sí las separa es **cuántas nacen a la vez**:

- **El importador crea el lote entero sin `save()` intermedio** — su propio docblock lo dice: «No
  realiza `context.save()`. El llamador debe guardar después». Sus filas nacen en un bucle cerrado,
  con milisegundos entre una y la siguiente.
- **El chat exige un toque humano por fila.** `ChatAssistantViewModel.saveDraft` tiene un **único**
  llamador (`ChatAttachmentsView`), y es el `onSave` de UNA tarjeta: no hay «guardar todas».

Y no es una ocurrencia: **el propio importador ya reconoce así sus filas**, con un
`importStart = Date.now` antes del bucle y un `filter { $0.createdAt >= importStart }` después, para
no confundirlas con las históricas al emparejar transferencias.

## Cómo quedó

`ChatUnsignedExpenseRepairLogic.batchFlags` agrupa por **huecos encadenados** (tolerancia 2 s) sobre
**todas** las filas del store, y una fila que pertenezca a un grupo de dos o más queda fuera del
barrido. Se agrupa por hueco y no por ventana fija porque un import de mil filas tarda varios segundos
en total, pero entre dos consecutivas nunca hay una pausa humana.

**Hay que pasarle todas las filas, no solo las candidatas**, y esto es lo que más fácil se hace mal: un
import mezcla gastos e ingresos, así que mirando solo las positivas un import de quinientas filas con
tres candidatas parecería tres gastos sueltos. Hay un test justo para eso
(`aLoneCandidateInsideAnImportedBatch_isStillProtected`).

De paso, el pre-filtro del fetch desapareció: ahora hay **un solo fetch sin predicado** y el criterio
es la única autoridad. Eso cierra a la vez la duplicación que ya había dejado dos condiciones sin
probar en este mismo fichero.

## Residual conocido

**Un import de una sola fila no tiene vecino y es indistinguible de un gasto dictado.** No hay señal
que lo separe. Y un usuario que pulsara «Guardar» en dos tarjetas del chat en menos de dos segundos
perdería esas dos: se falla hacia no tocar, que es lo que pidió la decisión.

## Verificación

Dos controles positivos por mutación, uno por cada lado del acotado:

- Quitar el guard del lote pone en rojo los tres casos de importación.
- Hacer que **todo** cuente como lote pone en rojo siete, incluido el caso principal — que es lo que
  impide satisfacer el acotado dejando de curar nada.

## QA · 2026-09-16 — sigue en qa: a mano en simulador (unos 10 minutos)

**Lo que se midió hoy:** Yala no registra tipos de documento, así que el import solo entra por el
selector de archivos del sistema, y ese selector no está en el árbol de accesibilidad: la automatización
no puede elegir el archivo y Escape no lo cierra. Todo lo demás es local y cabe en el simulador.

**El criterio 3 ya tiene ticket:** `csv-import-leaves-no-origin-mark-and-reuses-opposite-categories`.

### Guion, a mano

1. Borra Yala Dev del simulador y ábrela desde el icono, **sin** `-uitest` (con él el barrido no corre y
   el store es otro). Onboarding normal con una cuenta en PEN. No relances la app hasta el paso 5.
2. Crea dos archivos UTF-8 y arrástralos al simulador (Archivos → En mi iPhone), con los nombres de
   categoría sembrados en el idioma del simulador:
   - `lote.csv` — cabecera `date,amount,currency,category,subcategory,note` y tres filas:
     `2026-05-10,45.00,PEN,Compras,Farmacia y botiquín,devolucion` ·
     `2026-06-02,30.00,PEN,Alimentación,Restaurantes,reembolso` ·
     `2026-06-03,-12.50,PEN,Alimentación,Delivery,gasto`
   - `suelta.csv` — la misma cabecera y una fila: `2026-07-01,20.00,PEN,Alimentación,Restaurantes,control`
3. Perfil → Datos → «Importar archivo», con «Crear categorías nuevas» apagado → `lote.csv` → la cuenta
   PEN. Espera 5 s o más y repite con `suelta.csv`.
4. En Registros apunta los cuatro importes: +45, +30, −12,50 y +20.
5. Fuerza el cierre, reabre desde el icono y espera unos 2 minutos: el barrido espera a que el store esté
   listo.
6. **PASS** si +45 y +30 siguen positivos (el lote quedó protegido) **y** la fila suelta pasa a −20. Ese
   −20 es el control: prueba que el barrido corrió, y es el residual aceptado de arriba. Si la suelta sigue
   en +20, la corrida no vale; repite desde el paso 1.

Guion preparado por un lector del barrido sobre `2.1` @ `bebd57a57` (cabeceras en
`TransactionCSVImportService.swift:302-305`; el barrido no corre con `-uitest`, `AppBootstrapper.swift:202-206`).

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Es una limpieza que corre una sola vez por dispositivo y en tu iPhone ya corrió con el build 13. Lo cubre `ChatUnsignedExpenseRepairTests`.
