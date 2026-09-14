---
id: activation-restore-start-fresh-keeps-the-imported-rows
status: backlog
priority: high
area: "onboarding, modo-nube, grupos"
created: 2026-09-14
source: "medido cerrando `restore-start-fresh-keeps-the-imported-corpus` (2026-09-14); NO reproducido en device"
---

# «Activar Yala completo → Restaurar → Empezar desde cero» borra la zona de iCloud y la vuelve a llenar

## El síntoma, en lenguaje de usuario

Uso Yala solo para grupos y decido activar Yala completo. Elijo «mi iCloud privado», la app me dice que
encontró mis datos de antes y toco «Traer mis datos». Los veo, cambio de opinión y toco «Empezar desde
cero». Termino el onboarding… y **mis datos viejos siguen ahí**.

Y si además tengo Yala en otro teléfono, allí también: lo que se borró arriba vuelve a subir desde aquí.

## Lo medido (2026-09-14, árbol `799e01a3` + el PR de `restore-start-fresh-keeps-the-imported-corpus`)

- El botón lo cablea `FullModeActivationView.swift`, `case .restore` → `onStartFresh: { go(to:
  .onboarding(.freshPrivate)) }`. **No borra nada**, igual que el del Welcome antes de ese PR.
- Y el arreglo del Welcome —mandar el botón a la puerta de iCloud— **aquí no sirve tal cual**. La puerta
  de la activación borra SOLO la zona (`performICloudZoneWipe` → `performICloudCorpusWipe(includingLocalRows:
  false)`), y eso es una restricción del paso 8 que sigue viva: `DataWipeService.wipeAllUserData` resetea
  `hasCompletedOnboarding`, el modo y el nombre, así que borrar lo local mandaría al Welcome a quien está
  activando —y con `FullModeActivationResumeStore` a medias.
- Pero para llegar a `.restore` por este flujo **hubo relanzamiento** (`WelcomeMirrorRelaunchLogic
  .requiresMirror(.fullActivationRestore) == true`), así que el store personal **espeja**: tras el
  relanzamiento `personalStoreDecision` cae en `iCloudAvailable ? .iCloudMirror : .localNoMirror`, y los
  dos adjuntan el mirror (`attachesCloudKitMirror`).
- ⇒ borrar solo la zona deja las filas importadas en el store, y `NSPersistentCloudKitContainer`
  **re-exporta** a la zona recién creada. Un borrado que no borra, bajo un copy que promete lo contrario.

## Por qué no se cerró con su hermano

Cerrarlo pide un borrador que **no existe**: filas personales sin tocar preferencias.
`wipeAllUserData` hace las dos cosas en un solo gesto, y su `resetAllUserPreferences`
(`DataWipeService.swift:553`) va mucho más allá de quitar keys — resetea `AppRouter`, `ProTourManager`,
`SetupChecklistManager` y los espejos del App Group. Partirlo es un objeto propio, con su propio riesgo
sobre un método destructivo que comparten «Vaciar datos» y el wipe remoto.

## Qué hay que decidir antes de escribir

1. **¿Se parte `wipeAllUserData`** (un `resetPreferences: Bool = true`, default que preserva el
   comportamiento de hoy) **o se escribe un borrador nuevo** que solo enumere los modelos? Lo primero es
   menos código y más superficie compartida; lo segundo, al revés.
2. **¿Qué pasa con el dominio de Grupos?** Aquí NO se purga: los grupos son de la misma persona que está
   activando y la activación existe para conservarlos (ADR §6). Eso lo separa del «empiezo de cero» del
   Welcome, que sí es un handover.
3. **¿Y las preferencias residuales?** La puerta de la activación pasa `clearsResidualPreferencesOnWipe:
   false` a propósito: ahí el nombre y la divisa son el prefill de quien activa. Tras un «empezar de
   cero» desde Restaurar, ¿siguen siendo suyos, o son los que acaba de descartar?

## Criterios de aceptación

- [ ] **DEVICE** · Solo-grupos → «Activar Yala completo» → privado → la puerta encuentra corpus →
      «Traer mis datos» → Restaurar → «Empezar desde cero» → tras el onboarding y esperar a que iCloud
      sincronice, **no aparece ningún dato previo**, ni aquí ni en un segundo dispositivo con el mismo
      Apple ID.
- [ ] La sesión de grupos queda **intacta**: los grupos, sus gastos y el modo siguen donde estaban, y la
      persona no acaba en el Welcome.
- [ ] El recorrido del Welcome (`restore-start-fresh-keeps-the-imported-corpus`) sigue verde.

## Relacionados

- [[restore-start-fresh-keeps-the-imported-corpus]] — el mismo botón por la puerta del Welcome, cerrado
  el 2026-09-14. Su test `activationKeepsItsOwnExit` **pinnea la asimetría** y se pondrá rojo cuando este
  ticket se ataque: es su aviso de que hace falta el borrador nuevo, no un obstáculo.
- [[late-icloud-wipe-can-re-export-between-its-two-halves]] — la misma re-exportación, pero por un kill
  entre las dos mitades del borrado. Aquí la segunda mitad no corre nunca, por diseño.
- [[full-mode-activation-must-ask-where-personal-data-lives]] — el paso 8, de donde sale la restricción.
