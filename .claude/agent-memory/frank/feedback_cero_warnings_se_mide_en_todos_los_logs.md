---
name: cero-warnings-se-mide-en-todos-los-logs
description: «Cero warnings nuevos» del gate NO se lee del último build — no mira los tests y el build es incremental; se une todo log de la sesión, se filtra por el diff y se tiran los de mutantes
metadata:
  type: feedback
---

**«Cero warnings nuevos» se mide uniendo TODOS los logs de la sesión y filtrando por los ficheros del
diff, no leyendo el build final.** Después se descartan los que solo salen en logs de mutantes (una
variable que el mutante deja sin usar) y los de líneas anteriores al cambio (`git blame`).

**Why:** el 2026-09-10, con el gate a punto de sellar, dos warnings MÍOS en ficheros de test iban al
commit —uno era error en modo Swift 6— y el build final no los enseñaba. Dos razones medidas: el `build`
del paso 1 no compila `YalaTests`, y el grep del paso 2 filtra fuera toda línea `warning:`; y encima el
build es incremental, así que un fichero que no se recompila en esa corrida no repite sus warnings.
Ticket: `gate-never-reads-test-file-warnings`.

**How to apply:** antes de sellar, `cat <scratchpad>/*.log | grep -E "/<fichero>.swift:[0-9]+:[0-9]+: warning:"`
por cada `.swift` del diff, test incluidos. Un warning que aparezca, se localiza (`grep -l`) antes de
juzgarlo: si solo sale en `mut*.log`, es del mutante. Cuando el ticket se arregle, esta ficha caduca —
compruébalo en `.claude/commands/gate.md` antes de seguir aplicándola. Familia de
[[mis-mediciones-fallan-por-el-filtro]].
