---
name: el-ancla-que-no-existe
description: Antes de diseñar un «vuelve a enlazarse», comprueba que el objeto TIENE identidad serializable — si no la tiene, el ticket está pidiendo algo imposible y hay que decirlo, no inventar un ancla
metadata:
  type: feedback
---

**Cuando un ticket pide que algo «vuelva a enlazarse» más tarde, la primera medición es si el objeto
tiene una identidad que se pueda guardar. Si no la tiene, el diseño del ticket es imposible tal cual
y lo correcto es decirlo y entregar la mitad que sí se puede, no fabricar un ancla.**

**Why:** el 2026-09-11, el paso 10 pedía conservar el `splitExpenseID` «dormido» para que re-asociar
la misma cuenta re-enlazara las filas. Diseñé el almacén externo entero antes de comprobar lo
elemental: **`TransactionItem` no tiene `id`**, y su `syncID` es opcional y en una sesión privada vale
`nil`. Sin identidad, «devuélvele el puntero a ESA fila» no se puede escribir.

Las tres salidas que quedaban, y por qué ninguna vale como atajo:

- **Un `PersistentIdentifier` persistido o una huella por importe+fecha+cuenta** es el
  ancla-por-contenido que ya dio un incidente de identidad colapsada en este repo.
- **Un campo nuevo en el modelo** sí da el ancla, pero ese modelo vive en el container CloudKit
  personal: un field key nuevo exige deploy a Production, y sin él el mirror **rechaza el record
  entero** y el sync personal muere para todo el parque.
- **Dejar el puntero puesto**, que era la lectura literal del ticket, deja el movimiento ATRAPADO
  —ni editable ni borrable sobre un gasto que ya no existe— y ningún barrido lo repara después.

⇒ Entregué lo que el criterio de aceptación perseguía de verdad (**cero duplicados**, con un conjunto
sellado por cuenta) y **declaré la mitad que no vuelve** —el enlace— con su ticket y con la vía
concreta para hacerlo bien si Jürgen lo quiere.

**How to apply:**

- Ante un «se re-enlaza», «se rehidrata», «vuelve a apuntar»: **grep del modelo buscando su
  identidad** antes de diseñar nada. `var id`, un UUID no opcional, algo estable entre procesos.
- Si no la hay, **el ticket dice el CÓMO, no el QUÉ**: lee su criterio de aceptación y separa lo que
  se puede cumplir de lo que no. Aquí «0 duplicados» y «vuelven a estar enlazados» eran dos cosas, y
  una era alcanzable.
- **Declara la mitad que no entra en el ticket, en el PR y en la memoria**, con la vía real para
  cerrarla. Una promesa a medias sin nombrar es peor que no entregarla.

Relacionado: [[la-premisa-del-encargo-tambien-se-mide]] ·
[[el-mecanismo-que-existe-se-probo-con-otro-corpus]] — el AC dice QUÉ, no CÓMO.
