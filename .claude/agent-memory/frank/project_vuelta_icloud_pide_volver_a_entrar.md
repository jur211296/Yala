---
name: vuelta-icloud-pide-volver-a-entrar
description: PR #194 (2026-09-17) — la vuelta a iCloud ya dice cuándo hay que volver a entrar; queda el QA en iPhone y cuatro residuales, uno de ellos el importante
metadata:
  type: project
---

**PR #194, en `qa`.** Si la sesión de la nube caduca durante «Volver a iCloud», la tarjeta lo dice y
ofrece entrar; al entrar, la vuelta sigue donde estaba. Las cuatro fases previas al montaje del
espejo (claim 15 % · drain 30 % · verify 50 % · freeze 62 %) dejaban la barra muda.

**Why:** ninguna de esas fases es estable, así que el motor de la nube no corre y el aviso de «vuelve
a entrar» de Ajustes no puede salir — ese exige el runtime en `.stoppedUntilSignIn` y lo que se pinta
es la tarjeta de progreso.

**How to apply:**

- **Lo que espera a Jürgen es el QA en iPhone: 8 pasos, y los que deciden son el 6 y el 7.** El 6 es
  el control negativo (sin red y con la sesión buena **no** debe pedir volver a entrar) y el 7 es
  entrar con otra cuenta de Google (**no** debe retomar). Hace falta staging: la sesión se caduca con
  `delete from auth.sessions where user_id = …`.
- **El residual importante es `reverse-before-mount-has-no-way-to-abandon-the-return`**: las cuatro
  fases salen solo por éxito y la tarjeta no ofrece cancelar en ninguna. Este cambio cierra la última
  puerta automática que quedaba —la degradación de `reverseVerify`, que el criterio 3 del ticket
  pedía quitar— sin abrir otra. No es regresión (ese terminal ya llegaba con un `.reverseRollback`
  que lanza sin sesión), pero si Jürgen pregunta «¿qué falta aquí?», es esto.
- Los otros tres: `reverse-zombie-sweep-reads-an-expired-session-as-network` (la misma forma una fase
  más tarde), `forward-verify-reads-an-expired-session-as-network` (la ida, fijada con test) y
  `neutral-mount-wiring-scan-is-red-on-2-1`, que **no es de este cambio** — un source-scan que falla
  igual en un worktree limpio desde HEAD, encontrado por la suite completa de aquí.
