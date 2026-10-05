---
id: accounts-settings-list-redesign
status: backlog
priority: medium
area: "accounts, settings, ui"
created: 2026-10-03
updated: 2026-10-03
source: diseño aprobado por Jürgen el 2026-10-03 (lienzo «Cuentas del Panel — propuestas», página «Rediseño de cuentas», pantallas 4 y 6)
---

# Ajustes › Cuentas: lista clara, tocar abre la vista de la cuenta, y desarchivar en lote

## La idea

Segunda entrega del rediseño de cuentas (la primera es `panel-accounts-redesign`). Diseño aprobado: https://claude.ai/artifact/LvWp7bj43PJY1S2Rin9Cu3

- **Lista**, no carrusel: aquí se gestionan muchas cuentas. Cabecera con el total («5 activas · S/ X en total»).
- Cada fila: icono de color, **nombre** (siempre; hoy sale el número de cuenta en su lugar si lo hay,
  `AccountsSettingsListView.swift:293-296`), «tipo · moneda» y, si hay número, enmascarado (`••4821`), saldo a la derecha.
- **Tocar una cuenta abre la misma vista de cuenta del Panel** (`AccountDetailSheet`) y se edita desde ahí: un solo
  sitio para ver y editar. Hoy abre el formulario directo.
- Debajo, tres filas que se tocan: **Colecciones de cuentas** (ticket `account-collections`), **Cuentas del sistema**
  (las `Grupos [moneda]` que crea Grupos) y **Archivadas**.
- **Archivadas** abre su lista con **selección en lote** al estilo de la bandeja (`InboxView`: «Cancelar» /
  «Seleccionar todo» arriba, barra abajo con «N seleccionadas» y **Desarchivar**).

## Antes de empezar

- El subtítulo de Archivadas no puede decir «no suman al total» sin decidir `archived-accounts-still-count-in-the-panel-total`. Decidido el 2026-10-03: suma lo que no está excluido; archivar desde el formulario excluye, pero una archivada re-incluida (o archivada antes de ese día, o por el downgrade) suma. El subtítulo no puede afirmar «no suman» a secas.
- Reordenar se queda (botón de la toolbar, como hoy).
