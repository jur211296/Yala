# Otros 7 formularios y 3 pantallas dejan de leer su modelo después de borrarlo

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `formularios-modelo-borrado-b` · Sesión cola **S34b** · al cerrar → **S35** (`grupos-admin-saldo-inicial`).

## Contexto
La sesión formularios-modelo-borrado (PR #708) arregló cuatro formularios y dejó el resto en `tickets/backlog/more-forms-read-their-deleted-model-while-closing.md`: otros 7 formularios y 3 pantallas (la más probable, la lista de presupuestos) pueden cerrar la app en iOS 27.x al leer el modelo borrado mientras se cierran.

Cards:
- `tablero ver tablero-otros-7-formularios-y-3-pantallas-dejan-gxa9`

## Qué se pide
1. Lee el ticket y el PR #708 y aplica el mismo patrón a los 10 casos (ViewModels, el `init` que el padre vuelve a ejecutar y el borrado de Grupos que es sync incluidos).
2. Test de regresión por caso o por patrón compartido.
3. Mueve el ticket a `tickets/done/`.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Comportamiento visible (solo evitar la lectura del modelo borrado). Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0

Decisiones auto-contestadas (MODO AUTÓNOMO, opción conservadora):

1. **Base.** El PR #708 sigue abierto (en cola de auto-merge, detrás de 2.2) y trae el ticket y el molde. La rama se
   apoya en su cabeza (merge local de `origin/encargo/2026-10-31-formularios-modelo-borrado`), sin tocar su rama ni
   su PR. Cuando #708 aterrice, el diff del PR queda solo con lo de aquí.
2. **Molde.** El de #708: copia previa de lo que pinta una alerta; accesor que mira `isDeleted || modelContext == nil`
   para lo que el `body` lee; el ViewModel suelta el modelo tras borrarlo; y el `init` que el padre vuelve a
   ejecutar mira antes de leer. Nada de vaciar una pantalla que se sigue viendo.
3. **Excepción: Ajustes del grupo al salir.** Su `body` lee el grupo en decenas de sitios. Se aplica el molde de
   `BudgetDetailView.isBudgetValid`: con el grupo ya borrado la lista no pinta filas mientras la hoja baja. Es el
   único cambio que puede verse, y solo en los fotogramas de cierre tras salir de un grupo.
4. **Listas padre.** La de presupuestos (la del ticket) y, por el mismo patrón, las de Categorías y Etiquetas: filtran
   lo que ya no se puede leer, como ya hace `AccountsSettingsListViewModel.accounts`.
5. **Dudosos.** Etiquetas: se copia el recuento de la alerta y, tras eliminar, el ViewModel suelta la lista que
   recorría la unicidad del nombre. `GroupSheet.id` deja de leer `id` del gasto (usa `persistentModelID`), y así no depende de si
   `.preserveValueOnDeletion` hace seguro el getter.
6. **Fuera:** el `body` de `GroupDetailView` tras salir del grupo (lee el grupo en barra, título y chips): no es
   copia de una línea y cambia la forma de la pantalla. Ticket aparte.
7. **Tests:** scans de cableado (molde `DeletedModelFormGuardWiringTests`) en un fichero nuevo, más unit de los
   mecanismos de ViewModel que se pueden medir en el simulador.
8. **Medido en el gate:** la guarda `isDeleted || modelContext == nil` dentro de un ViewModel tumbó 22 tests, porque los
   tests de ViewModel crean modelos sin contexto y `modelContext == nil` también vale para un modelo nunca insertado.
   La guarda del `init` pasa a la VISTA y el ViewModel suelta con una marca explícita (regla en `swiftui-ds.md`).
9. **Review adversarial (dos lentes).** Arreglado: el texto de «Salir con deuda» que el `body` de Ajustes del grupo
   evalúa fuera de las filas leía miembros borrados; la lista de Ajustes › Cuentas leía la cuenta borrada al rehacer la
   hoja y recorría registros borrados; dos scans casaban con otra ocurrencia más abajo (mutantes vivos). Sin tocar,
   anotado en el ticket: `Tag.id` y `expense.id` en hojas que solo un borrado por sync alcanza.

