---
id: adopt-lineage-block-for-foreign-data-takes-fifteen-minutes-to-say-so
status: backlog
priority: medium
area: "cloud sync, welcome"
created: 2026-11-13
updated: 2026-11-13
source: "Resto del ticket adopt-lineage-block-shows-connecting-for-fifteen-minutes (QA del 13-nov en el iPhone 14)"
---

# Cuando el adopt bloquea de verdad por datos ajenos, tarda 15 minutos en decirlo

## Qué pasa

La causa del bloqueo que vivió Jürgen (el puente de Grupos creando filas antes del claim) está resuelta. Queda el caso
legítimo: el teléfono tiene datos que NO son de la cuenta (`cloudAdoptLineageBlocked noSharedRows`). La app ya sabe a los
30 s que no va a entrar (`cloudForwardStepWaiting = adopt|…|stop_lineageUnproven`, importación quieta), pero la pantalla
sigue en «Conectando con tu cuenta… 60 %» hasta el techo corto de 15 min, y cada reintento (≈30 s) vuelve a bajar la cuenta
entera (`/sync/pull` desde 0 + `/sync/merkle`, ~25 s por vuelta).

## Lo que hay que decidir (del ticket original)

1. Con `noSharedRows` **y** la importación quieta, ¿salir ya a la pantalla de «no coinciden» en vez de esperar 15 min? La
   espera legítima (lo que aún se importa) ya la frena antes la quiescencia.
2. Mientras se espera, no repetir la enumeración entera en cada vuelta, o espaciarla.
3. Que «Reintentar» no prometa nada que no puede cumplir: el texto de la salida ya existe (`effectLineageUnproven`).

Es lógica de sync: va con review adversarial. Toca `MigrationRunner.observeAdoptEffectFailure` y el techo corto del efecto
del adopt (regla «Y el EFECTO del adopt también» de `.claude/rules/swiftdata-cloudkit.md`).
