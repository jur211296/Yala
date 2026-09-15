---
id: queued-offer-after-dismiss-flakes-on-a-cold-simulator
status: backlog
priority: low
area: "testing, xcuitest, presentaciones"
created: 2026-09-15
source: "gate de `cloud-signout-collapses-a-groups-session-expiry-into-permanent` (2026-09-15)"
---

# La oferta que espera en la cola a veces no aparece al cerrar la hoja, con el simulador recién arrancado

## Lo que pasó (medido)

`AppleIDCloseNoticeUITests.test_notice_presentsThroughTheQueue_andLaterReleasesTheRouter` cayó en su línea 86:
la oferta de prueba (`trial_offer_dismiss`) no apareció en los 45 s siguientes a tocar «Ahora no» en la hoja del
cambio de Apple ID. Fueron cuatro corridas del mismo binario (`test-without-building`), las cuatro con el
centinela del simulador sin intrusos:

| Corrida | Simulador | Caso | Duración |
|---|---|---|---|
| 1.ª | caliente; la corrida murió después, en otra clase, por falta de memoria del sistema | pasa | 23,2 s |
| 2.ª | **recién arrancado**: el apagón de la 1.ª lo dejó apagado | **falla** | 68,3 s |
| 3.ª | caliente | pasa | 22,7 s |
| 4.ª | caliente | pasa | 23,0 s |

Entorno durante las cuatro: 48 procesos `claude` vivos en la máquina y la swap entre 2,9 y 3,2 GB de 4.

**No lo introdujo el cambio de ese gate**: solo tocaba la traducción del motivo en el cierre de la nube, y este
test recorre la celda privada y la oferta en cola. Eso se razona leyendo el test; lo medido es que el mismo
binario pasa 3 de 4.

## Por qué tiene ticket aunque «la primera corrida tras arrancar no cuenta»

`.claude/rules/testing.md` da esa explicación por buena, pero la midió en iOS 27.0 y dice que en 26.x «se
absorbe». Esto es 26.5 y no se absorbió. Y es el segundo rojo de esta forma en dos días: el cierre del #168 anotó
que `RemoteWipeNoticeRoutingUITests` cayó una vez con el paywall sin presentar y dio 3 de 3 aislado, con la
hipótesis de una carrera entre drenar la cola y desmontar el aviso. Ese dato no está en ningún ticket y aquí se
cita de oídas. Con dos casos no se distingue latencia de carrera.

## Lo que hay que medir

1. **N corridas en frío contra N en caliente** del mismo caso, con `simctl shutdown` y `boot` antes de cada
   corrida fría. Si solo cae en frío, es latencia: basta con calentar el simulador antes o con subir la espera.
2. **Si también cae en caliente**, instrumentar el drenaje de la cola al cerrar la hoja. Si drena mientras la
   hoja se desmonta y la oferta se pierde, es la carrera de dos presentaciones del mismo anchor
   (`.claude/rules/swiftui-ds.md`), y eso sí le pasa a una persona.

## Criterios de aceptación

- [ ] Clasificado con los números del punto 1: latencia o carrera.
- [ ] Si es carrera, arreglada y con un test que la reproduzca antes del arreglo.
