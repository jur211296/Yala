---
id: cash-flow-plan-asks-the-starting-balance-the-account-already-has
status: backlog
area: cash-flow-plan
priority: medium
created: 2026-10-14
updated: 2026-10-14
source: auditoría UX 2.2, lote 5 (primeros días), encontrado fuera del lote — es del lote 18
---

# El plan de flujo de caja pregunta «¿Con cuánto empiezas?» con 0 y sale en negativo aunque la cuenta tiene saldo

**Clase:** observación de cálculo para el lote 18 (reportes). No se tocó en el lote 5.

## Qué se vio (medido en el simulador, 2026-10-14)

Persona nueva con S/ 1.463 en su única cuenta y un pago planificado de S/ 45. El plan propone «¿Con cuánto
empiezas? (opcional) 0» y el resumen dice «Disponible -S/ 45»; la tabla, ya creada, enseña «Disponible -59 /
Acumulado -59» en el mes en curso. Para quien empezó hoy, el plan dice que no le alcanza teniendo S/ 1.463.

Capturas: `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-5-primeros-dias/capturas/5.8-04-guia-plan-4de4.png`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-5-primeros-dias/capturas/5.8-08-guia-tabla-2de3.png`.

## Qué decidir

Si el saldo inicial del plan propone el saldo de las cuentas, y cómo se explica (criterio de calculadoras claras).
