Yala
# Bandeja: unir al llegar el mismo consumo de Apple Pay, aviso, correo, web e IA, con Separar
---
toca: Yala/Models/InboxDraft.swift,Yala/App/Intents/ApplePayPendingStore.swift,Yala/App/Logic/AtajoBanco/BankNoticeDraftService.swift,Yala/App/Services/BankEmailDraftService.swift,Yala/App/Logic/BankEmailDraftLogic.swift,Yala/App/Logic/InboxMatchLogic.swift,YalaTests/BandejaUnirAlLlegar/,webapp/supabase/,tickets/backlog/2026-11-24-bandeja-unir-al-llegar.md,tickets/done/2026-11-24-bandeja-unir-al-llegar.md
esfuerzo: high
cierre: cierra-sola
depende: Yala/bandeja-emparejador-entre-fuentes
---

Decisión de Jürgen (24-nov, 14:30 y 14:32 Lima): «vamos con todo lo recomendado» de `docs/propuestas/bandeja-sin-duplicados/README.md` (opción B, un pendiente por consumo), y los lotes 1 a 4 entran **en 2.3**, después de la subida a TestFlight de la build 8.

Decisiones ya tomadas (todas las recomendadas): unir solo en coincidencia fuerte, con «Separar» a un toque; si el importe difiere entre fuentes, manda el del banco; un planificado de monto fijo con cargo distinto pregunta, no se actualiza solo; grupos y cuentas compartidas quedan fuera (el emparejador ignora los borradores de grupo).

## Qué se pide
Lote 2 del plan. Cablea `InboxMatchLogic` en un punto común después de `materialize` para Apple Pay, aviso del banco, correo del banco, Yala web e IA. Agrega un campo sincronizado para recordar qué se unió (migración SwiftData más la columna en la nube, con su rollback en `webapp/supabase/`) y la acción «Separar» en el borrador. Toca el modelo sincronizado, así que sigue el checklist de cambios de modelo del repo y prueba que una base de 2.2 migre sin perder borradores. Pruebas en `YalaTests/BandejaUnirAlLlegar/`.

## Cómo entregar
- Un PR contra 2.3, sin firma de IA. Deja el auto merge activado y cierra; no esperes al CI.
- **Entregable visual:** artifact público de Claude (capturas o flujo según el lote). Pon el link en «Qué salió».
- Si necesitas un archivo fuera de `toca:`, tócalo solo si es imprescindible y anótalo en «Decidido sin consultar». Si cambian textos, ponte al día con el catálogo de 2.3 antes del PR y agrega las claves en todos los idiomas.
- Pruebas en el iPhone 14 (DeviceMCP, conectado a la Mini): verifica primero que esté libre; si no, usa un simulador (en la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo).
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión».
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones

> Modo semi. Las de producto ya las tomó Jürgen (24-nov, «todo lo recomendado»); estas son técnicas y las resuelve la
> sesión con su recomendación. Se discuten en el PR.

**D1 · ¿Sobre qué base se trabaja si el lote 1 (emparejador) no está mergeado?** → la rama del lote 1 (PR abierto, en
cola de auto-merge) se une a la mía; al abrir el PR se rebasa sobre `2.3` con el lote 1 ya dentro, o el PR lo arrastra.
Por qué: el encargo declara `depende:`. Descartada: esperar el merge sin avanzar.

**D2 · ¿Cómo se recuerda lo unido?** → un solo campo opcional `InboxDraft.joinRecordRaw` (JSON `InboxJoinRecord`) en el
borrador que sostiene el consumo: lo que trajo cada fuente absorbida y los valores del borrador antes y después de unir.
Lo absorbido NO queda como fila. Por qué: un estado nuevo de borrador («unido») lo leería una 2.2 como pendiente
(`DraftStatus` cae a `.pending`) y la Bandeja de esos teléfonos volvería a enseñar los duplicados. Descartadas: fila
oculta con puntero al que la sostiene, y un campo por fuente.

**D3 · ¿Cuándo se une: antes o después del guardado de cada fuente?** → antes, en el mismo guardado. El borrador que
llega y se une se borra sin haber llegado a guardarse (no viaja a iCloud ni a la nube) y el que lo sostiene se actualiza;
si el guardado falla, se deshace la unión con lo demás. Por qué: atómico, sin borrar filas ya sincronizadas.
Descartada: guardar y unir en un segundo guardado (si fallaba, había que deshacer un borrado con `rollback` en el
contexto compartido).

**D4 · ¿Qué une el lote 2?** → solo la coincidencia FUERTE con un pendiente (`InboxMatchLogic.decide` → `.join`). Lo
dudoso y «ya registrado» quedan como hoy (pendiente propio); preguntarlo es el lote 3. Por qué: decisión 2 de Jürgen y
el plan de lotes. El emparejador recibe `saved: []`: con o sin guardados, `.join` solo sale de un pendiente fuerte.

**D5 · ¿Qué campos cambia la unión en el que sostiene?** → importe y moneda del banco, hora de Apple Pay o del aviso,
comercio por la prioridad del lote 1; cuenta y subcategoría solo si faltaban. Por qué: es el `Resolved` del lote 1 y
nunca pisa una cuenta elegida (en una unión fuerte las cuentas coinciden o una falta).

**D6 · ¿Qué hace «Separar»?** → separa todo lo unido de una vez: cada fuente absorbida vuelve como pendiente propio y el
que sostiene recupera sus valores, campo a campo, solo donde siguen siendo los que dejó la unión (lo que la persona
cambió después se queda). Un toque, sin confirmación. Lo separado no se vuelve a unir solo entre sí. Por qué: «Separar
a un toque» (decisión 2) y no perder ediciones. Descartada: separar fuente a fuente (es UI del lote 3).

**D7 · ¿Dónde va «Separar» en el lote 2?** → en el editor del borrador, un bloque pequeño «Unido de: Apple Pay · Correo
BCP» con el botón, solo si el borrador tiene algo unido. La fila con las fuentes es el lote 3. Textos en una tabla
propia (`BandejaUnir.strings`, 16 idiomas) para no chocar con el catálogo que toca el PR de la red ±1 día.

**D8 · Un registro de unión que no se entiende (versión futura).** → el borrador no se usa como sostén ni enseña
«Separar». Por qué: reescribirlo perdería lo que guardó una versión nueva.

**D9 · El mismo borrador de la IA visto en otro aparato.** → `alreadyMaterialized` cuenta también las fuentes de la IA
absorbidas en un registro de unión (instante de llegada, importe y nota). Por qué: si no, el otro aparato lo volvería a
crear como pendiente nuevo.

**D10 · La columna en la nube.** → `inbox_drafts.join_record_raw text` con `since: 11` (manifest v11), con el molde de
`capture_rules_raw` (apunte y reemisión al subir de versión). La migración y su marcha atrás van en
`qa/cloud/g36_01_*`, como todas las columnas del canal personal, no en `webapp/supabase/` (ahí viven los permisos del rol
de lectura web, que son por columna: la nueva no le llega). CloudKit: `CD_joinRecordRaw` en los dos `.ckdb` de
desarrollo; Production queda en `pendingProductionDeploy` y lo despliega Dan. Por qué: es el procedimiento que ya fija
el test de paridad y `asc-preflight.sh`.

**D11 · Prueba de que una base de 2.2 migra.** → test que crea un store con el modelo de 2.2 (el modelo actual sin los
campos que el esquema de producción de CloudKit, que es el de 2.2, no tiene), siembra borradores con Core Data y lo abre
con el `ModelContainer` actual: mismos borradores y `joinRecordRaw` en `nil`.
