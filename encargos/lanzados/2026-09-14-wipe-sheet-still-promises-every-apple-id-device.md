# Implementar ticket: wipe-sheet-still-promises-every-apple-id-device

## Contexto
Una más antes de la pausa por cambio de cuenta Claude (Jürgen 2026-09-14). Tras #157 la hoja de Vaciar datos sigue prometiendo wipe en todos los dispositivos del Apple ID; ya no es cierto para solo-grupos / prestado.

## Decisión de Jürgen (2026-09-14)
**(1) Suavizar la fila ☁️**: prometer solo donde uses Yala con tus datos personales / vida personal — no «cualquier dispositivo con este Apple ID». Sin jerga interna de «sesión privada» (rule l10n). Las 4 variantes de locale vía `qa/scripts/add-l10n-key.sh`. Actualizar o retirar el razonamiento en `DestructiveScopeLogic.swift:279-281`.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank. Device-QA si aplica → `tickets/qa/`.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.

No lances el siguiente: cola en pausa tras este. No marketing/.

## Que se pide
1. Leer ticket + DestructiveScopeSheet / L10n keys.
2. Implementar copy suavizado (1) en las 4 variantes; criterios del ticket.
3. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Opción 2 (matiz) o 3 (dejarlo). Wipe de prod.

## Como se sabe que esta bien
La hoja en `.icloud` no afirma un alcance que el receptor puede no cumplir; locales al día; PR mergeado; `/cerrar-total`.
