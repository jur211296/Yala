---
name: las-lineas-del-ticket-son-del-fichero-de-entonces
description: Un ticket que cita «falla en :1115 y :1118» puede nombrar mal QUÉ aserción es: abre el fichero en el commit del fallo antes de razonar sobre el mecanismo
metadata:
  type: feedback
---

Las líneas de fallo de un ticket se leen **en el fichero de la fecha del fallo** (`git show <commit>:<fichero> | sed -n`), no en el de hoy ni en la frase del ticket.

**Why:** 2026-10-26, card zvlj (marca ≈ del resumen de Registros). El ticket decía que caían «ingresos NO marca» y «saldo SÍ marca»; en el fichero de entonces `:1115` era `s.balance == 1_000` y `:1118` `s.balanceIsApproximate`. Con la lectura del ticket ningún estado global encajaba; con la real, «solo gastos» encajaba a la primera (sin ingresos: saldo −999.000 y sin marca). Seis semanas de reapariciones sin causa salían de esa lectura.

**How to apply:** antes de formular hipótesis sobre un rojo citado por línea, `git log --until=<fecha> -1 -- <fichero>` y lee esas líneas ahí. Luego confirma con un mutante que reproduzca exactamente esas aserciones. Hermano de [[la-premisa-del-encargo-tambien-se-mide]].
