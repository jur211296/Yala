---
id: adopt-lineage-block-shows-connecting-for-fifteen-minutes
status: backlog
priority: very-high
area: "cloud sync, welcome"
created: 2026-11-13
updated: 2026-11-13
source: "QA de Jürgen en el iPhone 14 (Yala Dev, staging), sesión del minitutorial del correo, 2026-11-13"
---

# Entrar desde un teléfono nuevo en una cuenta con grupos se bloquea 15 min en «Conectando con tu cuenta… 60 %»

## La causa (medida el 2026-11-13, segunda y tercera prueba)

**No hacen falta datos ajenos: los crea la propia app.** Con el teléfono vacío (app reinstalada, App Group vaciado y el
iCloud de Yala Dev borrado), al «Entrar con Google» el canal de Grupos baja ANTES del claim (`/groups/pull` 07:12:09,
`/account/claim` 07:12:33) y el puente de Grupos crea en local la cuenta sistema «Grupos PEN», las categorías «Grupos» y
«Cobros de grupos», 7 subcategorías, el gasto «Super Wong 60» (sin `syncID`) y su borrador `groupExpense`. La cuenta de
staging ya tenía sus 2 gastos de grupo puenteados por el otro aparato, con identidades distintas. El adopt ve esas filas
como huérfanas, exige linaje y no encuentra ninguna compartida: `cloudAdoptLineageBlocked noSharedRows|quiet`.

⇒ **Le pasa a toda persona con grupos que entre en su cuenta desde un teléfono nuevo**, no a un caso raro de datos
ajenos. Es la colisión entre dos reglas de `.claude/rules/swiftdata-cloudkit.md`: el linaje del adopt y el puente de
Grupos, que acuña identidades por dispositivo. Una cuenta sin grupos (`930e5e48…`, 1.906 movimientos) no tiene el puente
que lo dispare. Sin medir aún si la 2.2 publicada tiene el mismo orden (Grupos antes del claim).

## Qué ve la persona

Inicia sesión en un teléfono que ya tiene datos y la cuenta de Yala también tiene datos, pero no comparten nada. La
pantalla se queda en «Conectando con tu cuenta… 60 % · Esto puede tardar unos minutos. Mantén Yala abierta», con
«Reintentar» y «Cancelar la activación». Jürgen lo vivió como un cuelgue («es una cuenta con nada de datos, debería
cargar en 1 segundo»). «Reintentar» vuelve al mismo sitio.

## Lo medido (2026-11-13, 11:48–11:56 UTC, instalación `c1fdbac40fc3c52e` en `yala_metrics_staging`)

- 11:51:21 el claim contesta `existing_stable` y empieza el adopt. A las 11:51:51 la app ya sabe que no va a entrar:
  `cloudAdoptLineageBlocked = noSharedRows|quiet` y `cloudForwardStepWaiting = adopt|lt_15m|lt_15m|stop_lineageUnproven`.
  La importación ya está quieta, así que esperar no cambia nada.
- Aun así la pantalla sigue en progreso hasta el techo corto (15 min, regla «El adopt solo sube lo que el backend no
  conoce…» de `.claude/rules/swiftdata-cloudkit.md`). Solo entonces sale el texto `effectLineageUnproven`.
- Cada reintento (≈ cada 30 s) vuelve a bajar la cuenta entera: `/sync/pull` de seq 0 a 4171 en 9 páginas y
  `/sync/merkle`, unos 25 s por vuelta. Son 4 vueltas en 2 min según `wrangler tail`.
- La cuenta de staging (`7fa23530…`) tiene 7 movimientos, 5 cuentas, 13 categorías, 69 subcategorías, 2 borradores y 3.970
  tipos de cambio vivos. Se migró desde otro aparato el 2026-11-06. El teléfono tenía su propio corpus: 1 movimiento,
  1 cuenta, 2 categorías, 7 subcategorías y 1 borrador, con identidades distintas. Ninguna fila en común, así que el
  bloqueo en sí es correcto.

## Lo que hay que decidir

0. **Que el puente de Grupos no fabrique filas personales antes de que el adopt decida** (o que el linaje reconozca las
   filas del puente: su gemela en la cuenta es la pata del mismo gasto de grupo, con clave natural `split_expense_id`).
   Sin esto, lo de abajo solo hace que el bloqueo se diga antes.

El bloqueo en sí se queda para los datos ajenos de verdad. Lo que falla también es cuánto tarda en decirlo:

1. Con `noSharedRows` **y** la importación quieta, ¿salir ya a la pantalla de «no coinciden» en vez de esperar 15 min? La
   espera legítima (lo que aún se importa) ya la frena antes la quiescencia.
2. Mientras se espera, no repetir la enumeración entera en cada vuelta, o espaciarla.
3. Que «Reintentar» no prometa nada que no puede cumplir: el texto de la salida ya existe.

Es lógica de sync: va con review adversarial.

## Residual de la prueba

Desinstalar Yala Dev **no** vacía su App Group (`group.com.jurgenschmidt.yala.dev`): el store volvió intacto tras
`devicectl device uninstall`. Para dejar el teléfono limpio hubo que vaciar los stores a mano.
