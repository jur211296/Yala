---
id: ai-model-choice-lives-in-the-app-binary
status: backlog
priority: high
area: ai, gateway
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H15)
---

# El modelo de IA está escrito en la app: cambiarlo exige una release

> **Grupo: para Jürgen.** Arquitectura del contrato app ↔ gateway. Decide cómo se harán todos los
> cambios de modelo futuros.

## Qué pasa

Cada servicio escribe su modelo (`.gpt4_1_mini` en 8 sitios, `.gpt4_1_nano` en 3, `.whisper_1` en 1) y
el gateway lo reenvía sin mirar. Consecuencias:

- Cambiar de modelo exige release, y las versiones viejas siguen con el viejo. El apagado de
  `gpt-4.1-nano` el 23-oct (`gpt-4-1-nano-shuts-down-on-october-23`) es el primer caso real.
- No se puede probar un modelo nuevo con un % de usuarios.
- El sitio natural para partir la IA por modo nube o privado (card de 2.2) es el gateway, y hoy no
  decide nada.

## Opciones

| | Qué se hace | A favor | En contra |
|---|---|---|---|
| **A** | El gateway elige el modelo **por categoría** (`X-Yala-Category`) y por tarea, e ignora el que mande la app | Un cambio de modelo es un deploy del Worker. Sirve para A/B y para modo nube/privado | Hay que añadir una cabecera de **tarea** (la categoría `suggestions` hoy mezcla clasificador, sugerencias y reescritor; `insights` mezcla cinco). Parámetros que dependen del modelo (`reasoning_effort`, `temperature`) también pasan al gateway |
| **B** | La app sigue mandando el modelo, pero el gateway tiene una **tabla de sustitución** (modelo pedido → modelo usado) | Cambio mínimo y compatible con todas las versiones. Resuelve los apagados | No permite elegir distinto por tarea si dos tareas comparten modelo |
| **C** | Dejarlo como está | Nada que hacer | Cada apagado de OpenAI es una carrera contra App Review |

## Recomendación

**B ya** (es lo que pide el apagado del 23-oct y se hace en un día), **A en 2.2** junto con la card de
partir la IA por modo. B absorbe `gateway-proxies-any-model-and-any-length`.

## Hecho cuando

- Opción B: tabla en el gateway con tests; la app actual funciona sin cambios.
- Opción A: además, cabecera de tarea en la app y la elección de modelo documentada en el gateway.
