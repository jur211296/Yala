# Subir a TestFlight el HEAD de 2.1 (CPV nuevo) para Device-QA — via asc

## Contexto
Jürgen 2026-09-09: Device-QA en dos móviles TF (personal + teléfono solo QA). ESTADO/CPV del proyecto siguen en **build 12** con muchos merges encima (#102–#115+). Hace falta un build fresco en TestFlight **antes** del guion de prueba.

Herramientas: `asc` CLI ya autenticado en la Mini. Subida Yala TF/store = solo Mini. Scheme/release según CLAUDE.md / EXECUTION-RULES / práctica del repo.

## Que se pide
1. Bump `CURRENT_PROJECT_VERSION` (y lo que el repo exija) al siguiente entero.
2. Archive + upload a App Store Connect / TestFlight con el flujo estándar del repo (`asc` + Xcode/xcodebuild según docs).
3. Confirmar que el build aparece en TF (processing → ready) o dejar el estado claro si queda en processing.
4. Actualizar `docs/ESTADO.md` con el nuevo número de build/CPV.
5. Avisar a Frank al cerrar: número de build TF listo (o «en processing») para que lance la sesión del guion Device-QA.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit del bump + docs, merge si aplica, `/cerrar-total`. Solo parar si falta acceso/credencial/2FA de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No empieces el guion Device-QA aquí — eso es otra sesión.

## Como se sabe que esta bien
- IPA/build en ASC/TF; CPV actualizado en repo + ESTADO; `/cerrar-total` con el número de build.

## Avisos al bot dueño (Frank)
POSTea al webhook cuando: (1) acceso Jürgen; (2) PR; (3) /cerrar-total con **número de build TF** y si ya está instalable; (4) idle — una vez.
