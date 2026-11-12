---
name: project-prueba-cortesia-ia-espera-iphone
description: 12-nov: la prueba de cortesía de voz, foto y Yala IA (Y23-09) queda en qa; probarla exige vaciar Yala Dev en el iPhone y el encargo prohibía borrar datos de dispositivos
metadata:
  type: project
---
La card Y23-09 (bienvenida 2.3, lote 03) quedó en `tickets/qa/onboarding-2-3-learn-to-record-courtesy-trial.md` con
guion de iPhone para Jürgen.

**Why:** leer voz, foto y la frase de Yala IA necesita red y App Attest de hardware, y una instalación nueva (Primeros
pasos solo existe en instalaciones de 2.3). En el iPhone 14 eso es vaciar Yala Dev, y el encargo de lotes decía «nunca
borrar datos de dispositivos reales»: choca con mi nota de que en el iPhone 14 decido yo. Ganó el encargo.

**How to apply:** si en otro lote de bienvenida hace falta una instalación nueva en el iPhone, mira si el encargo trae
esa prohibición antes de vaciar; si la trae, guion para Jürgen. Lo que más vale medir en su QA: que el chat de la prueba
no diga «no disponible» con una cuenta Free (se arregló apagando las sugerencias, sin medir en hardware).
