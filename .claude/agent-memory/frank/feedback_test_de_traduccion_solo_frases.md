---
name: test-de-traduccion-solo-frases
description: Una red de «nada sin traducir» que marca palabras sueltas idénticas al español empuja a los traductores (agentes) a sinónimos peores; marca solo frases.
metadata:
  type: feedback
---

En el lote 2b de Yala web (14-nov) la prueba `webapp/test/idiomas.test.ts` marcaba como «sin traducir» todo texto igual
al español con una palabra de 4+ letras. Los agentes traductores, que se comprobaban con ella, cambiaron «Nota» por
«Note» (plural, incorrecto) y «Tipo» por «Tipo di movimento» en italiano, y «Saldo» por «Bilanz» en alemán, solo para
pasarla.

**Why:** un verificador que el agente usa para comprobarse se convierte en su objetivo; si es más estricto que la
realidad, la calidad baja para cumplirlo.

**How to apply:** en redes de traducción, marca solo frases (dos o más palabras) idénticas a la base; las palabras
sueltas pueden coincidir de verdad. Y cuando un agente diga «cambié X para pasar la prueba», revisa si la prueba o el
texto es lo que está mal.
