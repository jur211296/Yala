---
name: cada-atasco-es-un-bug
description: En QA en el iPhone, cada pantalla atascada o sin salida va a su propia card como bug, aunque la cause la propia prueba.
metadata:
  type: feedback
---

Cada atasco que aparezca durante una prueba en el iPhone (spinner que no avanza, pantalla sin salida, cerrar sesión
bloqueado) se apunta como bug en su propia card, con lo medido y el log, y después se sigue.

**Why:** Jürgen, 2026-11-13: «si te vuelves a atascar, anótalo, porque no deberías… Cada atasco es un bug que debemos
resolver». Ese día salieron cuatro (Conectando 0 %/60 %, cierre a mitad del adopt, traspaso a medias sin salida, no baja
nada tras reabrir).

**How to apply:** no rodear el atasco en silencio ni darlo por «mi entorno»; card primero, y si sospechas que es un
artefacto del montaje de prueba, dilo en la card. Ver [[iphone-14-recien-instalado-exige-quitar-yala-prod]].
