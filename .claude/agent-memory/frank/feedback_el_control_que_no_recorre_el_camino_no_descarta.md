---
name: el-control-que-no-recorre-el-camino-no-descarta
description: Un control «sin X funciona» solo descarta X si recorre el MISMO camino que el caso roto; si X cambia la ruta, el control no prueba nada
metadata:
  type: feedback
---

**Un control negativo solo aísla la causa si el caso bueno pasa por el mismo código que el roto.** Si quitar X
cambia la RUTA, el control mide otra pantalla.

**Why:** el 2026-10-15 (card 8xt4) mi propio barrido dejó escrito «sin el cambio de grupos pendiente llega al
onboarding», y eso apuntaba a la subida de grupos. Pero sin cambios de grupos el alert borra en el sitio y nunca
pasa por la puerta privada; con ellos delega en la puerta. El fallo estaba en la puerta (`importNotQuiescent`
por el testigo del mount que miente bajo `-uitest`), a la que el control no llegaba. Lo destapó una sonda de
tres `NSLog`, no el razonamiento.

**How to apply:** al escribir un control en un ticket o barrido, di por qué código pasa; si X decide la ruta,
el control no sirve y hay que instrumentar el camino roto. Relacionado: [[instrumentar-gana-a-razonar]],
[[la-premisa-del-encargo-tambien-se-mide]].
