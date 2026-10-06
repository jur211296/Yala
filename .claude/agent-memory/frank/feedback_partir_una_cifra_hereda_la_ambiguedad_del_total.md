---
name: partir-una-cifra-hereda-la-ambiguedad-del-total
description: Al partir un total en «tuyos / de otra cuenta», cada parte se mide de la misma fuente que el total; si el total cambia de composición según el camino, no se parte
metadata:
  type: feedback
---

Al partir una cifra que ya existe («N cambios» → «Tuyos: a. De otra cuenta: b»), la parte nueva tiene que salir de la
MISMA fuente que el total, en el mismo tramo síncrono, y por cada sumando del total. Si el total cambia de composición
según el camino que lo produjo, no se parte: texto neutro.

**Why:** 2026-10-05, «Empezar de cero» partido. Calculé la parte ajena como «filas retenidas + espejo ajeno» y la review
(lente de datos) cazó dos «Tuyos: N» falsos: (1) con el drain atascado la cifra incluía cambios del History que el
registro atribuye a otra cuenta, y mi parte no los sumaba; (2) la cifra del push-all unas veces trae las filas retenidas y
otras no, así que cualquier resta las llamaba «tuyas». Los tests verdes no lo veían: sus testigos no tenían History ajeno.

**How to apply:** antes de escribir la parte, enumera los sumandos del total en CADA constructor (no en uno) y pregunta por
cada uno «¿de quién es?». Un sumando cuyo dueño no consta deja la cifra sin partir (`Int.max` → neutro), no se asigna al
lado cómodo. Y un «unknown» no debe inventar la otra clase cuando no consta nada de ella (ver [[el-copy-que-promete-se-recorre]]).
