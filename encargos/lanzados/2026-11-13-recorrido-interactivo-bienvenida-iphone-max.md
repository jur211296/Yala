Yala
# Recorrido interactivo con Jürgen en el iPhone 14: bienvenida y pasos iniciales flujo por flujo
---
card: nueva
toca: tickets/recorrido-bienvenida-2026-11-13/, docs/qa/recorrido-bienvenida-2026-11-13/
esfuerzo: medium
cierre: cierras-tu
---

Sesión en MODO MANUAL, pedida explícitamente por Jürgen el 13-nov. No hay cierre final sin su GO humano y no ejecutes `/cerrar-total` por tu cuenta.

Va después de dos bugs: «Después de "Ya está tu cuenta", Yala va directo al Panel» y «Entrar con otra cuenta de Google o Apple funciona al primer intento». Corre ANTES de los ajustes visuales del Welcome y de Grupos (pedido de Jürgen del 13-nov, 09:52). Antes de empezar, instala en el iPhone 14 por DeviceMCP la build más reciente de 2.3, con esos arreglos mergeados (Jürgen lo conecta a la Max para esta sesión; si no aparece, pídeselo).

Objetivo: recorrer junto con Jürgen, en vivo y uno por uno, todos los flujos de la bienvenida y los pasos iniciales en el iPhone 14: Welcome, entrar con Google, Apple e iCloud privado, otra cuenta, «Empezar de cero», «Dividir con amigos», los pasos iniciales y minitutoriales (incluido el de correo), la Bandeja y el modo nube. En cada flujo: lo ejecutas o lo ejecuta Jürgen, muestras capturas, anotas lo que él comente y esperas su visto bueno antes de pasar al siguiente.

Esta sesión verifica y no programa: no toca código de la app, para poder correr en paralelo con otra sesión de Yala en la Mini. Cada hallazgo queda como ticket en `tickets/recorrido-bienvenida-2026-11-13/` (capturas en `docs/qa/recorrido-bienvenida-2026-11-13/`) y, si Jürgen lo pide, como card; los arreglos se encolan después como encargos aparte. Al terminar, entrega un artifact visual de Claude con la lista de flujos (OK o con hallazgo) y los tickets creados, y espera el GO de Jürgen para cerrar.

Puedes usar un segundo simulador si hace falta. Commits y PR sin firma de IA.


Primero verifiquen con Jürgen que, tras «Ya está tu cuenta», la app va directo al Panel (card tablero-despues-de-ya-esta-tu-cuenta-yala-vuelve-zrya) y que entrar con otra cuenta de Google o Apple funciona (card tablero-entrar-con-otra-cuenta-de-google-o-apple-38q3). Si alguno sigue fallando, anótalo en su card.

## Paso 0 — decisiones

Sesión manual con Jürgen delante; lo que él diga en vivo manda sobre esto.

- **Build a probar:** los dos arreglos previos siguen en cola de merge con el CI corriendo. No se espera (regla de no esperar CI ajeno): se compila Yala Dev de `origin/2.3` + las dos ramas en un worktree aparte del scratchpad, sin commit. Riesgo: si el CI de esas ramas falla, lo probado no es lo que aterrice; se dice en el cierre.
- **Partir de cero:** se desinstalan Yala y Yala Dev del iPhone 14 y se reinstala solo Yala Dev (memoria: con Yala prod instalada el App Group de Dev sobrevive). Datos de dev en el teléfono de pruebas: lo decide Frank.
- **Instalación:** por `devicectl` (Device MCP gratis no tiene `build_and_run`).
- **Orden:** 0a «Ya está tu cuenta» → Panel, 0b otra cuenta de Google/Apple, luego Welcome, Google, Apple, iCloud privado, Empezar de cero, Dividir con amigos, pasos iniciales y minitutoriales (correo incluido), Bandeja, modo nube.
- **Superficies:** un ticket por hallazgo en `tickets/recorrido-bienvenida-2026-11-13/`, capturas en `docs/qa/recorrido-bienvenida-2026-11-13/`, acta en el README de esa carpeta de tickets. Cards solo si Jürgen las pide; si 0a/0b fallan, comentario en su card.
- **Entrega:** todo cae en `tickets/` y `docs/` (sin compilar), así que no hay gate de build; PR por ser worktree. Cierre solo con el GO de Jürgen.
- **Decisiones de Jürgen pendientes del lanzamiento:** no se incorporan aquí (no tocan este encargo y `decisiones.py` no está en la Max); se dice en el cierre.
