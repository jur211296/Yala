# Plugin de Yala para Claude — borrador de la fase 0

Este plugin conecta Claude con tu cuenta de Yala en la nube para que puedas preguntarle por tus finanzas:
cuánto llevas gastado este mes, cómo vas con tus presupuestos o qué pagas cada mes en suscripciones. Claude
solo puede leer: no crea, cambia ni borra nada, y puedes quitarle el acceso cuando quieras.

**Estado: borrador, no publicado.** Apunta al Worker de staging y solo funciona con las cuentas de prueba de
staging. No se ha enviado al directorio de Anthropic.

## Qué trae

- `.mcp.json`: el conector MCP remoto de Yala (seis herramientas de solo lectura).
- `skills/gasto-del-mes`: cuánto has gastado y en qué.
- `skills/presupuesto`: qué presupuestos van en riesgo y cuánto te queda.
- `skills/recurrentes-a-revisar`: tu gasto fijo mensual y anual, y qué pagos conviene revisar.

## Requisitos

Una cuenta de Yala en modo nube. Si usas Yala en modo privado (iCloud), tus datos no están en la nube y el
conector no ve nada.

## Ejemplos

- «¿Cuánto llevo gastado este mes y en qué?»
- «¿Cómo voy con mis presupuestos?»
- «¿Qué pago cada mes en suscripciones y cuáles debería revisar?»
