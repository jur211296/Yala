---
id: 2026-11-22-pruebas-interfaz-rojas-2-3-lote
status: done
priority: medium
area: "qa, uitests"
created: 2026-11-22
updated: 2026-11-22
source: "encargo del 22-nov: encolar lo pendiente del backlog que esté claro (Jürgen, 15:08 Lima)"
---

# Lote: pruebas de interfaz rojas de 2.3

Ocho tickets de XCUITest en rojo en 2.3: enlace a grupo en arranque en frío, texto grande de `FormClarity23UITests`
(dos tickets), «Pagar ahora», convertir a grupo, espera al cerrar sesión sin cuenta, entradas del widget en segundo plano
y el carrusel del flujo de caja.

## Resultado

Medido antes de tocar nada: los 9 casos pasan en la nocturna de 2.3 del 22-nov (salvo convertir a grupo, arreglado ese
mismo día después de la nocturna) y 9/9 en local sobre origin/2.3. Ninguno era un bug de la app. Siete se cierran sin
cambios, con la evidencia en cada ticket. El del carrusel, además, recibe el arreglo de la prueba que pedía (mirar la
página con el carrusel quieto), verificado con la clase entera y el caso 3 veces seguidas.

Lo que confirma el runner del CI es la próxima nocturna: el CI de un PR no corre la interfaz.

Encargo y Paso 0: `encargos/lanzados/2026-11-22-pruebas-interfaz-rojas-2-3-lote.md`.
