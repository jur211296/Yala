# Implementar ticket: activation-restore-start-fresh-keeps-the-imported-rows

## Contexto
Cola autónoma bypass. Hermano del #155 (Welcome ya arreglado): en «Activar Yala completo → privado → Restaurar → Empezar desde cero» el botón sigue sin borrar de verdad (borra zona, el store espeja y re-exporta).

## Decisiones de Jürgen (2026-09-14, paquete Frank)
- **2.1A** Partir `wipeAllUserData` con flag de preferencias (default preserva comportamiento actual); no un borrador totalmente nuevo salvo que 2.1A no baste.
- **2.2A** Dominio de Grupos **intactos** al empezar de cero desde activación.
- **2.3A** Preferencias residuales (nombre, divisa, prefill) **se quedan**.

MODO AUTÓNOMO HASTA TERMINAR: review adversarial, gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`. Device-QA → `tickets/qa/`.

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez. No avisar por test/build a reintentar ni CI advisory.

No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer ticket + hermano #155 + restricción del paso 8.
2. Implementar con 2.1A/2.2A/2.3A: tras el flujo de activación + «Empezar desde cero», no reaparecen datos personales (ni en 2º dispositivo); grupos intactos; no caes al Welcome.
3. El recorrido Welcome del #155 sigue verde (`activationKeepsItsOwnExit` se pondrá rojo a propósito — ajústalo).
4. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Wipe de prod. Borrar grupos en este flujo. Limpiar prefs residuales (2.3A).

## Como se sabe que esta bien
Criterios del ticket; tests; PR mergeado; `/cerrar-total`.

---

## Paso 0 — decisiones (resueltas en autónomo, bypass · 2026-09-14)

El árbol completo, con las coordenadas que lo sostienen, vive en el ticket
(`tickets/in-progress/activation-restore-start-fresh-keeps-the-imported-rows.md`, sección `## Paso 0`).
Aquí va el resumen para discutirlo en el PR.

**Partida:** Jürgen fijó 2.1A (partir `wipeAllUserData` con flag de preferencias), 2.2A (Grupos intactos)
y 2.3A (nombre, divisa y prefill se quedan). Lo medido añade dos cosas que ninguna de las tres preveía.

| # | Nodo | Decisión | Por qué |
|---|---|---|---|
| **D1** | ¿Adónde va «Empezar desde cero»? | A la **puerta de iCloud**, con un **case propio** (`.restoreDiscardGate`), no reusando `.privateGate` | Misma salida que el hermano (#155): la puerta mide contra CloudKit, enseña cifras, exige 2.º gesto y sobrevive a un kill. Case propio porque las dos entradas necesitan **borrados opuestos**: antes del relanzamiento lo local es de quien activa; después, lo local **es** lo que bajó el espejo. Un `Bool` al lado del step se hereda en silencio |
| **D2** | ¿Qué corta el flag de 2.1A? | `resetAllUserPreferences()` **y** `ProfileImageStorage.delete()`; **no** corta la reapertura de los seeds ni la limpieza de punteros a filas borradas | La foto vive fuera del reset (`:204` vs `:209`) y es identidad, como el nombre. El criterio del corte: *lo que describe a la persona se queda; lo que describe a las filas que acabo de borrar, se va* |
| **D3** | ¿Cómo se dicen las tres políticas de borrado? | Un **enum de scope** (`.zoneOnly` · `.importedRows` · `.handover`) en vez de sumar `Bool`s | Tres políticas, no dos; y dos `Bool` más permiten combinaciones que no existen (purgar Grupos sin borrar filas). Cuesta reescribir 4 aserciones que pinnean la firma literal, se traducen 1:1 |
| **D4** | Tras borrar, ¿se bajan `hasExistingData` / `hasPersonalData`? | Se **re-miden** con su fetch vivo, y la gracia del wipe remoto se cancela **antes** | `hasExistingData` cuenta también grupos, que aquí **siguen**: ponerlo a `false` sería mentir. Y un `hasPersonalData` cayendo con la gracia viva levanta el alert de wipe remoto, que **desmonta la sheet de la activación** |
| **D5** | El arm huérfano que sobrevive a una activación cancelada | **Fuera, con ticket** | Ya existe hoy con `.privateGate`; este PR lo vuelve más alcanzable pero no lo introduce |

**Los dos hallazgos que cambiaron el alcance** (los dos dejaban la app rota y ninguno estaba en el ticket):

1. **Sin reabrir el centinela del seed, la persona acaba SIN CATEGORÍAS.** Un alta solo-grupos deja
   `seedCategoriesExecuted == true` siempre, y `seedCategoriesIfNeeded` sale por su flag guard antes de
   mirar la base: el seed del final del onboarding es un no-op silencioso, y con él se va «Ajuste de
   saldo». ⇒ el flag de 2.1A **no basta solo**.
2. **La premisa del ticket sobre «el modo» es falsa.** `wipeAllUserData` **no** toca el eje 1
   (`cloudSync.hasPrivateSession` está en el prefijo que `removeUserPreferenceKeys` excluye a propósito
   y con test). Lo que rompe son `hasCompletedOnboarding` y `hasShownWelcomeChooser`, nada más.

Y una corrección al enunciado del encargo: **el botón no «borra la zona»** — no borra nada
(`FullModeActivationView.swift:152`). Quien borra la zona es la puerta, que es otro camino.
