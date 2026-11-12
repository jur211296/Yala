---
esfuerzo: high
---
# Auditar el import de Yala (CSV/XLSX) de punta a punta —cuentas, transferencias, ida y vuelta con el export y todo lo demás— y salir con una auditoría priorizada, tickets y cards propuestos, sin tocar el código de la app

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `import-auditoria-mejoras` · Sesión cola **S27j** · al cerrar → **S27k** (UI tests 2.2 en verde).
Card: `tablero ver tablero-explorar-todo-lo-que-mejorariamos-del-im-fb91`.

## Contexto
Pedido de Jürgen (2026-10-29 08:33 Lima): sesión EXPLORATORIA de todo lo que mejoraríamos del import, para ver cuántos tickets salen y en qué versión van. **Sin cambiar código de la app**: solo docs y tickets.

Hallazgos ya conocidos (revisión de solo lectura en `origin/2.2`), punto de partida obligatorio — verifícalos y amplíalos:
- **Cabecera rígida**: el XLSX solo acepta `date,amount,currency,category,subcategory[,tags,note]` (`Yala/Utils/XLSXReader.swift:84-96`); el CSV igual (`TransactionCSVImportService.swift:317-331`, `:1240-1251`). El export escribe `account`, `split_total` y `split_portion`, así que **el propio export de Yala no se puede reimportar** (ticket existente `tickets/backlog/exported-csv-cannot-be-imported-back.md`, card `mnox`).
- **No hay columna de cuenta**: todo va a una sola cuenta o a una cuenta por moneda (`:1447-1449`, `:1608-1611`).
- **Transferencias con dos patas** solo se emparejan si coinciden día, monto absoluto y moneda (`applyTransferPairingHeuristic` `:1753-1785`, `TransferPairReconcileService.computePairingPlan`). Las que cambian de moneda nunca se emparejan; no hay columna de par ni en export ni en import (`transfer_pair_id` solo existe en la sync con la nube, `EntityEmissionMap.swift:206,233`). El emparejamiento no mira la cuenta.
- **Lo que sí funciona**: la subcategoría de sistema «Transferencia entre cuentas» saca esas filas de gastos e ingresos.

Cards relacionadas en el tablero (no dupliques; enlaza o absorbe): `mnox` (export no reimportable — se absorbe o enlaza), `sqcy` (movimientos más antiguos que el saldo inicial y su tasa), `trc6` (falta «Importación completada», en QA de Jürgen), `36m1` (Bienvenida: importar estado de cuenta), `3gsu` (importar grupo desde Splitwise/Tricount).

Caso real: `Yala_Registros_27-oct-2026_con-transferencias.xlsx`. No está en la Mini (revisado 08:4x): está en Descargas de la Air. Si no lo tienes, sigue con archivos sintéticos y dilo en el cierre. **Nunca lo subas al repo** ni copies datos reales a docs/tests.

## Qué se pide
1. Card a in progress con `--agente frank` al empezar.
2. Auditar, además de lo de arriba, todo lo que encuentres: ida y vuelta export→import sin pérdida; columnas por nombre y en cualquier orden; cuenta por nombre y crearla si no existe; saldos iniciales; multidivisa y tipos de cambio; gastos de grupo y columnas de reparto; etiquetas; categorías que no existen; duplicados y reimportar el mismo archivo; vista previa antes de confirmar; errores claros por fila; rendimiento con más de 3000 filas; formatos de fecha y decimales por país; Deshacer el import; modo nube vs iCloud privado.
3. Entregable `docs/import/AUDITORIA-IMPORT-2-2.md`: hallazgos priorizados, cada uno con evidencia (archivo:línea), impacto para el usuario y propuesta.
4. Por cada mejora, un ticket en `tickets/backlog/` con su **versión recomendada** (2.2 si es bloqueante o barata; 2.3 o después si no) y su card en el tablero (`tablero crear --proyecto Yala ... --cierre cierra-sola --agente frank`), **sin lanzar nada**. El ticket `exported-csv-cannot-be-imported-back.md` se absorbe o se enlaza (y su card `mnox` se actualiza en consecuencia).
5. Un solo PR a 2.2, solo con docs y tickets.
6. En el resumen de cierre, lista todos los tickets que salieron con la versión que propones para cada uno, para que Jürgen decida dónde van.

## Qué NO tocar
- Código de la app, tests, proyecto Xcode: nada. Solo `docs/` y `tickets/`.
- marketing/ y Web/ (Lola). No lanzar otras sesiones Yala.

## Reglas de Mini
No hace falta build ni simulador: es una auditoría de lectura. Si al final compilas algo para medir, pipeline serial (limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim) y borra al cerrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

## Cómo se sabe que está bien
- `docs/import/AUDITORIA-IMPORT-2-2.md` cubre los hallazgos conocidos y la lista del punto 2, priorizados.
- Un ticket + card por mejora, con versión recomendada; `mnox` absorbido o enlazado.
- PR docs-only a 2.2; cierre con la lista de tickets y versión propuesta.

/cerrar-total

## Paso 0 (Frank, 2026-10-29)

- **Caso real:** el archivo SÍ está en este Mac (`~/Downloads`). Se mide con él solo en el scratchpad y solo en cifras agregadas (filas, columnas, monedas, cuántas transferencias se emparejarían). Nada de sus datos va al repo.
- **Sin compilar:** la auditoría es de lectura más el archivo real. Lo que pida un número de tiempo (rendimiento con 3000 filas, modo nube) queda como «inferido» y su ticket empieza por medirlo.
- **`mnox`:** se absorbe en el sentido de reutilizar su ticket (`exported-csv-cannot-be-imported-back`) como el de «columnas por nombre», ampliado con la auditoría y con versión propuesta. No se crea otro para lo mismo.
- **Granularidad:** un ticket por mejora que se pueda lanzar sola. Lo que solo tiene sentido junto (p. ej. las columnas nuevas del export y su lectura) va en el mismo ticket.
- **Versión propuesta:** 2.2 para lo que hoy deja datos mal en silencio y es barato, y para lo que tiene que acompañar a «columnas por nombre» para no abrir un bug nuevo; 2.3 para el resto del paquete de ida y vuelta y las mejoras de flujo; 2.4 para formatos raros. La decide Jürgen: va en el ticket, la card y el cierre.
- **Cards:** en backlog, asignadas a frank, `cierra-sola`, sin lanzar. Las relacionadas (`sqcy`, `trc6`, `36m1`, `3gsu`) se citan; no se tocan.
