# Rediseñar la hoja de la cuenta eliminada (mover o borrar sus movimientos) con la propuesta A

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `hoja-cuenta-eliminada` · Sesión cola **S22** · al cerrar → **S23**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/hoja-cuenta-eliminada-diseno-rd7z.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Saldo «antes → después»**: lo calcula el servicio repitiendo lo que hace `move` sin escribir (transferencias con la pareja en el destino se quitan enteras; las filas que `rowConverts` marca se reexpresan con la tasa de SU fecha vía `convertChecked`, sin red). Si alguna tasa no es exacta, la cifra lleva «≈». La suma pura va en `AccountRemovalLogic.balanceAfterMove`. Test oráculo: la previsión coincide con el saldo real tras `move`.
2. **Cabecera**: icono de la cuenta + nombre + «N registros · saldo». Los otros recuentos (programados, favoritos, borradores, presupuestos) no desaparecen: una línea secundaria debajo, solo si hay alguno. Con modo «solo gastos» no se pintan saldos (como la lista de cuentas).
3. **Destino**: dentro de la tarjeta Mover, fila «A <cuenta> · Cambiar ›» con id `account_removal_destination_<nombre>` y rasgo seleccionado; abre una hoja pequeña (`[.medium, .large]`) con la lista de cuentas (mismos ids por fila, las bloqueadas por divisa apagadas con su motivo).
4. **Id del recuento**: `account_removal_count_records` pasa a la línea «N registros · saldo» de la cabecera; el UITest comprueba que empieza por «2 ».
5. **Avisos**: una línea cada uno bajo su tarjeta (los de mover bajo Mover, los de borrar bajo Borrar cuando está elegida), en vez de un párrafo en el pie.
6. **Botón**: «Mover y eliminar «X»» (clave nueva con el nombre) / «Borrar y eliminar la cuenta» (la de hoy).
7. **Claves que quedan sin uso** (`intro`, `choiceHeader`, `moveAction` y `title`: la barra pasa a «Eliminar cuenta» y el nombre va en la cabecera; `countRecords` y `destinationHeader` se quedan porque los usa la hoja de «Movimientos sin cuenta»): se retiran de los 16 idiomas para no dejar texto muerto.
8. **`OrphanedRecordsSheet` no cambia** (asumido en la card).
9. **Review adversarial**: no — es UI sobre reglas que no cambian; el único cálculo nuevo es de lectura y lo fija un test contra `move`.
