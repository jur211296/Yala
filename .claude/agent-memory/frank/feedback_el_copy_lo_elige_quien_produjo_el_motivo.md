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

## Y el 2026-09-22, en el mismo techo: al añadir una SEGUNDA vía de salida, el copy se quedó con la vieja

Cuando una salida pasa de tener **un** disparador a tener **dos**, el motivo que se journalea deja de ser obvio y hay
que volver a elegirlo. Añadí `fase >= 72 h OR (causa definitiva && causa >= 900 s)` y dejé intacto el
`exitReason: blocker?.abortReason ?? .preMountStalled` — que era correcto cuando la única vía con blocker era la del
blocker. Con dos vías, la vuelta puede salir por el techo de FASE en una pasada que casualmente traiga un 403 de
**cero segundos**, y journalear `preMountRefused` le da el correo de soporte a quien llevaba tres días sin red.

**How to apply:** cada vez que una salida gane una vía nueva, busca el sitio que **nombra** esa salida —el motivo, el
copy, el canario— y pregúntate cuál de las dos vías lo produjo. La regla que salió: **el motivo lo elige el techo que
VENCIÓ**, y el predicado vive en un solo sitio (`MigrationPolicy.reversePreMountCauseCeilingReached`) porque lo
consultan la máquina y el runner — escrito dos veces, un día discrepan. Y si el 403 era real no se pierde nada: la
persona reintenta y a los 15 min sale con el motivo bueno, que entonces sí es verdad.

Relacionado: [[feedback_el_predicado_que_amplio_cortocircuita]], [[feedback_el_termino_nuevo_desarma_el_test_viejo]].

## Y el mismo día, un paso antes del copy: la CLASIFICACIÓN también la elige quien produjo el motivo

En `snapshot-upload-has-no-ceiling-and-no-way-out` clasifiqué `.sessionExpired` como definitivo **por su nombre**:
«esperar no arregla una sesión caducada». Las **tres** lentes de la review cazaron por separado que ese caso tiene dos
productores. Uno es el SDK que ya borró la sesión, y ése sí es definitivo. El otro es un 401 del gateway con la sesión
todavía guardada, casi siempre por el reloj del teléfono atrasado, y ése lo cura la renovación del SDK a su hora.
Tratarlo como definitivo metía una regresión: el reintento reusaba el mismo JWT rechazado sin pedir nada.

**How to apply:** antes de decidir en qué techo cae un outcome, lista sus PRODUCTORES (`grep` de cada `return
.<caso>`) y pregunta para cada uno «¿esperar lo arregla?». Si la respuesta cambia de uno a otro, el outcome no basta
y hace falta un testigo que los separe (aquí, `canRenewSession` leído después de la llamada). El nombre de un caso
describe el SÍNTOMA del cliente, no la causa.

**Y el testigo se lee ANTES del `await` que lo deja caducar (2026-09-24, PR #231).** Elegí el aviso del adopt parado con
`isImportQuiescent` leído DESPUÉS de `closeSessionIfOpened`; `signOut` espera, y un import recién asentado deja de contar a
los 8 s, así que el texto podía salir genérico siendo la causa iCloud. Lo cazaron las dos lentes. Fija la lectura en una
`let` antes del `await` y pínchala con un mutante de orden.
