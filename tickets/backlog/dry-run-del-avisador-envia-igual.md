---
id: dry-run-del-avisador-envia-igual
status: backlog
priority: low
area: "tooling, avisos"
created: 2026-09-09
source: medido al cerrar `qa-no-puede-crear-cuenta-en-otra-divisa` (2026-09-09)
updated: 2026-10-08
---

# `--dry-run` no simula nada si va con `--avisar`: manda el aviso de verdad

## Qué pasa

`~/.claude/hooks/avisar_grok.py` despacha por una cadena de `if` sobre los argumentos, y
**`--avisar` se comprueba ANTES que `--dry-run`**:

```python
    if "--avisar" in args:
        return modo_avisar(args)      # :1957-1958  ← envía
    if "--dry-run" in args:
        return modo_manual(args, prueba=False)   # :1959-1960  ← nunca se alcanza
```

Un comando con los dos flags entra por `modo_avisar` y **postea**. El flag no se ignora con un
error ni con un aviso: se ignora **en silencio**, y la salida es idéntica a la de un envío normal
(`ENVIADO destino=frank motivo=cierre-resumen HTTP 200`), así que nada delata que la simulación no
lo era.

**Medido el 2026-09-09**, y no en teoría: intentando previsualizar el aviso de cierre para
comprobar qué PR citaba —justo la comprobación que pide `el-aviso-de-cierre-cita-el-pr-de-otra-sesion`—
salió un segundo `cierre-resumen` real a Frank con el texto de prueba «verificacion del puntero».
Las dos líneas están en `~/.claude/cache/avisos-grok/envios.log`, a 19 segundos una de otra.

## Por qué importa

El daño no es el ruido, es que **deja sin instrumento la comprobación que otro ticket exige**. El
cierre de toda sesión lanzada tiene que verificar a mano que el aviso cita el PR correcto, y la
única forma de mirarlo sin enviar es un dry-run que no existe. Hoy la elección es: enviar dos veces,
o no comprobar.

Y hay un agravante de documentación: la ayuda del propio script (`:184`) anuncia
«compone, dice si pasaria la puerta y **NO envia**», y el comentario de `:1696` lo repite. El
contrato está escrito y el orden de los `if` lo incumple.

## Cómo se sabe que está bien

- `--dry-run` con `--avisar` **compone y no postea**, y lo dice.
- Un control negativo: el mismo comando sin `--dry-run` sí envía, y el log lo distingue.
- Que la salida del dry-run enseñe la línea del PR (`**PR #N · … · mergeado a main**`), que es lo
  que hace falta comprobar en cada cierre.
- Ojo al arreglarlo: `--probar` (`:1961`) cae en la misma cadena y detrás de `--avisar`, así que
  tiene el mismo problema. Los dos se arreglan igual — mover la comprobación de los dos flags
  **antes** del despacho por modo, o hacer que `modo_avisar` los respete.

## Medido en 2.1 (triage 2026-10-08)

- `~/.claude/hooks/avisar_grok.py` (fichero del 7-oct): `main()` sigue comprobando `--avisar` (`:2162`) antes que `--dry-run` (`:2164`) y `--probar` (`:2166`).
- `modo_avisar` (`:1991`) no mira `--dry-run` ni `--probar` en ningún punto: compone y llama a `despachar` (`:2076`).
- La ayuda sigue prometiendo «NO envia» (`:185`). Los tres commits del fichero desde el 09-sep (`9cc2a14`, `30ec1b1`, `4ef9a98` en el git de `~/.claude`) no tocan el orden.

Triage 2026-10-08: abierto · medium → low · `main()` de `avisar_grok.py` sigue despachando `--avisar` (`:2162`) antes que `--dry-run` (`:2164`); tooling de `~/.claude`, sin datos en riesgo.
