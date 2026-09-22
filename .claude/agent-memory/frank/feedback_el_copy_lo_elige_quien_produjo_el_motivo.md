---
name: el-copy-lo-elige-quien-produjo-el-motivo
description: Una decisión sobre el TECHO no decide el COPY — reusé un terminal cuyo texto acusaba a la cuenta en la nube para un motivo que escribe una función local.
metadata:
  type: feedback
---

Cuando una decisión de Jürgen dice «techo corto» o «terminal X», eso decide **cuánto se espera**, no **qué lee la
persona**. El copy lo elige **quién produjo el motivo**, y hay que leerlo literalmente antes de reusar el terminal.

**Why:** el 2026-09-22 la decisión era «el `default` de un reason desconocido: techo CORTO». Mandé ese caso al
terminal `preMountRefused` porque ya existía y elegía el corto — siguiendo el molde del claim, donde el motivo
desconocido sí va a `claimRefused`. Pero el texto de `preMountRefused` dice literalmente **«tu cuenta en la nube no
lo permitió»** y da el correo de soporte, y el motivo desconocido del Merkle lo escribe una **función local**: la
persona leía una causa inventada y soporte recibía correos por un desajuste de contrato del cliente. El molde del
claim no trasladaba su precondición — allí el motivo lo escribe el SERVIDOR. Dos lentes de la review lo cazaron por
separado.

**How to apply:** antes de reusar un `ReverseAbortReason` (o cualquier terminal con copy), **abre el
`Localizable.strings` y léelo**. Pregunta: ¿esta frase es VERDAD para la causa que la va a producir? Si el terminal
afirma quién falló, solo vale cuando ése fue quien falló. Y el test que lo fija compara **los textos**, no los enums:
es el texto lo que la persona lee.

Corolario que salió del mismo sitio: que dos motivos compartan `abortReason` no los hace redundantes — lo que los
separa es el `rawValue` del canario, y eso es lo único que en la flota distingue una avería local de un contrato roto.

Relacionado: [[feedback_el_molde_no_traslada_sus_precondiciones]], [[feedback_el_copy_que_promete_se_recorre]],
[[feedback_alcance_minimo_salvo_incoherencia]].
