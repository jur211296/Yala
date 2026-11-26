# Maquetas v2: Compartido, con Grupos y Personas (26-nov-2026)

Artifact para decidir (público): https://claude.ai/artifact/GxheqzBgnvRUcrdMAKyNGu
Card «Espera decisión» de Jürgen en el tablero de Yala 2.3: «Aprobar maquetas v2: Compartido (Grupos | Personas)».
La decisión se guarda en la base del artifact (`decisiones/compartido-v2`: `nombre`, una clave por pantalla con
`si` / `ajustar` / `no`, y `nota`).

- `index.html`: la página publicada. Cada pantalla nueva va al lado de su captura real de hoy.
- `capturas/`: capturas reales del simulador (iPhone 17 Pro, `origin/2.3` en `3eb19a261`, claro y oscuro) que sirvieron de
  molde, sacadas con un XCUITest temporal que no se commitea (semillas `grupos` + `-uitest-seed-group-cross-debts`,
  `realista`, `minimal` con sesión y consentimiento, invitación con `inviteOnboarding`).
- `maquetas-claro.jpg`, `maquetas-oscuro.jpg`: la página entera tal como se ve en el artifact.

Sigue la idea A de la primera ronda (`docs/propuestas/deudas-directas-con-personas/`): una persona es, por dentro, un
grupo de dos que no se ve como grupo.

## Qué cambió respecto de la v1

La v1 dibujaba piezas que la app no tiene. La v2 copia lo que hay y marca en rosa solo lo nuevo:

- La fila de captura real es **«Nuevo gasto · Voz · Foto · Yala IA»** (`GroupQuickActionsRow`). El encargo decía
  «Nuevo registro · Imagen · Foto · Yala IA»: se dibuja la real.
- El primer chip del detalle de grupo se llama **«Gastos»** (`groups.detail.records`), no «Registros». El detalle de
  persona repite «Gastos · Saldos · Estadísticas», con icono en los tres y nombre solo en el elegido, como hoy.
- Arriba de la lista no hay buscador (Jürgen, 30-oct): tampoco en Personas.
- Los chips «Grupos | Personas» son los de Planificación (`NavigationChipButton` con `showsTitleWhenUnselected`, en
  `navigationChipsInset`): debajo del título grande, como se ve en la captura de Planificación.
- El filtro de grupo del detalle de persona no es una fila nueva: es la cápsula que Estadísticas del grupo ya tiene
  («Todas», «Todo»), puesta junto al rótulo de la cifra en las tres páginas.
- El formulario de «Nuevo gasto» con «¿Con quién?» es aproximado: no se capturó `GroupExpenseFormView`. Se dibujó con
  las filas de «Gasto compartido» del formulario de registro (captura del 21-nov), y lo nuevo es esa fila en el sitio
  de «Grupo».

## Tomado del código (archivo por archivo, leído en `origin/2.3`)

| Pieza de la maqueta | De dónde sale |
|---|---|
| Título grande, botones de la barra (nuevo grupo, ajustes, avatar) | `GroupsContainerView` (`navigationTitle`, `toolbar`) |
| «Te deben en total», cifra, barra, «Debes / Te deben» | `GroupSummaryHeader`, `ArchivedDebtLine` |
| Fila «Nuevo gasto · Voz · Foto · Yala IA» | `GroupReceiptEntry.swift` (`GroupQuickActionsRow`) |
| Tarjeta de grupo con filas «X te debe» | `GroupCardView` |
| «Ver archivados (N)» plegable | `GroupsContainerView.archivedGroupsSection` |
| Estado vacío con pasos (cuenta, aceptar, crear) | `GroupsEmptyStepsCard`, `GroupsEmptyStepsLogic` |
| Chips «Presupuestos | Pagos planificados» | `PlanningView.navigationChipsBar` |
| Detalle: saldo, chips, páginas | `GroupDetailView`, `GroupBalanceHero`, `GroupRecordsView`, `GroupBalancesView`, `GroupStatsView` |
| Invitación: tarjeta, «Unirme», «Ya estás en» | `GroupInviteOnboardingView`, `WelcomeInviteOpeningView`, `GroupCreatedInviteSheet` |
| Textos | `Yala/Resources/es.lproj/*.strings` |

## Qué es nuevo

1. El nombre de la pestaña («Compartido») y los chips «Grupos | Personas».
2. La lista de Personas, con «Ver liquidadas (N)» al pie (mismo pliegue que los archivados).
3. En la barra de Personas, «Añadir persona» en el sitio de «Nuevo grupo».
4. El detalle de persona y su filtro de grupo («Todo · <grupos> · Sin grupo») en las tres páginas.
5. La etiqueta de grupo en cada fila de Gastos de una persona.
6. Saldar por grupo, solo lo sin grupo, o todo.
7. «Por grupo» en Estadísticas: cuánto te debe en cada grupo compartido.
8. La primera pantalla de la invitación a una persona (el resto de la invitación queda igual).
9. Vista completa sin grupos tras el onboarding, y «Nuevo gasto» sin grupo con «¿Con quién?».

## Nombre recomendado

**«Compartido».** Nombra lo que guardan los dos chips. Cabe en la barra de pestañas: es más corto que «Planificación»,
que ya cabe. En los 16 idiomas existe una palabra corta (Shared, Partagé, Geteilt, Condivisi, Compartilhado, 共有…).
Alternativas en el artifact: «Juntos» (cálido, pero no dice qué hay dentro), «Dividir» (verbo, choca con «Dividir una
boleta») y dejar «Grupos» (cero coste, pero Personas queda dentro de «Grupos»).

Término para lo que no está en un grupo: **«Sin grupo»** (se entiende solo y se traduce sin ambigüedad). Comparados:
«Libre» (se confunde con «gratis») y «Directo».

## Estimación para 2.3

Unas **6 a 7 sesiones**: 2 solo de vista y 4 a 5 que tocan datos o sincronización.

| Parte | Tipo | Sesiones |
|---|---|---|
| Nombre (16 idiomas) y chips; botón de la barra según el chip. `ConfigurableTab.groups` no cambia de id | Vista | 1 |
| Persona = grupo de dos con una marca nueva (SwiftData + manifiesto de Grupos) y neto por persona entre grupos | Datos | 1,5 |
| Lista de Personas, liquidadas, detalle espejo con la cápsula de grupo | Vista | 1 |
| Saldar por grupo, solo lo sin grupo o todo (una liquidación por grupo y moneda) | Datos y sync | 1 |
| Invitar a una persona (mismo enlace; el servidor distingue persona y salta la aprobación) | Datos y servidor | 1 |
| Entrada sin grupo obligatorio, «¿Con quién?» y alta de persona al guardar | Datos | 0,5 a 1 |

## Riesgos

- **2.2 y la web no conocen la marca «de dos».** Verían el grupo de dos como un grupo más. Hay que decidir si va en una
  versión nueva del manifiesto (`group_capability_manifest.json`, columnas con `since`) y qué enseña la web.
- **La misma persona en dos grupos solo se reconoce si tiene cuenta.** Dos «Beto» sin cuenta en grupos distintos se
  quedan aparte hasta que entren.
- **Saldar todo con varias monedas** escribe varias liquidaciones; el desglose bajo la cifra tiene que dejarlo claro.
- **El nombre nuevo**: 45 textos en español dicen «Grupos» (medido en `es.lproj`), más la ficha y las capturas de la App
  Store, que son de Lola.
- **Pedir cuenta al guardar y no al entrar**: si la persona dice que no, hay que decidir si el gasto queda solo en sus
  finanzas o se descarta.
- **«Dividir una boleta»** crea personas temporales sin grupo: tienen que ser las de este chip, no otra lista.
