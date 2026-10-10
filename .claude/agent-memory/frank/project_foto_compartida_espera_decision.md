---
name: foto-compartida-espera-decision
description: La foto compartida que «no arranca» (10-oct) — arreglado el frío (PR #441); lo que puede quedar del reporte depende de la decisión B de Jürgen
metadata:
  type: project
---

El 10-oct (PR #441) se arregló lo único que caía en simulador: con la app cerrada el enlace decidía Pro/consentimiento
antes del arranque. En caliente, 2.1 ya leía bien (delante, segundo plano, Bandeja abierta, aviso de arranque).

**Why:** el reporte de Jürgen («a veces no arranca hasta cerrar Yala del todo») puede venir de la foto que ESPERA en
silencio detrás de una hoja abierta (Bandeja, la hoja de lectura anterior). Eso es lo que pedía el encargo y no se tocó;
la alternativa está en `shared-photo-waits-silently-behind-an-open-panel-sheet` (recomendada B).

**How to apply:** si vuelve el reporte tras el device-QA de `share-image-reading-does-not-always-start`, pregunta
primero si tenía una hoja abierta antes de buscar otro bug; y mira el breadcrumb `SharedImage` en Console.
