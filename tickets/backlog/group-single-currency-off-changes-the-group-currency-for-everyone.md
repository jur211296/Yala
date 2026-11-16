---
id: group-single-currency-off-changes-the-group-currency-for-everyone
status: backlog
priority: medium
area: groups, currency
created: 2026-11-09
updated: 2026-11-09
source: revisión por vistas 2.3, zona 37 (docs/ux/revision-vistas-2.3/37-grupos/, hallazgos secundarios); consolidación de necesarias 2.3
---

# Decidir: apagar «Ver las deudas en una sola moneda» cambia la moneda del grupo para todos, sin preguntar

**Es una decisión de producto.** Al apagar el interruptor en Ajustes del grupo, la app pone como moneda del grupo la
moneda por defecto de quien lo apaga (`group.currencyCode = appPreferences.defaultCurrencyCode`), y ese cambio llega a
todos los miembros. No hay aviso ni confirmación. Leído en `Yala/App/Views/Groups/GroupSettingsView.swift:460-472` el
2026-11-09; la revisión de Grupos lo anotó desde el código, sin reproducirlo con dos teléfonos.

## Qué hay que decidir

A) Al apagarlo, la moneda del grupo se queda como estaba.
B) Se pregunta antes, diciendo que el cambio es para todos.
C) Se deja como está.

Sale de la consolidación de necesarias 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`,
decisión 3). Toca datos compartidos de un grupo: el arreglo que se elija pide review adversarial.
