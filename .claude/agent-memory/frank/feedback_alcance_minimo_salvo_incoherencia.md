---
name: alcance-minimo-salvo-incoherencia
description: Jürgen escoge el alcance mínimo en cada decisión, pero amplía cuando el propio cambio dejaría una incoherencia visible al usuario
metadata:
  type: feedback
---

Al registrar el ticket de los predeterminados del Panel (2026-09-04) le puse cuatro decisiones
juntas. Escogió lo mínimo en tres —solo instalaciones nuevas, no re-sembrar a quien ya tiene la
app, dejar Cuentas plegada como está, aceptar un efecto colateral en usuarios actuales con tal de
no acoplar código nuevo— y **amplió** en la única donde el cambio se contradecía a sí mismo: que
«Restablecer» pasara a devolver los nuevos predeterminados en vez de encenderlo todo.

**Why:** su criterio no es «poco trabajo», es «que no queden dos verdades». Un residual heredado lo
tolera y lo deja anotado; una incoherencia que introduce *este* cambio, no — porque el usuario la
vería y no sabría a qué atenerse.

**How to apply:** al ofrecer decisiones de alcance, separa siempre las dos familias y dilo:
«esto ya estaba roto antes» vs «esto lo rompe este cambio». Propón el mínimo para lo primero y la
ampliación para lo segundo; acertarás casi siempre y él solo tendrá que confirmar. Y ofrécele las
decisiones **agrupadas tras medir**, no de una en una mientras investigas — ver
[[jurgen-levanta-sus-reglas]] y [[creo-que-no-es-aprobacion]].
