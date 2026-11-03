---
id: account-chip-icon-overflows-at-the-largest-text-size
status: backlog
priority: low
area: "panel, accesibilidad"
created: 2026-11-03
updated: 2026-11-03
source: "pase de estrés del barrido de QA 2.2 (encargo 2026-11-03-barrido-qa-2-2-b)"
---

# El chip de una cuenta en «Tus finanzas» saca el icono de su cápsula con el texto más grande

## En lenguaje de usuario

Con el texto de accesibilidad al máximo, el primer chip de «Tus finanzas» en el Panel pinta el icono de la cuenta
fuera de la cápsula, a la izquierda, y montado sobre el principio del nombre («Ahorros USD»). Se lee, pero se ve roto.

## Lo medido (2026-11-03)

- iPhone 17e y iPhone 17 Pro Max, iOS 27.2, AX5, modo oscuro, Yala Dev sobre `origin/2.2` en `8625a7edd`, semilla
  `realista`. Capturas: `~/Claude/worktrees/_capturas/barrido-qa-2-2-b/estres-17-pro-max/1-panel-realista.png` y
  `~/Claude/worktrees/_capturas/barrido-qa-2-2-b/estres-17e/1-panel-realista.png`.
- No medido: si pasa ya en 2.2 (5) o lo trajo el chip «Grupos» de #758 (`PanelAccountChipsRow.swift`). Primer paso:
  la misma captura con el build de `1a78abf51`.

## Hecho cuando

Con AX5 en el iPhone más pequeño y el más grande, el icono queda dentro de su chip y no tapa el nombre; captura del antes
y el después.
