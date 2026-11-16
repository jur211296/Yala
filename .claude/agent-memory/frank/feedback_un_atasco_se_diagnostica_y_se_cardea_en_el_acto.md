---
name: feedback-un-atasco-se-diagnostica-y-se-cardea-en-el-acto
description: Jürgen 13-nov — ningún atasco o fallo visto en una prueba se deja ir: se busca el motivo con datos del aparato y se abre card crítica, aunque no sea del encargo
metadata:
  type: feedback
---

Si una prueba en el iPhone (o en el simulador) se atasca o falla, aunque no sea lo que el encargo arregla, se diagnostica en
el acto con datos y se abre card very-high con «CRÍTICO» en el título, lista para lanzar.

**Why:** 2026-11-13, QA del arreglo de «otra cuenta de Google y Apple»: el adopt se quedó al 60 % y yo iba a seguir con el
PR. Jürgen: «si se ha atascado, identifica el motivo con los logs y crea la card crítica. No dejemos ir ningún atasco o fallo».

**How to apply:** los logs del iPhone por Wi-Fi piden root (`log collect` → «Must be root»); antes de pedir la contraseña,
la telemetría de staging por instalación ([[reference-leer-telemetria-de-staging]], token en la Mini
`~/Secrets/yala-cloudflare/analytics-read.token`) y el journal copiado del App Group con devicectl
([[reference-contar-el-store-del-iphone-con-devicectl]]) dieron el motivo exacto en minutos. El tablero no tiene
`critical`: very-high + «CRÍTICO» en el título, y `mover … --a ready`.
