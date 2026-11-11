---
id: archiving-exclusion-open-decisions
status: done
priority: medium
area: "accounts, panel, subscription"
created: 2026-10-03
updated: 2026-11-11
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

## Pregunta para Jürgen (triage 2026-10-08)

Con la respuesta al punto 1 se cierran casi solas la 2 y la 3.

- **A.** Archivar quita la cuenta del saldo y del carrusel, pero conserva su historial en Registros y Estadísticas. «Archivada» deja de sumar por sí sola, y archivar deja de encender «Excluir». El downgrade y las archivadas de antes del 03-oct quedan coherentes sin migrar nada.
- **B.** Archivar excluye de todo (lo que hace hoy el formulario). El downgrade también excluye, y al volver a Pro re-incluye las suyas. Se migran las archivadas viejas.
- **C.** Dejarlo como está.

**Recomendación: A.** Una tarjeta cerrada no debería borrar «Gastos 2025», y A no mueve datos de nadie en silencio. Con A la prioridad es `medium`.

## Medido en 2.1 (triage 2026-10-08)

- `DowngradeResolutionSheet.archiveExcessItems` (`Yala/App/Views/Subscription/DowngradeResolutionSheet.swift:313-318`) sigue archivando sin excluir.
- Registros sigue descartando las cuentas excluidas (`Yala/App/ViewModels/RecordsViewModel.swift:290`, `:354`). No hay migración de las archivadas de antes del 03-oct.

Triage 2026-10-08: abierto · medium → medium · las tres preguntas siguen sin respuesta; el downgrade archiva sin excluir (DowngradeResolutionSheet.swift:313) y Registros oculta las excluidas.

## Hecho (2026-11-11, decisión 6 de la revisión 2.3: opción A, adelantada de 2.4)

Archivar saca la cuenta del saldo y conserva su historial. Las tres preguntas quedan contestadas sin migrar datos:

1. **Archivar ya no enciende «Excluir de las estadísticas»** (formulario y líneas de la tarjeta). Una cuenta archivada
   deja de sumar en el saldo (cifra, curva, «en N cuentas», Distribución, widgets, aviso de informe, Yala IA y el
   conector), y sus gastos e ingresos siguen en Registros, el Panel y Estadísticas. Con la cuenta archivada el
   formulario no enseña «Excluir» y avisa de lo que pasa (16 idiomas).
2. **El downgrade** archiva sin excluir, como antes: esas cuentas dejan de sumar y su historial sigue.
3. **Las archivadas de antes**: las archivadas sin excluir dejan de sumar; las que se archivaron con «Excluir»
   encendido (del 2026-10-03 a hoy, también en 2.1) vuelven a enseñar su historial sin tocar el dato.

Las dos reglas viven en `AccountScopeLogic` (`sumsInBalance` y `keepsHistory`) y en `.claude/rules/session-filters.md`.
Las cuentas sistema de Grupos que archiva la propia app siguen sumando (no son un archivado de la persona).
Pruebas: `ArchivedAccountKeepsHistoryTests`, `AccountScopeLogicTests`, XCUITest `ArchivedAccountKeepsHistoryUITests`
(rojo en la base: aviso viejo, «Excluir» encendido, Panel en «Salió S/ 0.00» y Taxi fuera de Registros). Review
adversarial con tres lentes. QA en el simulador por Frank; nada que pruebe Jürgen a mano.
