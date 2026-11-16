# Conciliación de los PR abiertos contra 2.3 — 14-nov-2026

Fuente del artifact de la conciliación (https://claude.ai/artifact/Qk8sHpM8J3uNMLKa3ALpkY, privado). Medición en [`medicion.md`](medicion.md); los encargos de cada
continuación, tal como se encolaron, en [`continuaciones/`](continuaciones/).

## Lo que pasaba

Había 18 PR abiertos contra 2.3. Tres quedaban fuera por encargo: «Conectar Gmail» (borrador, no se mergea) y los dos
de esta tarde (tandas rojas de UI y presupuesto pasado), que cierran sus propias sesiones.

Los 15 restantes estaban **todos en conflicto** con 2.3, y 14 de ellos **en cola de auto-merge**. Sus sesiones habían
cerrado en modo cola: dejaron el PR en cola y movieron sus cards a «done» o «in qa». Después, el merge de otro PR los
dejó en conflicto, y la cola de GitHub no mergea un PR en conflicto ni avisa. Llevaban de 1 a 8 días así, con las cards
diciendo que el trabajo estaba hecho y el código fuera de la rama.

## Resultado

| PR | Qué es | Decisión | Motivo | Cards |
|---|---|---|---|---|
| [#954](https://github.com/jur211296/Yala/pull/954) | «Empezar» tras «¡Tu cuenta está lista!» lleva al Panel | **Cerrado: reemplazado** | #971 (hoy) arregla el mismo bug con la misma causa y el mismo arreglo, probado en el iPhone 14 | ya en done (correcto) |
| [#962](https://github.com/jur211296/Yala/pull/962) | Volver a tu iCloud sin atasco, iCloud vaciado = vacío | **Cerrado: va dentro de #973** | sus tres commits están en la rama de #973 | siguen con #973 |
| [#882](https://github.com/jur211296/Yala/pull/882) | Subir a TestFlight desde la Mini o la Max | **Cerrado: ya en 2.3** | el `CLAUDE.md` de 2.3 ya lo dice desde el 11-nov | — |
| [#973](https://github.com/jur211296/Yala/pull/973) | iCloud y cerrar sesión (lote B del barrido) | **Vigente, conflicto trivial** → continuación, cadena 1 (1.º) | solo choca en DECISIONS y el índice de QA | p9q0, zy1d, 4lld, atde, f8pd → blocked |
| [#930](https://github.com/jur211296/Yala/pull/930) | Nube: cifrado, fotos y exportar a la vista al activar | **Vigente, conflicto trivial** → cadena 1 (2.º) | solo TICKETS y el índice de QA | 1agd → blocked |
| [#910](https://github.com/jur211296/Yala/pull/910) | Nube: volver a tu iCloud y activar con borrado pendiente | **Vigente, conflicto de textos** → cadena 1 (3.º) | los dos nombres fijos (decisión 51) renombraron sus mismas claves | anfw → blocked |
| [#916](https://github.com/jur211296/Yala/pull/916) | Nube: «Cambiar de cuenta» y la hoja de soltar | **Vigente, conflicto de textos** → cadena 1 (4.º) | igual que #910; tal cual, deja rojo `DosNombresDeSitioTests` | izvv → blocked |
| [#899](https://github.com/jur211296/Yala/pull/899) | Cuentas: archivar saca del saldo y conserva el historial | **Vigente, conflicto de traslado** → cadena 1 (5.º) | el núcleo del conector se movió a `shared-core`; su rojo de CI fue el runner perdido | la de la decisión sigue en done |
| [#894](https://github.com/jur211296/Yala/pull/894) | Grupos: pagos sin duplicar, reparto sin dígitos perdidos | **Vigente, un hunk semántico** → cadena 2 (1.º) | choca con «saldar como en Splitwise» en el confirmado del pago | d8nx → blocked |
| [#943](https://github.com/jur211296/Yala/pull/943) | VoiceOver: cinco selectores con su nombre | **Vigente, conflicto trivial** → cadena 2 (2.º) | solo textos (añadir al final) e índice | 38yb → blocked |
| [#924](https://github.com/jur211296/Yala/pull/924) | Estadísticas: Tendencias y VoiceOver de las gráficas | **Vigente, conflicto trivial** → cadena 2 (3.º) | textos, índice y una viñeta de regla | 1yeg → blocked |
| [#920](https://github.com/jur211296/Yala/pull/920) | Nuevo registro: categorías a un toque y buscador | **Vigente, conflicto trivial** → cadena 2 (4.º) | textos, índice, regla y lista de exentos | 4xrs → blocked |
| [#912](https://github.com/jur211296/Yala/pull/912) | Nota de salud honesta (lote 1) | **Vigente, conflicto trivial** → cadena 2 (5.º) | textos, índice y memoria | la de la decisión sigue en done |
| [#922](https://github.com/jur211296/Yala/pull/922) | Registros: el calendario se pliega a la semana | **Vigente, conflicto semántico** → cadena 2 (6.º) | el calendario se movió en 2.3; hay que rehacer `RecordsTabView` | rjsz → blocked |
| [#818](https://github.com/jur211296/Yala/pull/818) | Tu IA registra en Yala | **Vigente en parte** → cadena 2 (7.º) | su cola de borradores la supera la cola común de Yala web; lo demás sigue faltando | o9b0 → blocked |

Ninguno se mergeó en esta sesión: ninguno estaba sin conflicto, y resolver incluso los triviales exige el gate con
simulador (ver `medicion.md`).

**Cards «en curso» sin sesión viva:** la guía visual de usuario nuevo y el onboarding 2.3 desde cero → **done**. La
primera tiene sus dos PR mergeados el 7-nov; la segunda desembocó en el diseño oficial de la bienvenida 2.3, ya construido.

## Cómo funcionan las continuaciones

- Cada una trabaja **sobre la rama del PR** (no abre otro), trae 2.3 con un merge, resuelve, pasa `/gate` y empuja.
- **Espera a que su PR quede mergeado** antes de cerrar (tope 90 min o dos vueltas). Es una excepción a propósito a
  «no se espera el CI»: estos PR se colgaron precisamente por cerrar sin esperar.
- Van en **dos cadenas** con `depende:`, para que no se dejen en conflicto entre ellas.
- Al mergear, devuelven sus cards de `blocked` a `in qa`.
- Pueden usar un segundo simulador en la Max o el iPhone 14 por Device MCP.

## Lo que esto destapa

El cierre en **modo cola** deja el PR en cola y da el trabajo por hecho, pero un conflicto posterior lo cuelga en
silencio: 14 PR y 14 cards en una semana. Falta quien vigile la cola: un barrido que busque PR en cola en estado
`DIRTY` y encole su continuación, o que el cierre en modo cola no mueva las cards hasta el merge.
