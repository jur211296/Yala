---
id: 2026-11-20-salud-financiera-tres-secciones-maquetas
status: done
priority: medium
area: "panel, salud-financiera"
created: 2026-11-20
updated: 2026-11-20
source: "Jürgen, 20-nov-2026, con capturas de su iPhone"
---

# Maquetas: la hoja de Salud financiera en tres secciones y en tono de consejero

Sesión de diseño, sin código de la app. Entregado:

- Artifact «Salud financiera en tres secciones» (https://claude.ai/artifact/3DGVHSBZxo1BFp9nf7xybw): las capturas de hoy,
  la opción A en seis estados (todo bien, presupuesto excedido, no alcanza, sin presupuestos, sin pagos planificados,
  sin Pro) en claro y oscuro con sus textos, las opciones B y C con el mismo caso, cómo encaja la nota con las secciones,
  de dónde sale el −33.974, casos de borde, una idea para la racha y siete preguntas con recomendación cuyas respuestas
  se guardan en la colección `decisiones` del artifact.
- Ticket de implementación: `tickets/backlog/2026-11-20-salud-financiera-tres-secciones.md`.

Medido por el camino: el −33.974 es «Al 30 de noviembre tendrías» (`MonthEndBalanceLogic`: saldo con tarjetas + lo que
falta entrar − lo que falta salir, gasto estimado incluido). «Presupuestos —» con un presupuesto en pantalla sale de
`FinancialScoreCalculator.bucketIsValid`: un presupuesto mensual cuenta desde el primer período que empieza después de
crearlo (inferido para el caso de Jürgen: no se miró la fecha de su presupuesto).
