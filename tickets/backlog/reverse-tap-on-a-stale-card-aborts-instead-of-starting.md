---
id: reverse-tap-on-a-stale-card-aborts-instead-of-starting
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` (2026-09-21), lente del aviso — medido con el test del propio ticket"
---

# Tocar «Volver a iCloud» con la tarjeta desfasada cancela la vuelta anterior en vez de empezar una nueva

## El problema, en lenguaje de usuario

Toco «Volver a iCloud». Sale un aviso diciendo que no se pudo terminar, lo cierro, y **no pasa nada más**: no hay
barra, sigo en la nube. Si vuelvo a tocar el mismo botón, ahora sí empieza. Desde fuera, el botón no funciona a la
primera.

## Por qué pasa (medido el 2026-09-21)

Ocurre cuando la pantalla pinta la tarjeta de «Volver a iCloud» mientras el journal todavía está en una de las cuatro
fases previas al montaje de una vuelta anterior.

`CloudMigrationController.startReverse` emite `reverseActivated` y `reverseConfirmed`. Desde una fase previa al montaje
los **dos eventos son inválidos** y la máquina los ignora — pero `MigrationRunner.submit` llama a `drive()` igual, y
`drive()` conduce la fase que hay. Si el techo de esa fase ya venció, la vuelta **sale a su origen dentro del toque**.
Resultado: el gesto aborta la vuelta vieja y no arranca ninguna.

Lo fija, sin proponérselo, el test del ticket que lo destapó
(`MigrationRunnerTests.startReversePair_exitsTheCeilingOnlyWhenTheJournalWasAlreadyInTheStage`, caso B): la fase acaba
en `.done` y el testigo de salida queda anotado.

**El aviso no lo causa, lo hace visible.** Desde el 2026-09-21 ese camino sí dice algo —antes era silencio total—, pero
lo que dice es cierto de la vuelta *anterior*, no del gesto que la persona acaba de hacer. Con el aviso puesto, el
silencio se cierra y el gesto sigue perdido.

## Qué habría que decidir

1. **Si el toque debe re-intentar solo** tras abortar la vuelta vieja: sería un segundo `startReverse` encadenado, y
   hay que mirar qué pasa si el aborto dejó un `reverse_abort` sin llegar al servidor.
2. **O si debe no hacer nada y refrescar**, dejando que la persona toque una segunda vez sobre una tarjeta ya veraz.
3. **O si el problema es la tarjeta**, y lo que hay que arreglar es que no se ofrezca «Volver a iCloud» con el journal
   en una fase de vuelta (hoy `canStartReverse` lo decide con `journaledPhase`, que es una foto).

La opción 3 es la que cierra la clase entera; las otras dos tapan este síntoma.

## Criterios de aceptación

- [ ] Decidido 1-3 antes de tocar código.
- [ ] Un toque sobre la tarjeta desfasada acaba con la vuelta empezada, o con la tarjeta diciendo la verdad — nunca
      con «no pasó nada» y un aviso de la vuelta anterior.
- [ ] Lo que se decida no re-abre `reverse-tap-is-lost-while-a-resume-is-running`, que es la otra mitad de este botón.

## Relacionado

- `reverse-tap-is-lost-while-a-resume-is-running` — el mismo botón, el caso de «hay un resume en vuelo». Distinto: allí
  el runner ignora la acción por reentrada; aquí la ejecuta sobre la fase equivocada.
- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el que lo midió.
