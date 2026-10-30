---
esfuerzo: high
---
# Import: leer las columnas por nombre (el export de Yala vuelve a entrar), columna de cuenta que crea la cuenta si no existe, Excel con texto en la celda, montos con miles y signo «−», y patas del puente de Grupos fuera

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `import-columnas-cuenta-excel-montos` · Sesión cola **S27m** · al cerrar → **S27tf** (TestFlight 2.2 (4)).
Cards: `mnox` (H4) · `tablero-al-reimportar-las-patas-del-puente-de-gr-l2g9` (H5) · `tablero-un-excel-con-el-texto-dentro-de-cada-cel-7wh5` (H3) · `tablero-importar-lee-el-separador-de-miles-como-jvgc` (H1) · `tablero-importar-a-la-cuenta-que-dice-cada-fila-34qe` (H7). Id de mnox: `tablero-el-csv-que-exporta-yala-no-se-puede-volv-mnox`.

## Contexto
Decisión de Jürgen (2026-10-29 13:05 Lima): siete hallazgos de la auditoría del import van a 2.2. La sesión anterior (S27l, PR propio) arregló las transferencias por idioma (H2) y el rollback (H6) con un solo punto de decisión «transferencia / ajuste». Esta hace todo lo que toca la lectura del archivo y el modelo de fila, que es el mismo código y no se puede partir sin pisarse.

La auditoría está en `docs/import/AUDITORIA-IMPORT-2-2.md` y los tickets en `tickets/backlog/`, del PR #689 (rama `encargo/2026-10-29-import-auditoria-mejoras`). Si al arrancar #689 aún no entró en `origin/2.2`, léelos con `git show origin/encargo/2026-10-29-import-auditoria-mejoras:<ruta>`, sin traer esa rama a la tuya. Lee H1, H3, H4, H5 y H7 y sus tickets.

- **H4**: cabecera rígida en CSV (`TransactionCSVImportService.swift:317-331`, `:1240-1252`) y Excel (`XLSXReader.swift:84-97`). El export escribe `date,amount,currency,account,category,subcategory,tags,note,split_total,split_portion` y deja reordenar y quitar columnas. La validación existe cuatro veces (`:358-538`, `:1265-1413`, y Excel vía `validateAndCreateDraft` `:649-735`).
- **H5** (va con H4; sin él H4 abre un error de cifras): las subcategorías del puente de Grupos son `isSystem` y se reimportarían como transferencias (`CategorySeed.swift:707-734`, `GroupBridgeSystemEntities.swift:23-49`). El caso real trae una.
- **H3**: `XLSXReader.swift:61-63` exige `sharedStrings.xml`; la cabecera (`:79-81`) solo lee de ahí. El archivo de Jürgen es todo `inlineStr` (openpyxl). La fecha de Excel solo se convierte en la columna 0 (`:210-216`); solo se lee la primera hoja.
- **H1**: `normalizeAmountString` (`:840-884`) decide el decimal por celda («1,500» y «1.500» entran como 1,5; «1.234.567» como 1,234) y `MoneyParsing.swift:56-57` borra el «−» U+2212, así que «−12.50» entra como ingreso.
- **H7**: no hay columna de cuenta; una moneda solo puede ir a una cuenta (`:154`, `:1447`, `:1089`, `:1608`) y con una moneda sin cuenta sale error (`ImportIntroSheet.swift:538-548`). El archivo de Jürgen tiene 7 cuentas en 3 monedas.

## Qué se pide
1. Las cinco cards a in progress con `--agente frank` al empezar.
2. H4: cabecera por nombre (mayúsculas y espacios aparte), en cualquier orden; obligatorias `date`, `amount`, `currency`, `category`, `subcategory`; las desconocidas se ignoran y la vista previa lo dice; si falta una obligatoria, el error dice cuál. Las cuatro rutas leen a un `RawImportRow` común y validan en un solo sitio, usando el punto de decisión de transferencia que dejó S27l.
3. H5: una fila con subcategoría del puente no se importa y la vista previa lo dice («N movimientos de grupos no se importan: se recrean desde el grupo»). `split_total` y `split_portion` se aceptan y se ignoran.
4. H3: sin tabla compartida, seguir con una vacía y leer `inlineStr` también en la cabecera; fecha convertida en la columna `date`; si hay varias hojas, la primera con cabecera reconocible.
5. H1: separador decimal decidido **por archivo**; un «1,500»/«1.500» sin pistas va como fila dudosa en la vista previa con la lectura propuesta; «−» y «–» cuentan como signo.
6. H7: columna `account` por nombre. Una cuenta que no existe se propone crear en la vista previa, con la moneda de sus filas y saldo inicial cero; si es una tarjeta con líneas por moneda, va a la línea de la moneda de la fila. Sin columna, el flujo de hoy. Archivadas y la de Grupos siguen fuera.
7. Tests con casos reales: la tabla de montos de H1, un `.xlsx` `inlineStr` generado en el test, ida y vuelta export (columnas por defecto y reordenadas) → import, filas del puente, cuentas nuevas y tarjeta multidivisa. Además, prueba local con `/Users/jur/Downloads/Yala_Registros_27-oct-2026_con-transferencias.xlsx` (en la Mini): **nunca** se sube al repo ni se copian sus datos a tests o docs; solo se informa el resultado en el cierre.
8. Review adversarial antes del PR (otra pasada que intente romperlo: cabeceras duplicadas, columna `account` vacía en algunas filas, nombres de cuenta con distinta mayúscula, monedas que no casan con la cuenta existente, hojas vacías).
9. Un PR a 2.2. Cards a done, o a in qa de Jürgen si hay algo que solo él ve en el teléfono.

## Qué NO tocar
- Las tandas 2.4 del import (duplicados, deshacer el import, fechas por archivo, codificaciones, hilo principal, etc.): no se adelantan.
- Esquema SwiftData salvo que H7 lo exija sin remedio (si es así, para y pregunta). marketing/ y Web/. No lanzar otras sesiones.

## Reglas de Mini
Pipeline serial Yala: limpiar → build `xcodebuild -jobs 2` sin sim booteado → boot 1 sim → tests → apagar y borrar ese sim. Nada de solapar build y tests. Borra al lanzar y al cerrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR. El build y el simulador van después de ese rebase, una sola vez.

## Cómo se sabe que está bien
- **El archivo de Jürgen `Yala_Registros_27-oct-2026_con-transferencias.xlsx` entra entero, con sus 7 cuentas y los saldos correctos** de cada una (compara cuenta por cuenta contra la suma de sus filas en el archivo y dilo en el cierre).
- El CSV y el Excel que exporta Yala, con las columnas por defecto, vuelven a entrar sin pérdida de cifras; las patas del puente no entran y la vista previa lo dice.
- La tabla de montos de H1 entra bien o como fila dudosa, nunca mal en silencio.
- PR a 2.2 abierto.

## Actualización (2026-10-29 19:52 Lima, tras cerrar S27l)
- S27l cerró con el PR #691: transferencias en los 16 idiomas, ajuste sin depender del idioma y rollback del import, con un solo punto de decisión «transferencia / ajuste» que esta sesión reutiliza. Si ese código aún no está en tu base, su rama es `encargo/2026-10-29-import-transferencias-rollback` (léela con `git show`).
- **Alcance de H5 ampliado por Jürgen (~19:30 Lima, nota de la card l2g9):** el import NO acepta nada de Grupos: ni las subcategorías del puente (préstamo a grupos, cobro, liquidaciones, saldos iniciales de grupo) ni la categoría «Grupos». Esas filas se saltan y salen en «filas que no entraron» con su motivo; Grupos tendrá su propia importación. Las transferencias entre cuentas y los ajustes de saldo SÍ siguen entrando (marcados para no sumar a ingresos/gastos).
- El PR #689 (auditoría, solo docs) está atascado en la cola por un conflicto con 2.2 en `docs/TICKETS.md`. No es tuyo: no lo toques.

/cerrar-total

## Paso 0 (Frank, 2026-10-29, auto-contestado salvo el límite de cuentas)

1. **Base**: la rama nace de `origin/2.2` y lleva mergeada `encargo/2026-10-29-import-transferencias-rollback` (#691, en cola): reutiliza `systemAdjustmentType(for:)` e `importAndSave`. Cuando #691 entre, el diff del PR se queda solo con lo de esta sesión.
2. **Un lector y un validador**: `ImportFileReader` lee CSV y Excel a una tabla (`RawImportRow` + columnas ignoradas) por NOMBRE de columna; las cuatro rutas públicas son envoltorios de un único `runImport` que valida en un sitio. Cabecera: minúsculas, espacios fuera y espacios internos como `_`. Duplicada una columna conocida → error de archivo que la nombra. Falta una obligatoria → error que dice cuáles.
3. **Columnas conocidas sin uso** (`card`, `split_total`, `split_portion`) y desconocidas: se ignoran y la vista previa las nombra.
4. **Grupos fuera** (nota de Jürgen en l2g9): una fila cuya categoría es «Grupos»/«Cobros de grupos» o cuya subcategoría es del puente —por nombre en todos los idiomas, antes de resolver nada, y además si lo resuelto es `isSystem`— no entra y sale en «filas que no entraron» con su motivo; la vista previa da el recuento. Tras la review, también las filas de la cuenta interna de Grupos («Grupos PEN», «Groups USD (Yala)»… en los 16 idiomas), que llevan la categoría real del gasto. `split_total` relleno NO es señal: en el archivo de Jürgen marca 28 filas de cuentas reales.
5. **Montos**: separador decimal por ARCHIVO con las celdas que lo delatan (dos separadores distintos, un grupo de miles repetido, decimales ≠ 3 cifras). Una celda que no cabe en la convención del archivo se lee por su propia evidencia. «1,500»/«1.500» sin pistas en el archivo entra con la lectura de miles (decimal si la moneda tiene 3 decimales) y sale como **dudosa** en la vista previa con la lectura. Las celdas numéricas de Excel no pasan por la convención. «−» (U+2212), «–» y «—» cuentan como signo.
6. **Cuenta por fila**: por nombre, sin distinguir mayúsculas, tildes ni espacios (las tildes, tras la review). Con varias del mismo nombre gana la de la moneda de la fila; si es una tarjeta con líneas, la línea de esa moneda. Una existente en otra moneda sin línea → fila fuera («está en X, la cuenta es en Y»). Archivada o de Grupos → fila fuera. Dos activas iguales en la misma moneda → fila fuera (ambigua). Una cuenta nueva toma la moneda de su primera fila (sus filas en otra moneda quedan fuera) y saldo inicial cero (sin movimiento de saldo inicial). Columna presente pero celda vacía → esa fila queda fuera con su motivo. Columna sin ningún valor → flujo de hoy.
7. **Límite Free (4 cuentas) — decisión de Jürgen (20:10 Lima)**: respetar el límite y que la persona elija en la vista previa qué cuentas nuevas se crean; si no, pedir Pro. Implementado: sin Pro y con más cuentas nuevas que huecos, la vista previa lista las nuevas con su recuento, preselecciona las de más filas hasta llenar los huecos, deja cambiarlas y ofrece «Hazte Pro»; las filas de las no elegidas salen como no importadas con el motivo.
8. **Sin cambio de esquema SwiftData**: H7 no lo necesita (cuentas normales).
9. **Fuera**: tandas 2.4 (duplicados, deshacer, fechas por archivo, codificaciones, hilo principal), `marketing/` y `Web/`.
10. **Review adversarial (dos lentes) — arreglado**: cuenta de Grupos; filas futuras antes de crear nada; cuenta y elección resueltas antes de crear categorías o etiquetas; Pro activado fuera de la hoja; accesibilidad de la elección; una celda ambigua sale dudosa si el archivo se contradice o si leída como decimal pasa de los decimales de la moneda; «$.50» (0,50, no 50); paréntesis con el símbolo fuera; «1.500,–» sin céntimos; agrupación india; letras entre cifras («1.5E3» texto) = importe inválido; BOM delante de cabecera entre comillas; fila CSV con celdas de menos = error de columnas (como antes); hojas de Excel en orden de pestañas y aviso de las otras hojas con movimientos. **Queda fuera (2.4)**: comilla suelta que se traga filas (H13), número de fila desplazado por líneas en blanco del CSV, texto enriquecido dentro de una celda en línea, DR/CR.
