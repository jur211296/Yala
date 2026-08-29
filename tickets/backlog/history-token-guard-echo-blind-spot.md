---
id: history-token-guard-echo-blind-spot
status: backlog
area: sync
priority: low
created: 2026-08-29
updated: 2026-08-29
source: docs/aprendizajes-tecnicos.md
---

# ACEPTADO · el guard del token tiene el mismo punto ciego del eco

## Estado: aceptado, no es deuda por olvido

Está en el tablero para que sea **visible**, no para atacarlo. El documento lo dice por escrito:
**«No se arregló a propósito.»** Verificado vivo el 2026-08-29 (`recoverIfHistoryTokenIncomparable`,
4 líneas de código).

## Qué es

`recoverIfHistoryTokenIncomparable` construye su lista `missing` **excluyendo el eco**. En un
device que solo recibe, esa lista sale siempre vacía y el guard declara el token válido
(`validatedByCompare`) sin re-anclar. Sonda: `incomparable=0 recovered=0`; el gasto local de esa
sesión no se captura y sí lo hace tras relanzar, porque `historyTokenValidated` es de sesión.

## Por qué se aceptó

El disparador no se materializa en la práctica: cualquier cosa que borre o conmute el store toca
también `syncMeta`, donde vive el cursor ⇒ **el cursor nunca sobrevive a su propio store**. Lo
que queda vivo es solo lo que el autor del guard ya dejó escrito: «una eventual no-comparabilidad
en relaunch normal», **sin cuantificar**.

La exclusión del eco es **idéntica en el canal personal** (`CloudSyncEngine.swift:1489`), así que
es patrón heredado, no una divergencia del molde.

## Qué lo reabriría

Cuantificar esa «eventual no-comparabilidad en relaunch normal». Hoy nadie la ha medido.

## De dónde sale

[docs/aprendizajes-tecnicos.md#defaulthistorytoken-es-por-store-y-un-drain-que-ancla-su-high-water-en-el-store-equivocado-q](../../docs/aprendizajes-tecnicos.md#defaulthistorytoken-es-por-store-y-un-drain-que-ancla-su-high-water-en-el-store-equivocado-q)
