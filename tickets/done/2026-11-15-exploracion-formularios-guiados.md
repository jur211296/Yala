---
id: 2026-11-15-exploracion-formularios-guiados
status: done
priority: medium
area: ux
created: 2026-11-15
updated: 2026-11-15
source: encargo 2026-11-15-exploracion-formularios-guiados (Jürgen, 15-nov)
---
# Explorar qué formularios de Yala se convierten en flujos guiados

Jürgen (15-nov): los formularios son largos y confusos. Quiere ir pasando los flujos habituales a algo como el
onboarding de Primeros pasos (una pregunta por pantalla, tarjetas, chips, la tarjeta que se llena arriba), con
«Usar formulario» arriba para quien prefiera el de siempre. Esta sesión es **solo exploración y maqueta**: no toca
el código de la app.

## Paso 0 — decisiones (resueltas en autónomo, sesión nocturna)

| Pregunta | Decisión | Por qué |
|---|---|---|
| ¿Dónde se guardan los comentarios de Jürgen? | En el navegador (`localStorage`) + botón «Copiar todos los comentarios». | Lo fija el encargo. Una base compartida añadiría una pieza que puede fallar y nadie la pidió. |
| ¿Cuántas maquetas? | Una por cada flujo marcado «Convertir». Los «No» no llevan maqueta. | El encargo pide «una maqueta por flujo recomendado». |
| ¿Se quita algún campo? | Ninguno: cada campo del formulario actual tiene su pregunta, aunque casi siempre se salte. | «No quites ninguna, Jürgen decide qué quitar». |
| ¿Dónde va «Usar formulario»? | Botón en la barra de arriba, en todas las preguntas; lo respondido pasa al formulario. | Cambiar de idea no debe costar empezar de cero. |
| ¿Confirmación antes de guardar? | Sí, «Revisa antes de crear» con cada respuesta y «Cambiar» al lado. | La pide el encargo; Primeros pasos va directo a «¡Lista!». |
| ¿Tema? | Solo oscuro. | «En modo oscuro como la app». |
| ¿PR o directo a 2.3? | PR a 2.3 en cola de auto-merge. | El diff es solo docs y tickets, pero el encargo pide PR. |
| Motor de guiados de Yala IA | Su encargo no está en esta máquina. Se asume que generaliza las piezas de Primeros pasos a pasos declarados como datos. | Las maquetas se escriben como datos (pregunta, tipo, por defecto, cuándo se salta) para que el mismo motor las lea. |

## Entregable

- Artifact interactivo con el inventario, la recomendación y una maqueta comentable por flujo:
  https://claude.ai/artifact/NezFuZTGRzURxftRovDPoD
- Fuente: `docs/exploracion/formularios-guiados/index.html`, y el inventario en texto en
  `docs/exploracion/formularios-guiados/inventario.md`.

## Resultado

- **Inventario:** 21 formularios de crear y editar. «Metas» no existe en Yala.
- **Convertir, en este orden:** cuenta, pago planificado, presupuesto, grupo, favorito, deuda de antes (saldo inicial
  de un miembro) y categoría. Cada uno tiene su maqueta con todas las preguntas, la confirmación y el éxito.
- **Más adelante:** gasto de grupo (pulir antes el formulario) y corregir el saldo de una cuenta.
- **Se quedan como formulario:** nuevo registro, editar registro, saldar, presupuesto del grupo, reflejar en tus
  cuentas, «Tu parte» y «Mi parte», etiqueta, recordatorio, línea del flujo de caja, hacer recurrente, propuesta de
  pago que se repite y guardar como favorito.
- **Siguiente paso:** Jürgen comenta en el artifact y pega los comentarios («Copiar todos los comentarios»); la
  implementación empieza por el motor común con pago y presupuesto, coordinada con la sesión de guiados de Yala IA.

## Encontrado (sin tocar)

- Una cuenta nueva arranca siempre en soles (`AccountFormViewModel.selectedCurrency = .pen`), no en la moneda
  principal.
- `AccountFormView.colorSection` existe y el `body` no la pinta: el color de la cuenta no se puede elegir.
- El editor de pagos calcula las próximas fechas (`updatePreviewDates`) y ninguna vista las pinta.
- `SaveAsFavoriteSheet` no avisa si falla al guardar (solo un `print` en DEBUG).
- La línea personalizada del flujo de caja acepta monto 0 o texto no numérico.
- `TransactionFormRow.swift` no tiene usos.
