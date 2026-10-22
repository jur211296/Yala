---
name: instrumentar-gana-a-razonar
description: Cuando ya cayeron varias hipótesis, deja de razonar y CUENTA — envolver fetch/la llamada cuesta 20 líneas y da el número; y un fenómeno que no se reproduce no se explica, se acota
metadata:
  type: feedback
---

**Cuando un diagnóstico lleva tres o cuatro hipótesis caídas, el problema no es que falte la
hipótesis buena: es que se está razonando sin datos. Instrumenta y cuenta.**

**Why:** el 2026-09-08, `goldens-de-staging-solo-pasan-a-trozos` llegaba con **cuatro hipótesis
refutadas** y una quinta a medio formular. Envolver `globalThis.fetch` en un `setupFile` de vitest
—20 líneas, un JSONL con `{test, path, status, startMs, durMs}` y hooks `beforeEach`/`afterEach`—
dio en **una corrida** lo que cuatro rondas de razonamiento no habían dado: 32 793 peticiones por
corrida, el 99,7 % de ellas en cinco tests, la fórmula exacta del coste (`1 + 5×N` por pull) y la
prueba de que la latencia **no** degradaba (mediana plana en 199-253 ms con 30 peticiones en vuelo).

Es la misma lección que la sonda de tres `print` del 401 de App Attest, que también llegó después de
cuatro hipótesis plausibles y falsas. **Cuando el coste es invisible, medirlo es más barato que
deducirlo.**

**How to apply:**

- **El umbral es «dos hipótesis caídas»**, no cinco. A la tercera, para y pregúntate qué contador te
  daría la respuesta directamente.
- **Instrumenta el borde, no el interior.** El punto de envoltura casi siempre es la llamada que
  cruza el proceso: `fetch`, el cliente HTTP, el RPC. Ahí pasa todo y no hay que entender el código
  de en medio.
- **Vuelca a fichero y analiza aparte.** Un JSONL + un script de 20 líneas de Python se re-consulta
  y contesta preguntas que no habías hecho al medir. Los `print` en consola se pierden.
- **Predice antes de medir el siguiente caso.** Con la fórmula en la mano predije 156 s para un test
  y dieron 130 s. Una predicción que acierta convierte una correlación en un mecanismo; sin ella,
  sigues teniendo una coincidencia. Ver [[mutante-compilado-zanja-hipotesis]].
- **Los andamios no se commitean.** Sonda y config viven fuera del árbol o en un directorio ya
  ignorado (en el gateway, `node_modules/.probe/`), y se retiran antes del commit.

## La otra mitad: lo que no se reproduce, no se explica

En esa misma sesión los **10 timeouts del ticket no se reprodujeron** — ni corriendo el fichero solo
ni dentro de la suite entera. La tentación era nombrarles una causa, porque había una candidata
elegante (el corpus acumulado) y encajaba con la aritmética.

**No se hizo, y esa es la decisión correcta.** Lo que se entregó en su lugar:

1. **El margen medido** — cuánto de su timeout consume hoy cada test (el más ajustado, el 55 %), que
   convierte «se rompe a veces» en «se rompe si el tiempo se multiplica por 1,8».
2. **Las candidatas que quedan vivas, dichas como candidatas**, con por qué no se pueden separar a
   posteriori.
3. **La que sí se pudo refutar**, con su medición (el paralelismo entre ficheros: 313 s contra
   311 s).

**Why:** un fenómeno intermitente al que le pones causa sin tenerlo delante te deja con un ticket
cerrado y el problema vivo — y peor, con una explicación escrita que el siguiente leerá como hecho.
Es exactamente cómo nace la clase de premisa de [[la-premisa-del-encargo-tambien-se-mide]].

**How to apply:** si el síntoma no aparece, dilo en la primera línea del cierre y entrega el margen
en su lugar. «No lo reproduje; aquí está lo que sí sé y a qué distancia está de romperse» es un
resultado. «Probablemente era X» no lo es.
