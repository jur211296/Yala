---
name: telefono-sin-attest-veredicto-y-salida
description: Encargo del 15-sep (opción 2) — el teléfono con 24 h sin App Attest ve el veredicto y puede cerrar sesión perdiendo los cambios de grupos; en qa solo espera la racha, porque la salida no se puede montar en ningún dispositivo
metadata:
  type: project
---

El ticket `groups-phone-that-never-attests-is-told-to-retry-forever` está en `qa` y **solo espera
dos cosas**: ver la racha en el simulador (dos lanzamientos del scheme `Yala` separados por más de
24 h) y el canario `groupsAttestTerminal` en campo tras publicar.

**Why:** la salida «Cerrar sesión y perderlos» exige cambios de grupos sin subir, y un teléfono sin
App Attest no baja ningún grupo. Ni el simulador ni un dispositivo llegan ahí sin fingir el token y
el transporte, que deja ciego al test. La cubren unit, source-scans y 25 mutantes.

**How to apply:** si un `/qa` coge este ticket, no intentes montar la salida: verifica la racha y
ciérralo con eso. Lo abierto tiene ticket propio
(`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`, medium;
`groups-tab-does-not-say-this-phone-cannot-sync-groups`, low).

Relacionado: [[un-numero-sustituto-lo-cumple-otra-cosa]].
