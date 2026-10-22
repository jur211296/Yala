---
name: ticket-nuevo-busca-el-duplicado-primero
description: Antes de escribir un ticket por un hallazgo, grepea tickets/ por el CONCEPTO — dos de los tres que escribí el 10-sep ya existían, y el que existía era mejor que el mío
metadata:
  type: feedback
---

Un hallazgo no se convierte en ticket hasta haber grepeado `tickets/` por su concepto (no por su
`id`, que me lo estoy inventando yo en ese momento).

**Why:** el 10-sep escribí tres tickets de golpe al cerrar el drift del percent. **Dos eran
duplicados**, y solo me enteré porque el `ls` de comprobación mostró un fichero que yo no había
creado:

- `gateway-typecheck-roto-y-fuera-del-ci` (7-sep) ya cubría mi «typecheck rojo».
- `ci-no-corre-la-suite-del-gateway` (4-sep, actualizado el 8) ya cubría mi «la suite no corre en
  CI» — **con dos costes reales ya cobrados** que yo no tenía: un rojo que tardó 24 h en verse y un
  diagnóstico que salió mal por eso mismo.

O sea que el ticket que existía no era peor que el mío: era **mejor**. Duplicarlo habría partido la
historia del problema en dos ficheros y habría hecho que las instancias nuevas pesaran menos, no más.

**How to apply:** por cada hallazgo, antes de escribir nada:

    grep -rln '<término del concepto>' tickets/     # vitest, typecheck, el símbolo, el fichero…

Si hay uno vivo, **añádele una sección fechada** con lo medido hoy (`## Tercera instancia
(<fecha>)`) y sube su `updated:` — enriquecer gana a duplicar, y una instancia nueva es justo lo que
sube la prioridad de un ticket parado. Si el ticket existente dice algo que hoy es falso, corrígelo
ahí mismo y dilo: el del typecheck proponía «meterlo en el job del gateway del CI», y ese job **no
existe**.

Y el caso inverso, que también salió ese día: comprobar si hay que **reabrir** un descartado.
`welcome-private-card-promises-icloud-in-visit` decía «deja de ser LOW en cuanto el percent suba de
0» — y el percent ya estaba en 100. No procedía: su descarte no se apoyaba en el percent sino en el
ADR que retira M1. **Leer el motivo del descarte antes de reabrir** es la misma disciplina; ver
[[project_rediseno_sesiones_dos_ejes]], que manda no reabrir esos sueltos.

Familia de [[feedback_la_premisa_del_encargo_tambien_se_mide]]: lo que el encargo llama «hallazgo
nuevo» puede llevar semanas escrito.

## Y antes de ARREGLAR de paso, no solo antes de escribir (2026-09-16)

Editando `StorageRowGateLogic` corregí su cabecera, que decía «percent 0» con producción sirviendo 100 (medido con
`curl`). Tenía ticket vivo desde el 8-sep, `storage-row-gate-comment-says-rollout-zero`, con **dos** criterios: esa
línea y barrer las demás menciones (hay al menos tres más). Mi arreglo cumplía la mitad y dejaba el ticket partido. Lo
cazó una lente y lo devolví.

**How to apply:** un comentario viejo que ves al pasar también se grepea en `tickets/` antes de tocarlo. Si tiene
ticket, se deja y se cita en el Paso 0; arreglar medio ticket desde otro PR es peor que no tocarlo.
