---
description: Higiene de documentos — reindexa DECISIONS, archiva lo cumplido y detecta punteros rotos
allowed-tools: Bash(python3 scripts/reorg_docs.py:*), Bash(python3 scripts/glosario.py:*), Bash(python3 scripts/indice_readme.py:*), Bash(python3 scripts/frescura.py:*), Bash(python3 scripts/indexar_doc.py:*), Bash(git:*), Bash(ls:*), Bash(find:*), Bash(wc:*), Read, Glob, Grep
---

Higiene de **Yala**. **Nunca borra nada**: solo mueve a historial. Un informe al final.

> Este repo tiene su propia variante del estándar y es deliberado: el estado se llama
> `docs/ESTADO.md`, las decisiones van **por fecha** (`## AAAA-MM-DD Título`) y no por `ADR-NNN`,
> y no hay `CHANGELOG.md` — el rastro cronológico lo dan `tickets/` y `git log`.
> **No fuerces los nombres de la casa aquí.** Lo que tiene que ser igual entre repos es qué
> trabajo hace cada documento, no cómo se llama el fichero.

## 1 · Reindexar

`docs/DECISIONS.md` son **234 KB en un solo fichero**: es el que más lo necesita de todo el
sistema, y hasta el 2026-08-30 era el único repo sin el script.

```bash
python3 scripts/reorg_docs.py --repo . --dry-run
python3 scripts/reorg_docs.py --repo . --apply
```

**`split_adrs.py` no aplica** y no se copia: parte por `## ADR-NNN` y aquí las entradas van por
fecha. Forzarlo rompería 79 entradas.

Y el índice de entrada y el glosario:

```bash
python3 scripts/indice_readme.py --repo . --apply
python3 scripts/glosario.py --repo . --apply
```

## 2 · Documentos que ya cumplieron

Busca en `docs/sessions/`, `docs/planning/` y `docs/modo-nube/`: archivos con fecha en el nombre
y más de 30 días, o artefactos de un solo uso ya aplicados. Mueve con `git mv` a
`docs/_archive/`. **Ante la duda, se queda.**

Los tickets tienen su propio ciclo (`tickets/done/`, `tickets/discarded/`) — **no los toques
aquí**: moverlos es trabajo de `/cerrar`, no de higiene.

## 3 · Punteros rotos y sellos que mienten

- Rutas absolutas (`/Users/...`) de `CLAUDE.md`, `README.md` y `docs/ESTADO.md` que no resuelven.
- **El sello `updated:` de `docs/ESTADO.md` contra `git log` del propio fichero.** Un sello a mano
  miente en cuanto alguien se olvida; ese olvido es lo que buscamos.
- Cifras y estados que un documento afirma y ya no son ciertos (número de build, rama, «rojo
  conocido»). Son afirmaciones verificables y comprobarlas cuesta un `grep`.

## 4 · Los topes

- **`docs/ESTADO.md`: máximo 40 líneas** — el mismo número que `/cerrar`. **El número avisa, no
  manda:** si se pasa acumulando lo cerrado, fuera; si lo que hay dentro sigue vivo, no se toca.
- **Cualquier fichero de referencia de más de 100 líneas necesita índice arriba.**
  `python3 scripts/indexar_doc.py <fichero> --apply`. `docs/glosario.md` está exento.

## 5 · Frescura

```bash
python3 scripts/frescura.py --repo .
```

Señal, no veredicto: por cada documento que salga, mira si lo que **afirma** sigue siendo cierto,
no si tiene polvo. En este repo la documentación envejece más rápido que el código.

## 6 · Informe

Tabla: acción · qué · antes → ahora. Cierra con cuánto contexto vivo se recuperó.

## Reglas

- No borres. No commitees (eso es de `/cerrar`).
- Verifica que no se perdió nada: cuenta los bloques `^## ` en vivo + archivo, antes y después.
  Si no cuadra, `git restore` y repórtalo.
- Si un documento está **mal** (no viejo: mal), dilo en el informe en vez de archivarlo en silencio.
