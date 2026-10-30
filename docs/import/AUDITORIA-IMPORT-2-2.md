# Auditoría del import de Yala (CSV y Excel) — 2.2

> Sesión exploratoria S27j, 2026-10-29. Árbol medido: `origin/2.2` en `e6e5ab064`. Sin cambios de código.
> Card: `tablero-explorar-todo-lo-que-mejorariamos-del-im-fb91`.

## En una frase

Hoy el import sirve para un archivo hecho a mano con la plantilla de Yala y una cuenta por moneda. Fuera de eso
falla de tres formas: **rechaza** archivos razonables (el propio export de Yala, el caso real de Jürgen), **acierta
mal en silencio** (montos con separador de miles, el signo «−», transferencias en cinco idiomas) y **no deja
volver atrás** (sin Deshacer y sin aviso de duplicados).

## Cómo se midió

- **Leído en el código**, con archivo y línea de este árbol.
- **Medido** con las funciones de montos, fechas y filas del import copiadas tal cual a un programa aparte (Swift, sin la
  app). Lo marco como *medido*.
- **El caso real** (`Yala_Registros_27-oct-2026_con-transferencias.xlsx`) estaba en las Descargas de este Mac. Lo leí
  fuera del repo y aquí solo van cifras agregadas: 2.749 filas, 10 columnas, 7 cuentas, 3 monedas, 50 patas de
  transferencia, 28 filas con reparto de grupo, 116 con etiquetas. Ningún dato suyo entra en el repo.
- **Sin compilar ni simulador.** Lo que pide un tiempo (rendimiento, modo nube) queda como *inferido*, y su ticket empieza
  por medirlo.

## Qué le pasa hoy al caso real

1. **No se abre.** Lo escribió openpyxl con el texto dentro de cada celda (`inlineStr`), sin la tabla de textos
   compartidos, y el lector de Excel exige esa tabla antes de mirar nada: «No pudimos abrir el archivo de Excel» (H3).
2. Guardado otra vez desde Excel, **lo rechaza la cabecera**: trae `account`, `split_total` y `split_portion` (H4).
3. Quitando esas columnas a mano, entraría con **las 7 cuentas fundidas en 3** (una por moneda) (H7).
4. De las 50 patas de transferencia, la heurística emparejaría **17 pares**. Las otras **16 patas quedan sueltas**, y
   todas caen en días con patas en otra moneda: son transferencias con cambio de moneda, que hoy nunca se emparejan (H9).
   Ninguno de los 17 pares tiene las dos patas en la misma cuenta, así que en este archivo la heurística no se equivoca;
   solo se queda corta.
5. El reparto de las 28 filas de grupo se pierde: `split_portion` viene como texto («50 %», «1/3») (H5, H18).

## Hallazgos priorizados

Severidad con `docs/criterios-de-version.md` §2: una cifra financiera equivocada sube un escalón. Versión propuesta:
**2.2** si es un fallo alto (bloquea cualquier salida) o barato; **2.4** para el resto, que es el tema «Tu mes real ·
empezar con datos» donde el roadmap ya pone el import (`docs/ROADMAP.md`, eje 2, fila «Importar»). Ninguno encaja en el
tema de 2.3. La versión la decide Jürgen.

| # | Hallazgo | Qué ve la persona | Sev. | Versión | Ticket | Card |
|---|---|---|---|---|---|---|
| H1 | Montos: el separador de miles se lee como decimal y el «−» tipográfico se pierde | «1,500» entra como 1,50; «1.234.567» como 1,23; «−12,50» entra como ingreso | alta | **2.2** | `import-reads-thousands-as-decimals-and-drops-the-unicode-minus` | `jvgc` |
| H2 | La subcategoría de transferencias no se reconoce en japonés, neerlandés, polaco, chino y portugués | Las transferencias importadas cuentan como gasto e ingreso | alta | **2.2** | `transfer-subcategory-unrecognized-in-five-languages` | `ynsq` |
| H3 | Un Excel con el texto dentro de la celda no se abre | «No pudimos abrir el archivo», también con el caso real | media | **2.2** (barata) | `xlsx-with-inline-text-cannot-be-opened` | `7wh5` |
| H4 | Cabecera rígida: columnas fijas, en orden fijo | El archivo que exporta Yala no se puede volver a importar | media | **2.2** (barata) | `exported-csv-cannot-be-imported-back` (card `mnox`, ampliado) | `mnox` |
| H5 | Las patas del puente de Grupos se reimportan como transferencias | Al reimportar, gastos de grupo salen de Estadísticas y se emparejan como transferencias | alta al entrar H4 | **2.2** con H4 | `reimported-group-legs-become-transfers` | `l2g9` |
| H6 | Si el import falla al final, lo insertado se queda en memoria sin deshacer | Categorías o registros a medias que aparecen tras otro guardado | baja | **2.2** (barata) | `import-failure-leaves-unsaved-inserts-in-the-main-context` | `a27x` |
| H7 | No hay columna de cuenta ni se puede crear una cuenta desde el import | Todo cae en una cuenta por moneda; con un archivo de una moneda sin cuenta, error | media | 2.4 | `import-account-column-by-name` | `34qe` |
| H8 | El export no dice qué tipo de registro es cada fila ni cuál es su pareja | El saldo inicial no entra; las transferencias vuelven sin pareja | media | 2.4 | `export-import-carry-record-kind-and-transfer-pair` | `lrjn` |
| H9 | La heurística de transferencias no mira la cuenta ni el cambio de moneda | Transferencias con cambio de moneda quedan sueltas; dos del mismo importe el mismo día también | media | 2.4 | `import-transfer-pairing-ignores-accounts-and-currency-changes` | `cbjx` |
| H10 | La fecha se adivina fila a fila | «03/04/2026» de un banco de EE. UU. entra el 3 de abril; «10/27/26» entra en el año 26 | media | 2.4 | `import-guesses-date-order-per-row` | `wsgn` |
| H11 | Reimportar el mismo archivo lo duplica todo | Saldos y gastos al doble, sin aviso | media | 2.4 | `import-has-no-duplicate-detection` | `kfma` |
| H12 | Un import no se puede deshacer | Para quitar 3.000 filas mal importadas hay que borrarlas a mano | media | 2.4 | `import-cannot-be-undone` | `xs1e` |
| H13 | Una comilla suelta se traga filas; líneas sin separador se saltan sin decirlo; solo UTF-8 | Filas que desaparecen dentro de una nota; un CSV de Excel en Windows no se lee | media | 2.4 | `csv-import-silently-swallows-rows-and-only-reads-utf8` | `6gh7` |
| H14 | El import corre dos veces y en el hilo principal | Con miles de filas, la app se congela al previsualizar y otra vez al importar (inferido) | media | 2.4 | `import-runs-twice-on-the-main-thread` | `rh1i` |
| H15 | Un import de miles de filas en modo nube no está medido | Desconocido: subida, cola y Deshacer futuro sin medir | media | 2.4 | `import-of-thousands-of-rows-in-cloud-mode-is-unmeasured` | `2u45` |
| H16 | Categorías, subcategorías y etiquetas casan solo por nombre exacto | «comida» no es «Comida»: fila rechazada o categoría duplicada | baja | 2.4 | `import-name-matching-is-exact` | `tbws` |
| H17 | La vista previa no dice qué va a crear | Categorías, etiquetas y transferencias sueltas aparecen después, sin aviso | baja | 2.4 | `import-preview-hides-what-it-will-create` | `1j8u` |
| H18 | Hora, tasa de cambio manual y naturaleza no viajan en el export | Tras la ida y vuelta, otra conversión y otra clasificación | baja | 2.4 | `export-import-lose-time-manual-rate-and-nature` | `xx0g` |
| H19 | El Excel exportado guarda importes y fechas como texto | En Excel no se pueden sumar los importes sin convertirlos | muy baja | 2.4 | `exported-xlsx-stores-amounts-and-dates-as-text` | `a90i` |

**Para 2.2 salen seis**: H1, H2, H3, H4, H5 y H6. H4 y H5 van juntos: leer columnas por nombre hace importables los
archivos exportados, y sin H5 eso abre un error de cifras que hoy no se alcanza. **Para 2.4, trece.**

---

## H1 · Montos: miles leídos como decimales, y el «−» perdido

**Evidencia.** `TransactionCSVImportService.swift:840-884` (`normalizeAmountString`) decide el separador decimal con el
último `,` o `.`: si solo hay uno, es el decimal. Después `MoneyParsing.swift:56-57` filtra todo lo que no sea
`0-9 . ,`, y con eso desaparece el signo U+2212 («−»), que no es el guion de `:44`.

**Medido** (las dos funciones copiadas tal cual):

| En el archivo | Entra como |
|---|---|
| `1,500` | 1,5 |
| `1.500` | 1,5 |
| `-1,234` | −1,234 |
| `1.234.567` | 1,234 |
| `−12.50` (signo tipográfico) | **+12,5** |
| `1.500,00`, `1,500.00`, `1 500,00`, `(12.50)`, `S/ 12.50` | bien |

**Impacto.** Una cifra equivocada en silencio: ni la vista previa ni el resumen avisan. Un extracto de banco con miles
sin decimales («S/ 1,500») o con el signo de Numbers o de algunas webs bancarias entra mal. Yala exporta sin separador de
miles (`TransactionsExportService.swift:449-454`), así que la ida y vuelta propia no lo sufre.

**Propuesta.** Decidir el separador **por archivo**, no por celda: si alguna fila trae decimales con un separador, ése es
el decimal en todo el archivo. Un `1,500` o `1.500` sin más pistas no se adivina: va como fila dudosa en la vista previa,
con la lectura propuesta. El «−» (y el «–» de algunas exportaciones) cuenta como signo. Tests con la tabla de arriba.

## H2 · Transferencias que no se reconocen en cinco idiomas

**Evidencia.** El import marca una fila como transferencia si su subcategoría es «de sistema»
(`TransactionCSVImportService.swift:220-228`, repetido en `:1153-1161`, `:1540-1547` y `:1709-1716`), y eso se decide por
nombre contra `Subcategory.transferNames` (`Subcategory.swift:115-123`). La lista tiene es, en, de, fr, it y un
«Transferencia entre contas» sin tilde. Faltan:

- El nombre que usa la app al crear una transferencia (`L10n.Transfer.categoryName`, `NewTransactionViewModel.swift:1107`
  y `:1157`, creada **sin** `isSystem`): «Transferência entre contas» (pt, pt-BR, pt-PT), «口座間振替» (ja),
  «Overschrijving tussen rekeningen» (nl), «Transfer między kontami» (pl), «账户间转账» (zh-Hans).
- El nombre de la subcategoría sembrada (`CategorySeed.swift:343-360`, `subcategory.accountTransfer`): «Account
  transfer» (en), «Kontoüberweisung» (de) y los mismos de ja, nl, zh y pt. Tampoco llevan `isSystem`.

Además, el import distingue «ajuste» de «transferencia» comparando con el texto del idioma **actual**
(`L10n.Subcategory.balanceAdjustment`, `:222`): con los datos sembrados en español y el teléfono en inglés, un «Ajustes
de saldo» se marca como transferencia.

**Impacto.** Con Yala en esos idiomas, importar un archivo con transferencias las suma a gastos e ingresos y, en el caso
del ajuste, cambia su tipo. Cifra equivocada en silencio.

**Propuesta.** Reconocer la subcategoría por papel y no por texto: completar las listas con todos los nombres de
`transfer.categoryName` y `subcategory.accountTransfer` de los 16 idiomas como arreglo inmediato (barato), y decidir el
tipo de ajuste con `balanceAdjustmentNames` (todos los idiomas), no con el texto actual. Un test de paridad que recorra
los `.lproj` y falle si un idioma nuevo trae un nombre que la lista no tiene. El arreglo de fondo (marcar esas
subcategorías con `isSystem` o con un papel estable) toca esquema y va aparte. **Fuera del import** la misma lista
decide qué subcategorías salen de los selectores y de «Top categorías» (`Subcategory.swift:128-136`); el ticket lo cita
pero no lo amplía.

## H3 · Un Excel con el texto dentro de la celda no se abre

**Evidencia.** `XLSXReader.swift:61-63` exige la tabla de textos compartidos (`sharedStrings.xml`) y, si no está,
lanza «No pudimos abrir el archivo de Excel». La cabecera (`:79-81`) solo lee de esa tabla, aunque las filas ya saben
leer el texto en línea (`:199-200`). **Medido en el caso real**: no tiene esa tabla; todas sus celdas son `inlineStr`
(lo escribió openpyxl). Lo mismo pasa con otros generadores de Excel de scripts y de algunas exportaciones.

Dos limitaciones vecinas: solo se lee la **primera hoja** (`:66-71`), y la conversión del número de fecha de Excel solo
se aplica a la **columna 0** (`:210-216`), que deja de ser la fecha en cuanto las columnas vayan por nombre (H4).

**Propuesta.** Sin tabla compartida, seguir con una vacía y leer el texto en línea también en la cabecera. Convertir la
fecha en la columna que se llame `date`. Si el libro tiene varias hojas, usar la primera que tenga una cabecera
reconocible. Test con un `.xlsx` de `inlineStr` generado en el propio test.

## H4 · Cabecera rígida: el export de Yala no vuelve a entrar

**Evidencia.** CSV: `TransactionCSVImportService.swift:317-331` y su gemelo multidivisa `:1240-1252`. Excel:
`XLSXReader.swift:84-97`. Solo valen cuatro cabeceras exactas: `date,amount,currency,category,subcategory` con `tags`
y/o `note` al final. El export escribe por defecto `date,amount,currency,account,category,subcategory,tags,note,
split_total,split_portion` (`TransactionsExportModels.swift:86-118`, `TransactionsExportService.swift:436-437`), y además
deja reordenar y quitar columnas. El mensaje de error dice qué columnas hacen falta, pero no cuál sobra.

Detalle de mantenimiento: la validación de filas existe **cuatro veces** (CSV simple `:358-538`, CSV multidivisa
`:1265-1413`, y las dos de Excel vía `validateAndCreateDraft` `:649-735`). Cualquier arreglo de H1, H2, H5 o H10 hay que
hacerlo en cuatro sitios mientras siga así.

**Propuesta.** Leer la cabecera **por nombre** (mayúsculas y espacios aparte), en cualquier orden; exigir solo `date`,
`amount`, `currency`, `category` y `subcategory`; ignorar las desconocidas y decirlo en la vista previa («la columna
`card` no se usa»). Las cuatro rutas pasan a leer a un `RawImportRow` común y a validar en un solo sitio. Si falta una
obligatoria, el error dice cuál. Test de ida y vuelta: exportar con las columnas por defecto e importar ese archivo.
**Va con H5**, que es lo que hace segura la ida y vuelta.

## H5 · Las patas del puente de Grupos se reimportan como transferencias

**Evidencia.** El import trata como transferencia toda subcategoría con `isAnySystem` que no sea el ajuste
(`TransactionCSVImportService.swift:220-228`). Las subcategorías del puente de Grupos («Préstamo a grupos», «Cobro de
préstamo», «Liquidación enviada»…) son `isSystem = true` (`CategorySeed.swift:707-734`,
`GroupBridgeSystemEntities.swift:23-49`). El export las escribe como cualquier fila, y el resolutor las encuentra por
nombre (`CategoryImportHelper.swift:115-122`). El caso real trae una.

**Impacto (inferido del código, hoy inalcanzable sin H4).** Al reimportar, esas filas entran en una cuenta real, con
tipo «transferencia», sin enlace al gasto del grupo: salen de gastos e ingresos y la heurística puede emparejarlas como
transferencia. Además el reparto (`split_total`, `split_portion`) se pierde, porque el export lo escribe como texto para
leer («50 %», «1/3», `TransactionsExportService.swift:697-716`).

**Propuesta.** El import no crea patas del puente: una fila con subcategoría del puente se deja fuera y la vista previa
lo dice («2 movimientos de grupos no se importan: se recrean desde el grupo»). Las columnas de reparto se aceptan y se
ignoran. Importar un grupo de verdad es otra cosa (`3gsu`).

## H6 · Un fallo al final deja lo insertado sin deshacer

**Evidencia.** El import inserta categorías, etiquetas y registros en el contexto principal y luego guarda
(`ImportIntroSheet.swift:684-707`, `:797-821`). Si algo lanza después de insertar (el `save`, o un error de archivo en la
ruta multidivisa), el `catch` (`:760-777`, `:870-887`) cierra la hoja **sin `rollback()`**: lo insertado queda en el
contexto y lo guarda el siguiente `save` de cualquier pantalla. La vista previa sí hace `rollback` (`ImportPreviewService.swift:90`).

**Propuesta.** `modelContext.rollback()` en los dos `catch`. Barato.

## H7 · No hay columna de cuenta

**Evidencia.** Las cuatro rutas reciben una cuenta (`importCSV`/`importXLSX` `:154`, `:1447`) o un mapa moneda → cuenta
(`:1089`, `:1608`). Una moneda solo puede ir a una cuenta. Si el archivo es de una moneda sin cuenta, el error es «no
hay cuentas en PEN» y no se ofrece crearla (`ImportIntroSheet.swift:538-548`; el selector dice «crea una cuenta antes»,
`ImportAccountPickerSheet.swift:24-26`).

**Impacto.** El caso real tiene 7 cuentas en 3 monedas: entrarían fundidas en 3, con los saldos de cada cuenta mal.

**Propuesta.** Columna `account` por nombre (tras H4). Una cuenta que no existe se propone crear en la vista previa, con
la moneda de sus filas y saldo inicial cero. Si el nombre es el de una tarjeta con líneas por moneda, va a la línea de la
moneda de la fila. Sin columna, el flujo de hoy. Cuentas archivadas y la de Grupos siguen fuera
(`ImportAccountChoiceLogic.swift:16-22`).

## H8 · El tipo de registro y la pareja de transferencia no viajan

**Evidencia.** El export no escribe ni el tipo (`balanceAdjustmentType`: transferencia, ajuste, saldo inicial) ni la
pareja (`transferPairID`), que solo viaja en la sincronización con la nube (`EntityEmissionMap.swift:206`, `:233`). El
saldo inicial se crea **sin categoría** (`InitialBalanceService.swift:116-126`), así que se exporta con la categoría vacía
(`TransactionsExportService.swift:482-483`) y al reimportar cae como fila mala, «categoría vacía» (`:477-480`). Inferido
del código; no lo reproduje en la app.

**Propuesta.** Dos columnas nuevas en el export, opcionales en el import: `kind` (`expense`, `income`, `transfer`,
`adjustment`, `initial_balance`) y `transfer_id`. Con `transfer_id`, las dos patas se emparejan exactas, también con
cambio de moneda. Con `initial_balance`, la fila fija el saldo inicial de la cuenta en vez de crear un movimiento
(relacionado: `sqcy`, la tasa del saldo inicial al moverse).

## H9 · La heurística de transferencias se queda corta

**Evidencia.** `TransferPairReconcileService.swift:95-128` agrupa por día, importe absoluto y moneda, y solo empareja
grupos de exactamente un negativo y un positivo. No mira la cuenta. El import la llama sobre lo recién creado
(`TransactionCSVImportService.swift:1760-1785`).

**Impacto.** Una transferencia con cambio de moneda (PEN → USD) nunca se empareja: **16 de las 50 patas del caso real**.
Dos transferencias del mismo importe el mismo día tampoco. Y dos patas en la misma cuenta podrían emparejarse (en el
caso real, ninguna). Una transferencia sin pareja sigue fuera de gastos e ingresos, pero borrar una pata no borra la otra
y el detalle no dice a qué cuenta fue.

**Propuesta (para archivos de fuera; los de Yala usan `transfer_id`, H8).** Exigir cuentas distintas cuando haya
columna de cuenta. Emparejar con cambio de moneda cuando en el día haya exactamente una salida y una entrada sueltas en
cuentas distintas. Con más candidatos, emparejar por cuenta y nota antes de rendirse. La vista previa dice cuántas
quedan sueltas.

## H10 · La fecha se adivina fila a fila

**Evidencia.** `TransactionCSVImportService.swift:745-817`. Con `/`, siempre día/mes; si falla, prueba formatos con
`-` y `.` que el formateador acepta también con `/`. Un año de dos cifras suma 2000 solo en la ruta de `/`.

**Medido:** `03/04/2026` → 3 de abril (un banco de EE. UU. quiso decir 4 de marzo); `03/15/2026` → 15 de marzo (bien,
por el respaldo); `10/27/26` → **27-oct del año 26**; `27/10/99` → 2099 y se descarta como futura; `2026-10-27T14:30`
→ sin hora. Y la fecha se guarda a las 12:00 UTC, que en Nueva Zelanda en horario de verano (UTC+13) es **el día
siguiente**: `2026-10-27` se ve el 28.

Vecino: la plantilla escribe la fecha con el calendario del teléfono (`ImportIntroSheet.swift:426-429`, sin
`calendar` ni `locale`); con el calendario budista sale el año 2569 y todas sus filas se descartan como futuras.

**Propuesta.** Decidir el orden día/mes **por archivo** (si alguna fila trae un primer número mayor que 12, día/mes; si
el segundo, mes/día; si nada lo decide, el orden del idioma del teléfono, y la vista previa lo enseña). Años de dos
cifras en todas las rutas. Guardar la fecha como mediodía **local**. Plantilla con calendario gregoriano.

## H11 · Reimportar duplica

**Evidencia.** Ninguna de las cuatro rutas mira si un movimiento ya existe; no hay marca de origen en `TransactionItem`.

**Propuesta.** Huella por fila (fecha, importe, moneda, cuenta, nota) contra lo que ya hay y dentro del archivo. La vista
previa dice «N parecen ya importados» y por defecto los salta, con opción de importarlos igual.

## H12 · Un import no se puede deshacer

**Evidencia.** Tras guardar, solo queda el aviso de resultado (`ProfileView.swift:905-937`). Ningún registro sabe de qué
import vino.

**Propuesta.** Opción barata: guardar en el dispositivo los identificadores del último import durante 24 h y ofrecer
«Deshacer importación» en el aviso de resultado y en Ajustes › Importar; borra por el servicio de borrado de siempre,
que en modo nube emite los borrados. Opción completa: un campo `importBatchID` (cambio de esquema, entra en la ventana
de esquema de su versión). Recomiendo la barata.

## H13 · Filas que desaparecen y codificaciones que no se leen

**Evidencia y medido.**
- `splitCSVIntoRows` (`:975-1006`) abre y cierra comillas con **cualquier** `"`, también en mitad de un campo sin
  comillas. Medido: con una nota `Tele de 50" nueva`, cuatro filas se leen como dos. Como las comas de más se pegan a la
  nota (`:401-408`), las filas siguientes acaban **dentro de la nota** sin error.
- Una línea sin separador se salta sin contarla (`:372-374`), y no sale en la vista previa.
- Solo UTF-8 (`:292`, `:1032`, `:1220`). Medido: un CSV en Windows-1252 (el «CSV» por defecto de Excel en Windows) no se
  lee. El mensaje sí orienta («guárdalo como CSV UTF-8»).
- Separadores: solo `,` y `;` (`:822-831`). El tabulador no.

**Propuesta.** Comillas según RFC 4180 también al partir filas (una comilla solo abre al principio del campo, como ya
hace `splitCSVFields` en `:931-971`). Contar en la vista previa las líneas saltadas. Si UTF-8 falla, probar Windows-1252.
Detectar el tabulador.

## H14 · Dos pasadas en el hilo principal

**Evidencia.** El servicio es `@MainActor` (`:153`, `:1088`, `:1446`, `:1607`). La vista previa hace la importación
entera en un contexto aparte (`ImportPreviewService.swift:37-71`) y, al confirmar, se hace otra vez
(`ImportIntroSheet.swift:684-698`). Por fila: dos consultas de categoría y subcategoría
(`CategoryImportHelper.swift:115-122`) y, con etiquetas, una consulta de **todas** las etiquetas más una por nombre
(`TransactionCSVImportService.swift:594-616`). Al final, una consulta de **todos** los movimientos de la base
(`:235-238`).

**Impacto (inferido; no lo medí).** Con las 2.749 filas del caso real son más de 11.000 consultas en el hilo principal,
dos veces. La pantalla solo enseña «Importando» (`ImportIntroSheet.swift:675`, un retardo de 100 ms para pintar el botón).

**Propuesta.** Primero medir con 3.000 y 10.000 filas sintéticas (test de rendimiento). Después: diccionarios en memoria
para categorías y etiquetas, leer y validar fuera del hilo principal, y reutilizar lo validado en la vista previa para el
import en vez de rehacerlo.

## H15 · Modo nube con miles de filas, sin medir

**Evidencia.** El import no distingue iCloud privado de modo nube: guarda en local y lo demás lo hace la sincronización
(espejo de CloudKit, o el historial que drena `CloudSyncEngine` y proyecta `DeltaEmitter`). Un import de 3.000 filas es
un solo guardado con miles de inserciones, más categorías y etiquetas. No encontré límites ni troceo pensados para ese
caso en la subida, y no hay telemetría de cuánto tarda.

**Propuesta.** Medir en `Yala Dev` contra staging: 3.000 filas, tiempo hasta que la otra instalación las ve, tamaño de
los lotes, reintentos. Lo mismo para el Deshacer de H12, que serían 3.000 borrados. Relacionado:
`debounce-sync-imported-transactions`.

## H16 · Nombres exactos

**Evidencia.** Categorías y subcategorías: `category.name == categoryName`, `sub.name == subcategoryName`
(`CategoryImportHelper.swift:115-122`), sensible a mayúsculas y tildes. Etiquetas: `tag.name == name && tag.isActive`
(`TransactionCSVImportService.swift:610-616`): una etiqueta archivada con el mismo nombre crea otra. Y «Crear categorías
que falten» está **apagado** por defecto (`ImportIntroSheet.swift:103`), así que una fila con «comida» se rechaza.

**Propuesta.** Comparar sin mayúsculas, tildes ni espacios de más, y reutilizar la etiqueta archivada (reactivándola).
El interruptor pasa a la vista previa, con la lista de lo que crearía (H17).

## H17 · La vista previa no dice qué va a crear

**Evidencia.** `ImportPreviewLogic.swift` enseña cuántas filas, cuentas, fechas, totales, 3 filas de muestra, las filas
malas (10 con motivo) y las futuras. No dice qué categorías, subcategorías, etiquetas o cuentas va a crear, cuántas
transferencias quedan sueltas, ni las líneas saltadas (H13).

**Propuesta.** Una sección «Esto también se creará» y otra «A revisar» (transferencias sueltas, posibles duplicados de
H11, montos dudosos de H1). Es el sitio natural de las decisiones de H1, H7, H10, H11 y H16.

## H18 · Hora, tasa manual y naturaleza se pierden

**Evidencia.** El export escribe solo la fecha (`TransactionsExportService.swift:443-446`); el import, además, quita la
hora (`:749-755`). La tasa de cambio que la persona fijó a mano (`ForeignManualRateLogic`,
`NewTransactionViewModel.swift:867-874`) y el cambio de naturaleza (`needOverride`, `TransactionItem.swift:56-57`) no se
exportan: al volver, la conversión se rehace con la tasa del mercado.

**Propuesta.** Columnas opcionales `time`, `exchange_rate` y `need`. Con `exchange_rate`, el import la respeta como
manual. Baja: solo importa para una ida y vuelta exacta.

## H19 · El Excel exportado guarda importes y fechas como texto

**Evidencia.** `XLSXWriter.swift:201` y `:213`: toda celda es texto compartido (`t="s"`). Medido en el caso real (ya
reescrito): 2.742 de 2.749 importes son texto.

**Propuesta.** Importe como número y fecha como fecha de Excel. El import ya lee los dos.

---

## Lo que ya funciona y no hay que tocar

- **Vista previa antes de importar** con el mismo código que importa, en un contexto que no se guarda
  (`ImportPreviewService.swift`, L7-15).
- **Una fila mala no para el archivo**: entra lo bueno y se lista lo malo con su número de fila y un motivo en llano
  (`skippingInvalidRows`, L7-17; textos en `L10n+UXAudit22Lote7.swift`).
- **Comillas en campos** según RFC 4180, con el delimitador y saltos de línea dentro (`splitCSVFields`), y el BOM de UTF-8
  (medido: se quita solo).
- **«Transferencia entre cuentas»** saca las filas de gastos e ingresos en los idiomas que la lista reconoce (es, en
  con el nombre de la app, de, fr, it).
- **Multidivisa y tasas**: cada fila se convierte con la tasa de su día; sin tasa exacta queda provisional
  (`convertChecked`, `:187-216`) y, al terminar, se piden las tasas del rango y se reparan las provisionales
  (`ImportIntroSheet.swift:713-736` y `:826-847`).
- **Saldo inicial**: si el archivo trae movimientos más antiguos, la fecha del saldo inicial retrocede
  (`InitialBalanceService.swift:250-265`). La tasa que deja es `sqcy`.
- **Categoría por naturaleza**: con «Otros» de gasto y de ingreso, la del signo de la fila
  (`CategoryImportNatureLogic`).
- **La cuenta de Grupos y las archivadas** no se ofrecen como destino (`ImportAccountChoiceLogic.swift`).
- **«Importación completada»** ya sale tras cerrar la hoja (`ProfileView.swift:905-912`); su QA es `trc6`.

## Cobertura del encargo

| Pedido | Dónde |
|---|---|
| Cabecera rígida, export no reimportable | H4 (+ H3, H5) |
| Columna de cuenta, crearla si no existe | H7 |
| Transferencias con dos patas, cambio de moneda, columna de pareja | H8, H9 |
| Ida y vuelta export → import sin pérdida | H4, H5, H7, H8, H18, H19 |
| Columnas por nombre y en cualquier orden | H4 |
| Saldos iniciales | H8 (+ `sqcy`) |
| Multidivisa y tipos de cambio | H18; lo que funciona, arriba |
| Gastos de grupo y columnas de reparto | H5 (+ `3gsu`) |
| Etiquetas | H16 |
| Categorías que no existen | H16, H17 |
| Duplicados y reimportar | H11 |
| Vista previa | H17 |
| Errores claros por fila | Ya funciona; huecos en H4 (qué columna falta) y H13 (líneas saltadas sin contar) |
| Más de 3.000 filas | H14 |
| Fechas y decimales por país | H1, H10, H13 |
| Deshacer | H12 |
| Modo nube vs iCloud privado | H15 |

## Cards relacionadas

- `mnox` — su ticket (`exported-csv-cannot-be-imported-back`) pasa a ser H4, ampliado; card a 2.2.
- `sqcy` — la tasa del saldo inicial al moverse; la cita H8.
- `trc6` — «Importación completada»; en QA de Jürgen, no se toca.
- `36m1` — importar el estado de cuenta desde la Bienvenida; se apoya en H7 y H17.
- `3gsu` — importar un grupo de Splitwise o Tricount; H5 deja claro que el import de registros no crea grupos.
