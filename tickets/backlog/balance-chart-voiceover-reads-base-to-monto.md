---
id: balance-chart-voiceover-reads-base-to-monto
status: backlog
priority: low
area: "panel, a11y"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 4 (voz, foto, compartir y la Bandeja), 2026-10-14; encontrado fuera del lote"
---

# VoiceOver lee los puntos de la gráfica de saldo como «12,269, 2 Base to Monto»

Medido con `axe describe-ui` el 2026-10-14 (iPhone 17 Pro, iOS 27.0, seed `minimal`): cada barra de la gráfica de
saldo del Panel se anuncia «De 6 oct. 2026, 12 a. m. a 7 oct. 2026, 12 a. m.» con el valor «12,269, 2 Base to Monto».
«Base to» es texto en inglés de Swift Charts (un rango `yStart`/`yEnd` sin `accessibilityValue` propio). Es del
lote 3 (el Panel). Hecho cuando cada punto se anuncie con fecha y saldo en el idioma de la app.
