---
id: group-settings-options-read-their-value-from-a-lazy-section
status: backlog
priority: low
area: groups, settings
created: 2026-11-07
updated: 2026-11-07
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
---

# Las opciones de Ajustes del grupo toman su valor del aparecer de otra sección

Leído en el código, **no reproducido**: en Ajustes del grupo, «Menos pagos entre ustedes», «Ver las deudas en una sola
moneda», la moneda y «Cómo se reparte un gasto nuevo» se cargan en el `.onAppear` de la sección **Presupuesto**
(`GroupSettingsView.swift:493-499`), que es la quinta de una lista que solo monta lo visible. En una pantalla pequeña o con
texto grande, si esa sección no ha aparecido, los interruptores enseñarían «apagado» aunque el grupo los tenga encendidos.

Cómo verificarlo: iPhone SE o texto AX5, un grupo con «Menos pagos» encendido, abrir Ajustes sin desplazar y mirar el
interruptor.
