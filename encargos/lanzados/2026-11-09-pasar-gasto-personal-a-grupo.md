---
esfuerzo: high
toca: Yala/App/Views/Transactions/,Yala/App/Views/Records/,Yala/App/Views/Groups/,Yala/App/Logic/,Yala/App/ViewModels/,YalaTests/,YalaUITests/
release: no
---

# Pasar un gasto personal a un grupo desde Editar en Registros

## Contexto
Pedido de Jürgen (7-nov-2026, 12:22 Lima), confirmado en la cola oficial del 9-nov-2026: «Poder convertir una transacción personal en una de grupo directamente desde la edición de transacción en Registros». Es una función de la 2.3 (card del tablero «2.3 · Pasar una transacción personal a un grupo desde Editar en Registros», versión 2.3).

Elegibilidad ya decidida por Jürgen (7-nov, 12:28 Lima): «Solo gastos personales; ingresos y transferencias quedan fuera». La opción aparece SOLO al editar un gasto personal. No hay pregunta pendiente sobre eso.

Orientación verificada (no son decisiones de producto): `NewTransactionView` en `Yala/App/Views/Transactions/` recibe `transactionToEdit` y ya protege los registros ligados a Grupos. `GroupExpenseComposerView` elige el grupo y remonta `GroupExpenseFormView` por id; este deriva moneda, miembros, reparto y pagador en su `init`. Revisa `GroupExpenseViewModel` y `GroupTransactionBridge`: reutiliza esos mecanismos, no construyas un segundo circuito. Al 9-nov no había PR ni rama con esta función; vuelve a comprobarlo al arrancar (PRs abiertos y mergeados en jur211296/Yala).

Aviso relacionado: Jürgen reportó el 9-nov un bug grave en 2.2 en el mismo puente (gastos de grupo con cuenta y subcategoría que dejan borradores «Gasto compartido» en la Bandeja y duplican el «Préstamo a grupos» en Registros). Lo arregla otra sesión aparte, en 2.2. Aquí NO lo arregles, pero tu conversión no debe producir ese síntoma: los tests deben comprobar que no queda borrador en la Bandeja ni «Préstamo a grupos» duplicado.

Rama base: `origin/2.3` en jur211296/Yala. Lee `CLAUDE.md` y solo los ADR vigentes del puente de Grupos antes de editar.

## Qué se pide
1. Entrada desde Editar de un gasto personal en Registros: elegir grupo y reparto con los componentes actuales y revisar antes de confirmar.
2. Conservar importe, moneda, fecha, notas, adjuntos y cuenta según las capacidades y reglas EXISTENTES. Si algo no se puede conservar, dilo y consulta; nunca lo descartes en silencio.
3. No es «copiar» dejando dos gastos: el original queda vinculado como origen, sin duplicar el gasto ni cargar dos veces los saldos personales o del grupo. Aplica las invariantes existentes del puente y los permisos; nada de migraciones silenciosas ni redondeos o conversiones de moneda nuevos.
4. Cancelar en cualquier punto deja datos y saldos intactos. Confirmar es idempotente ante doble toque o reintento; un error no borra el original ni deja la conversión a medias. Cubre grupo eliminado o permiso perdido con la hoja abierta, y que Registros se actualice después de convertir.
5. Excluye registros que ya son de grupo, archivados, ingresos y transferencias.
6. Tests: elegibilidad, conservación de campos, cancelación, error/reintento/doble toque, vínculo único, sin borrador en Bandeja ni «Préstamo a grupos» duplicado, y saldos antes/después con igual y distinto reparto y moneda según lo que hoy se soporta.
7. Capturas antes/después (entrada, selector y reparto, resultado) con datos ficticios en `capturas/antes.png` y `capturas/despues.png`; revisa accesibilidad, teclado, texto grande e iPad donde aplique.
8. Dependencias: arrancas sobre `origin/2.3` sin esperar CI ni el PR anterior; justo antes de abrir el PR, `git fetch` y un solo rebase sobre `origin/2.3`, y build y simulador una vez después. Sin merge masivo de 2.2. Solo si otra sesión toca el mismo archivo o necesitas su código, esperas su merge.
9. Simuladores: en la Mini, máximo 1; en la Max puedes usar un segundo simulador (tope 2) aunque otra sesión de otro proyecto use uno, o el iPhone 14 conectado por DeviceMCP. Pipeline serial: limpiar solo lo propio o huérfano cerrado, build `xcodebuild -jobs 2` sin simulador encendido, luego bootear, probar, y apagar y borrar solo lo que encendiste (simulador, DerivedData propio, temporales).
10. Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Qué NO hay que tocar
- Ingresos, transferencias ni nuevas clases de transacción o ingresos de grupo.
- El bug de borradores y duplicados de 2.2 (lo arregla otra sesión).
- marketing/, producción, auth, colas, datos reales, dispositivos de Jürgen ni trabajo de otras sesiones.
- Commits y PR sin firma de IA (nada de «Generated with Claude Code», «Co-Authored-By» ni enlaces de sesión).

## Cómo se sabe que está bien
- Desde Editar de un gasto personal se pasa a un grupo y queda un solo gasto, vinculado, con saldos correctos; ingresos y transferencias no ven la opción.
- Tests nuevos en verde junto con el gate del proyecto; capturas antes/después.
- Un PR a `2.3` que explica la elegibilidad, cómo evita duplicados y los saldos comprobados. Cierre autónomo (cierra-sola) si queda completo; una duda material no resuelta no se da por terminada.

## Paso 0 (decidido por la sesión, modo semi, 2026-11-09)

Medido antes de decidir: `TransactionItem` no tiene adjuntos (ningún campo de foto o archivo); el puente ya sabe
**enlazar un movimiento existente** como pata real de un gasto de grupo («¿Ya lo apuntaste?», L13-15,
`DraftService.linkGroupExpenseDraft`) y su Caso A conserva ese registro (preserve+update: cuenta, nota, etiquetas,
necesidad y subcategoría intactas). La función reutiliza ese circuito; no hay segundo camino.

1. **Mecánica**: se crea el `SplitExpense` (pagador = tú) y el registro original pasa a ser su pata real
   (`splitExpenseID`); el puente añade solo el «Préstamo a grupos» de lo que te deben. Un guardado. Si algo falla
   antes de guardar se deshace solo lo propio (el contexto es compartido: sin `rollback()`).
2. **Fijo en la revisión** (se conserva, no se edita): importe, moneda, fecha, cuenta y «pagaste tú». Editable: nombre
   del gasto en el grupo, categoría (solo de gasto) y reparto. Cambiar el importe o la fecha reescribiría el registro.
3. **Elegible**: gasto, sesión con finanzas personales, cuenta real no archivada en la moneda del registro, sin puntero
   de grupo, sin transferencia ni ajuste de saldo, no es registro de un pago de grupo ni conservado al desasociar, y
   sin «Mi parte» (su importe es solo tu parte: pasarlo reescribiría lo que salió de la cuenta). Con «Mi parte» se dice
   por qué no se ofrece, no se esconde.
4. **Sin borrador en la Bandeja**: el enlace va con `withSkippedDraftCleanup`, como L13-15 (un registro sin categoría no
   pide clasificarla otra vez). Con el puente apagado no sale el «¿Lo registramos?»: el registro ya existe.
5. **Idempotente**: el formulario no guarda dos veces; el servicio, si el registro ya apunta a un gasto de ese grupo, lo
   devuelve sin crear otro; si apunta a otro, falla sin tocar nada.
6. **Entrada**: botón «Pasar a un grupo» bajo las acciones del editor (la fila de acciones no admite una sexta en un
   iPhone SE). Con cambios sin guardar en el editor no se ofrece hasta guardar o descartar.
7. **Al terminar**: el editor se cierra y sale el aviso «Pasado a <grupo>» con «Ver», el mismo de convertir un borrador.
