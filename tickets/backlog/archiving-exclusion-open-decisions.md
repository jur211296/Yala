---
id: archiving-exclusion-open-decisions
status: backlog
priority: medium
area: "accounts, panel, subscription"
created: 2026-10-03
updated: 2026-10-03
source: hallazgos de archived-accounts-still-count-in-the-panel-total, 2026-10-03
---

# Archivar y excluir: tres decisiones que quedaron para Jürgen

Desde el 2026-10-03, archivar una cuenta **desde su formulario** enciende «Excluir de las estadísticas» y lo avisa.
Tres cosas quedaron fuera a propósito, porque mueven datos o visibilidad sin que el usuario lo pida.

## 1. Excluir también oculta el historial en Registros

Medido: `RecordsViewModel` descarta del feed las transacciones de cuentas excluidas, y Estadísticas deja de contar
sus ingresos y gastos **de todos los periodos**, también los pasados. Así que archivar una tarjeta cerrada hace
desaparecer de Registros sus movimientos y baja «Gastos 2025». El aviso nuevo ya lo dice. Pregunta: ¿es lo que
quieres, o archivar debería excluir solo del saldo y conservar el historial?

## 2. El downgrade de plan archiva sin excluir

`DowngradeResolutionSheet.archiveExcessItems` archiva las cuentas que el usuario no elige conservar y **no** las
excluye. Se dejó así porque excluirlas ocultaría su historial (punto 1) y al volver a Pro nada las re-incluye.
Consecuencia: esas cuentas siguen sumando al saldo del Panel y entran en «en N cuentas» sin verse en el carrusel.

## 3. Las cuentas archivadas antes del 2026-10-03 no se migraron

Si no estaban excluidas, siguen sumando y contando (coherentes entre sí, pero invisibles en el carrusel). Una
migración que las excluya movería datos de todos los usuarios en silencio.

## Qué hace falta

Una respuesta por punto. Con la del 1 se cierran casi solas la 2 y la 3.
