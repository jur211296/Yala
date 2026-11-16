---
id: private-icloud-gate-takes-almost-a-minute-to-check
status: backlog
priority: medium
area: welcome, icloud
created: 2026-11-06
updated: 2026-11-06
source: QA en el iPhone 14 con Jürgen (lote cerrar-sesión-crash-welcome, card 7e60)
---

# «Revisando qué hay en tu iCloud…» tarda casi un minuto

## Qué pasa

En el Welcome, «Ya tengo cuenta › ¿Es tu primera vez? Empieza aquí › Crear otra cuenta › Tu cuenta en tu iCloud
privado» deja la pantalla «Revisando qué hay en tu iCloud…» unos 47 s (medido el 2026-11-06, 07:01:25 → 07:02:12, iPhone
14, iOS 27.2, Yala Dev, con red WiFi buena) antes de enseñar «Ya tienes datos en tu iCloud · 2 registros · 2 cuentas».
Jürgen preguntó si debería tardar tanto: no.

## Lo que no se sabe

Si el tiempo es de la sonda (consulta a CloudKit) o de esperar a que el espejo importe. No se midió con consola. Primer
paso: repetirlo con la consola del aparato y ver dónde se va el tiempo.

## Hecha cuando

La revisión responde en pocos segundos con red buena, o la pantalla dice qué está esperando y deja salir.
