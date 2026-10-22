# El avisador de rojos advisory del CI: Invalid API key — arreglar credencial + camino

## Contexto
Ticket: `tickets/backlog/ci-avisador-de-rojos-advisory-tiene-la-clave-mal.md` (high).
Jürgen 2026-09-09: creó routine **Avisos CI Yala** (Frank) y pegó URL/key en secretos del repo:
- `GROK_WEBHOOK_URL` / `GROK_WEBHOOK_SENDER_KEY` → webhook de esa routine (ya no la routine borrada).

Secretos en workflow: `.github/workflows/qa.yml` paso «Avisar a Grok si algun paso advisory fallo» usa `secrets.GROK_WEBHOOK_URL` y `secrets.GROK_WEBHOOK_SENDER_KEY`.

## Que se pide
AC del ticket:
1. Credencial viva (Jürgen ya rotó) — verificar.
2. **Verificar el camino entero desde el runner**, no solo curl local.
3. Un ejercicio del avisador aunque no haya rojos (ping periódico / camino que no se descubra solo en incendio).
4. Decidir (pregunta a Jürgen si hace falta) si `exit 1` del avisador debe seguir tumbando el job `tests` o separarse en check propio.

Board + `docs/TICKETS.md`. Merge + `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs, merge, `/cerrar-total`. Solo parar ante decisión/acceso real (p.ej. el punto 4 del AC).

## Cola siguiente (no la lances tú)
Tras /cerrar-total Frank lanza: `el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo`.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.

## Como se sabe que esta bien
- AC; aviso llega a Frank/Jürgen vía Avisos CI Yala; PR mergeado; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook Avisos Claude (sesión) cuando: (1) decisión; (2) PR; (3) /cerrar-total con resumen; (4) idle — una vez.
