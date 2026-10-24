---
id: iphone-duo-title-only-toolbar-buttons-stay-in-a-top-bar
status: backlog
priority: low
area: "platform, iphone-duo, adaptativo"
created: 2026-10-24
updated: 2026-10-24
source: "encargo 2026-10-24-iphone-duo-adaptar-2-2 (QA en el simulador del iPhone Duo, SDK 27.1)"
---

# iPhone Duo: los botones de barra de solo texto y el avatar se quedan en una barra arriba

**Decisión de Jürgen.** No es un fallo: es lo que hace el sistema. Pero deja dos barras a la vez en el Duo cerrado.

## Qué se ve

Compilando con el SDK 27.1, en el Duo cerrado (y abierto en horizontal) las pestañas y los botones con icono pasan a
una barra vertical en el lateral. Dos clases de botón no pasan y se quedan en una barra horizontal arriba, junto al
título:

- **Los de solo texto**: «Seleccionar» (Registros), «Cancelar», «Hecho», «Editar», «Aplicar», «Guardar», «Añadir»… Unos
  25 en hojas y pantallas secundarias. Apple: un botón con título y sin icono nunca va en vertical.
- **Los de vista propia**: el avatar de Ajustes (7 pantallas, `ProfileToolbarItem`) y «👥 3» del detalle de grupo.

La bandeja del Panel, que también era vista propia, sí se pasó a la barra vertical en este encargo: sin título arriba,
en el primer arranque se pintaba flotando encima de la gráfica.

## Lo que se probó y por qué no se hizo

- **Avatar a la barra vertical** (`.axisBehavior(.verticalPreferred)`): en el Panel cerrado no caben avatar, bandeja,
  Filtros y Configurar; Filtros se iba al menú «···». Captura: `barra-avatar-bandeja-en-vertical.png`.
- **Que la barra de pestañas ceda sitio** (`.toolbarVerticalCompressionBehavior(.prefersToolbarItems)`): las pestañas
  se colapsan a un solo botón. Captura: `barra-prefiere-acciones.png`.
- **«👥 3» en vertical**: el número se sale de la cápsula.
- **Botones de texto con icono** (`Button(título, systemImage:)`): en una barra horizontal el sistema prefiere el icono,
  así que **en el iPhone** «Cancelar» pasaría a ser una ✕ y «Editar» un lápiz. Es un cambio visible fuera del Duo.

Capturas en `~/Claude/worktrees/_capturas/2026-10-24-iphone-duo-adaptar-2-2/` (`barra-*.png`).

## Lo que hay que decidir

1. ¿Los botones de texto pasan a icono + título en toda la app (también cambia el iPhone), o se quedan como están?
2. ¿El avatar va a la barra vertical aunque en el Panel cerrado Filtros acabe en «···»?

## Hecho cuando

- La decisión está tomada y aplicada, con capturas del Duo cerrado y del iPhone 17 Pro antes y después.
- Ojo al aplicarla: un botón de barra con solo icono que no cabe **desaparece** de la barra vertical en vez de pasar a
  «···» (medido; regla en `.claude/rules/swiftui-ds.md`). Todo lo que pueda desbordar lleva título.
