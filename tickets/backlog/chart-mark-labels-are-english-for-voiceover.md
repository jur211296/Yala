---
id: chart-mark-labels-are-english-for-voiceover
status: backlog
priority: low
area: "a11y, charts, l10n"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 9 (presupuestos), visto en el código"
---

# Los nombres de los ejes de las gráficas están en inglés («Date», «Spent», «Period»)

Visto en el código el 2026-10-14, **sin medir con VoiceOver**: las marcas de Swift Charts de toda la app se declaran
con nombres fijos en inglés (`.value("Date", …)` 21 veces, `"Month"` 10, `"Balance"` 9, `"Period"` 6…). Swift Charts
usa esos nombres en la accesibilidad de las marcas y en el gráfico de audio, así que con VoiceOver pueden leerse en
inglés en cualquier idioma. En las gráficas de presupuesto, el texto propio de la línea del límite («Budget limit»)
ya se tradujo en el lote 9; los nombres de las marcas, no. El caso medido del Panel está en
`balance-chart-voiceover-reads-base-to-monto`.

## Hecho cuando

Medido con VoiceOver en una gráfica de cada pantalla, y los nombres que se lean salen en el idioma de la app.
