---
id: bank-email-measure-a-week-of-real-peruvian-alerts
status: backlog
priority: high
area: "gateway, qa"
created: 2026-11-04
updated: 2026-11-04
source: "roadmap 2.3, criterio de salida del correo del banco"
---

# Medir el 90 % con una semana de avisos reales de un banco peruano

Criterio del roadmap: con alertas de un banco peruano, al menos el 90 % de los movimientos de una semana llegan bien
(cuenta y divisa, también dólares). Sin el buzón activado no hay avisos reales; los tests del gateway usan correos
sintéticos con la forma de los avisos peruanos.

## Cómo

- [ ] Con el buzón en staging o producción, reenviar una semana de avisos (al menos dos bancos, con uno en dólares).
- [ ] Contar en la Bandeja: importe, divisa, comercio, fecha y cuenta propuesta, contra el aviso.
- [ ] Si baja del 90 %, ajustar `MAIL_READ_SYSTEM_PROMPT` y guardar los avisos (anonimizados) como banco en `gateway/bench/`.
