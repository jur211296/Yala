---
name: feedback-sentry-vacio-no-descarta-un-crash
description: «Crasheó y se cerró» sin evento en Sentry: busca primero una pantalla muerta o un exit(0) deliberado, no un crash
metadata:
  type: feedback
---

Card 7e60 (2026-10-28): Jürgen dijo «la app crasheó y se cerró» al cerrar sesión. Sentry no tenía nada y el iPhone no
estaba conectado. La causa leída en el código fue una pantalla sin nada que tocar (el Welcome que nadie presentaba tras
el cierre en caliente); otra candidata era el `exit(0)` al pasar a segundo plano con la pantalla de reabrir.

**Why:** para quien usa la app, una pantalla vacía y una salida limpia «son» un crash, y ninguna llega a Sentry.
**How to apply:** ante un «crash» sin informe, busca primero estados sin salida y `exit(0)`; pide el `.ips` del iPhone
(Ajustes › Privacidad › Análisis) en «Necesita de ti», una vez, sin parar por ello.
