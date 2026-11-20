---
name: el-titulo-de-sentry-no-es-la-pantalla
description: El título de una card de cuelgue (y el «culpable» de Sentry) no dicen en qué pantalla pasó; la pila sí. Leer el evento antes de aceptar el área del encargo.
metadata:
  type: feedback
---

Antes de arreglar un cuelgue de Sentry, baja el último evento por API (`reference-sentry-tokens-y-api`) y lee la pila
entera: el título y el «culpable» (`TransactionItem`, una función de un fichero) no dicen dónde corría.

**Why:** 20-nov-2026, encargo «Registros sin trabas»: tres cards de cuelgue con nombres de Registros. Las tres pilas
eran del Flujo de caja (motor del mes, índice de líneas). Un frame `RecordsMonthSectionsLogic.monthKey` era otra función
con el mismo cuerpo fusionada por el enlazador: el símbolo mentía sobre la pantalla.

**How to apply:** primera acción del encargo; si la pila contradice el área, se arregla donde dice la pila, se anota en
el Paso 0 y se amplía `toca:` tras comprobar que nadie más toca esos ficheros. Dos funciones idénticas en el binario
pueden compartir símbolo: si un frame «no encaja», busca su gemela.
