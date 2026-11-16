# Rebase PR 643 · Panel en todos los idiomas (2.2)
toca: `Localizable.xcstrings`, `Yala/Resources/`, `marketing/` NO

Rama base: **2.2**. Un solo PR (actualizar o reemplazar [#643](https://github.com/jur211296/Yala/pull/643)). Máquina: cualquiera libre. Prioridad 2.2 pedida por Jürgen 2026-11-05.

## Contexto
[#643](https://github.com/jur211296/Yala/pull/643) (trae el lote 12.4 / [#627](https://github.com/jur211296/Yala/pull/627)) pone la pestaña principal como «Panel» en todos los idiomas y alinea pt-BR «Ajustes». Lleva conflicto con 2.2 y el check `gateway` en rojo. Es el único bloqueo de producto abierto en 2.2.

## Qué se pide
1. Partir de `origin/2.2` al día.
2. Traer el trabajo de la rama de #643 (o reaplicar el cambio de l10n) resolviendo conflictos.
3. Arreglar el fallo de `gateway` hasta verde.
4. Dejar el PR listo para auto-merge a 2.2 (o abrir uno nuevo si la rama vieja no sirve) y, al mergear, cerrar #627 como absorbido.
5. Pipeline serial: limpia → build `-jobs 2` sin sim → 1 sim → tests tocados → apagar. DerivedData/cachés de esta sesión al cerrar.

## Qué NO hay que tocar
- Rama 2.3 / lotes N/P/T.
- `marketing/` (lane Lola).
- Barrido, device MCP, TestFlight (siguen en hold).
- No «arreglar» saltándote strings sin documentar.

## Hecha cuando
- CI verde en el PR hacia 2.2 (gateway + tests/coverage que apliquen).
- La pestaña se llama Panel en todos los idiomas; pt-BR dice Ajustes donde toca.
- #627 cerrado o claramente absorbido en el cuerpo del PR.
- Termina con `/cerrar-total` (cierra-sola).

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.
