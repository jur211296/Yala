---
id: settlement-notification-states-a-third-party-payment-as-fact
status: backlog
priority: low
area: "groups, notifications"
created: 2026-11-12
updated: 2026-11-12
source: "review adversarial del encargo «saldar como en Splitwise» (decisión 37 de 2.3)"
---

# El aviso de pago dice «¡Ana te pagó!» aunque lo apuntó otro y falta confirmarlo

Leído en el código por la review del 2026-11-12, sin medir en dispositivo: desde la decisión 37 (C1) un tercero puede
apuntar que Ana le pagó a Beto. En el teléfono de Beto el aviso local (`GroupNotificationService`, texto de pago
nuevo) dice «Ana te pagó S/ 50», como un hecho, sin decir que lo apuntó Lucía ni que falta que Beto lo confirme. Dentro
de la app la tarjeta sí lo dice («Lucía apuntó que Ana te pagó… ¿Lo recibiste?»). Quien paga (Ana) no recibe nada.

## Hecho cuando

Con un pago apuntado por un tercero, el aviso de quien recibe dice quién lo apuntó y que falta confirmarlo; test de la
lógica del texto.
