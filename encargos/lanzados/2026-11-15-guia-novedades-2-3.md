Yala
# Guía de novedades 2.3 para recorrerla como usuario
---
toca: docs/guias/novedades-2-3/
esfuerzo: medium
cierre: cierra-sola
---

## Qué quiere Jürgen (15-nov, 08:37 Lima)
Jürgen instaló la 2.3 desde TestFlight en su teléfono personal, donde usa Yala de verdad. Quiere un **artifact visual de Claude** para recorrer TODO lo nuevo de 2.3 como usuario (no como QA) y anotar comentarios y mejoras mientras lo mira.

## Alcance: lista COMPLETA
- Todo lo que cambió entre la última versión publicada en el App Store (2.2) y la 2.3 que está en TestFlight: funcionalidades grandes, cambios chicos, ajustes solo visuales, textos nuevos, animaciones, accesibilidad, rendimiento que se note. Nada se omite por pequeño.
- Fuentes: `git log` y PR mergeados en `2.3` desde el corte de 2.2, cards done/in qa de 2.3 en el tablero (`tablero listar --proyecto yala --version 2.3`), tickets/done, notas de versión y Novedades in-app si existen. Cruza las fuentes para no dejar nada fuera y no inventar nada que no esté en el build.
- Marca aparte lo que está mergeado en 2.3 pero NO entra en el build de TestFlight 2.3 (1) (p. ej. PR pendientes de desbloquear), para que Jürgen no lo busque.
- Es de solo lectura. No toques código, ni el tablero, ni CloudKit, ni Supabase.

## Cómo se organiza el artifact
1. **Usuario nuevo**: lo que ve alguien que instala desde cero (bienvenida/onboarding, creación de cuenta, primeros pasos, permisos, estados vacíos, etc.), en el orden en que aparece.
2. **Usuario existente**: lo que nota alguien que ya usa Yala y actualiza: pantallas cambiadas, novedades visibles, y funciones nuevas que **puede activar**.
3. Para cada función activable (p. ej. el correo que se reenvía y se registra solo, conectores, Nube/iCloud, Siri/atajos, Live Activities si aplica): si **ya se puede probar en producción con su teléfono**, cómo activarla paso a paso; o si **todavía no** (depende de backend en staging, de la web, de algo pendiente), dilo claro y por qué.
4. Cada ítem: dónde está en la app (ruta de toques), qué cambió, por qué importa, captura o maqueta si ayuda, estado (listo para probar / se puede activar / todavía no) y un espacio para que Jürgen marque «me gusta / mejorar / bug» y escriba su comentario. Que se pueda filtrar por sección y estado, y que los comentarios se puedan copiar o exportar en un solo bloque para pasárselo a Frank.
5. Arriba, un resumen: cuántos ítems hay por sección y un recorrido sugerido de 15–20 minutos.

## Entrega
- Artifact visual de Claude (no Markdown ni PDF), en español neutro latinoamericano, pensado para leerlo en el teléfono.
- Puedes dejar las fuentes del inventario en `docs/guias/novedades-2-3/` si sirve, en un PR chico; si no hace falta, no hagas PR.
- Si necesitas confirmar algo en la app, usa un simulador (en la Max puedes usar un segundo simulador) o el iPhone 14 por DeviceMCP; no hace falta prueba exhaustiva.
- Lo menor decídelo tú y anótalo en «Decidido sin consultar». Commits y PR sin firma de IA.
- Al terminar, publica el link del artifact en el cierre y ejecuta `/cerrar-total`.

## Paso 0 — decisiones (resueltas en semi, sin consultar: todas menores y reversibles)

1. **Corte del build:** 2.3 (1) se archivó desde el bump de versión, que contiene 2.3 hasta el merge del barrido final (`a64a2bafb`). Lo mergeado después (nube: cifrado y fotos, volver a tu iCloud; Grupos en Yala web) va como «no está en este build».
2. **Alcance:** PR de `v2.2..a64a2bafb` que tocan la app o el gateway; fuera los merges de 2.2 en 2.3 (ya publicados) y los PR solo de tests, docs o proceso.
3. **Estado de lo activable:** se mide en producción (`/config` del gateway, rutas `/mail/*`, MX de yalainbox.com) en vez de fiarse del RUNBOOK; lo que no se puede medir se dice.
4. **Usuario nuevo:** se recomienda verlo en el iPhone 14 de pruebas, nunca borrar Yala en el teléfono personal.
5. **Notas de Jürgen:** en la base del artifact (colección `notas`), con copia en el navegador y botón para copiar en bloque.
6. **Fuentes en el repo:** `docs/guias/novedades-2-3/` (inventario sin capturas, plantilla y script), en un PR chico.
