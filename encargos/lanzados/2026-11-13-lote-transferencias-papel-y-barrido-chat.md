Yala
# Transferencias y ajustes se reconocen por su papel y el barrido del signo del chat no voltea lo nuevo
---
card: tablero-transferencias-y-ajustes-se-reconocen-po-y616
toca: Yala/Models/Subcategory.swift, Yala/Services/TransferCategoryResolver.swift, Yala/Services/TransferMigrationService.swift, Yala/Services/CloudSync/SystemEntityMergePolicy.swift, Yala/Services/CloudSync/CloudSyncReconciler.swift, Yala/Utils/TransactionCSVImportService.swift, Yala/App/Logic/ManualSubcategoryPickerLogic.swift, Yala/App/Logic/SubcategoryDedupLogic.swift, Yala/App/Logic/BridgedEditPolicy.swift, Yala/App/ViewModels/SubcategorySelectorViewModel.swift, Yala/App/Views/Categories/CategoryDetailView.swift, Yala/App/Views/Categories/SubcategoryDetailView.swift, Yala/Services/Groups/GroupTransactionBridge.swift, Yala/Services/Groups/GroupTransactionBridge+Receivables.swift, Yala/Services/Groups/GroupExpenseService.swift, Yala/Services/Groups/GroupSplitLinesService.swift, Yala/Services/EntityDeletionService.swift, Yala/Services/CategoryRecordsMoveService.swift, Yala/Services/InitialBalanceService.swift, Yala/Services/DraftService.swift, Yala/App/Services/ScheduledPaymentDraftService.swift, Yala/Services/ChatUnsignedExpenseRepairService.swift, Yala/App/Logic/ChatUnsignedExpenseRepairLogic.swift, YalaTests/ChatUnsignedExpenseRepairTests.swift, YalaTests/TransferNamesParityTests.swift, YalaTests/SystemFlagsModelTests.swift, YalaTests/ImportTransfersByLanguageTests.swift, YalaTests/TransferCategoryResolverLanguageTests.swift, YalaTests/SubcategoryStableRole/, tickets/backlog/transfer-and-adjustment-subcategories-need-a-stable-role.md, tickets/done/transfer-and-adjustment-subcategories-need-a-stable-role.md, tickets/backlog/chat-sign-sweep-stays-armed-until-the-first-transaction-of-a-new-install.md, tickets/done/chat-sign-sweep-stays-armed-until-the-first-transaction-of-a-new-install.md
esfuerzo: high
cierre: cierra-sola
---

Lote corto de dos bugs de 2.3. Rama base: 2.3; la 2.2 está cerrada. Lee cada card y su ticket (en `tickets/backlog/`).

1. `tablero-transferencias-y-ajustes-se-reconocen-po-y616` · Transferencias y ajustes se reconocen por su nombre, no por su papel. Bug reportado por Jürgen, decidido para 2.3. **Decisión de Jürgen (13-nov, registrada; reemplaza la del 29-oct de dejarla como estaba en S27l):** la subcategoría de transferencia que Yala crea al empezar es de sistema en todos los idiomas, no se borra ni se renombra. Yala reconoce las transferencias y los ajustes por un papel estable en el modelo (por ejemplo `systemRole`), nunca por el nombre. Una subcategoría que cree el usuario con el mismo nombre queda normal. Hace falta una migración que rellene el papel en las subcategorías existentes, local y en la nube, sin duplicar ni perder datos. El import, los selectores y el puente de Grupos usan el papel. Cuida lo que en S27l hizo dejarla normal: al volverse de sistema no debe perderse la clasificación que el usuario hizo en el puente de Grupos, ni romperse lo que hoy se elige a mano en en/de/nl/ja/zh. Mide cuántas filas tocaría la migración y deja ese dato.
2. `tablero-bug-en-una-instalacion-nueva-el-barrido-vp14` · En una instalación nueva, el barrido del signo del chat sigue armado hasta el primer registro. Lo creado en esta instalación (también un CSV de una sola fila con un reembolso) no lo voltea el barrido, y un corpus viejo que llega por restore se sigue reparando. Test para los dos casos.

**CloudKit:** el campo nuevo se despliega al entorno Development y se prueba ahí. Subirlo a Production es una decisión vital: pregúntala según el modo y no lo hagas sin el visto bueno de Jürgen. Déjalo anotado en el PR como paso del release.

**Pruebas:** tests que caigan sin el arreglo, incluida una migración desde un store 2.2 con las subcategorías sembradas en es y en en, y una creada a mano con el nombre de transferencia. Si quieres comprobar algo de punta a punta, usa el iPhone 14 por DeviceMCP (está conectado a la Mini) o un segundo simulador si otra sesión ocupa el primero. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera (otros lectores de `isAnySystem` o `transferNames`), que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR. Los tests nuevos van en `YalaTests/SubcategoryStableRole/`.

**Entrega:** un PR contra 2.3, mergeado si CI pasa, los dos tickets en done y las dos cards en QA. Commits y PR sin firma de IA. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en semiautónomo por Frank)

**Barrido del signo del chat**
1. Corte: la ventana del barrido cierra en el **primer arranque de esta instalación con un build que firma** (clave `chatUnsignedExpenseRepairSweep.windowClose.v1`), no en el arranque en que el barrido llega a correr. Lo creado después no lo voltea; lo restaurado conserva su `createdAt` viejo y sigue dentro. Descartado «marcar el flag en el alta sin restore»: el restore puede llegar tarde y el alta no lo sabe.
2. El cierre se fija en `AppBootstrapper` antes de esperar al store (el barrido corre hasta 2 min después). Cambio mínimo fuera de `toca:`.
3. Residual: quien instaló 2.2, registró algo sin relanzar y actualiza a 2.3 sigue expuesto (2.2 no apuntaba el cierre). Aceptado.

**Papel de las subcategorías**
4. Campo `Subcategory.systemRoleRaw: String?` (opcional, CloudKit sin default) y `systemRole` calculado. `isSystemSubcategory`/`isAnySystem` pasan a leer el papel: los ~30 lectores siguen sin tocarse.
5. Mientras el campo está vacío (store 2.2, filas de un build viejo, canal del Modo Nube que no lo lleva), `systemRole` deduce el papel de las que creó Yala (`isDefaultSeed`) por nombre. Una creada a mano (`isDefaultSeed == false`) queda normal.
6. Relleno en cada arranque, tras la quiescencia (`SubcategorySystemRoleBackfill`): escribe el papel; una del usuario con nombre de sistema solo lo toma si ya guarda movimientos de ese papel (el importador las creaba con `isDefaultSeed: false`).
7. La sembrada de transferencia de en/de/nl/ja/zh, que era normal, se **separa**: lo que el usuario apuntó en ella (movimientos sin `balanceAdjustmentType`, favoritos sin destino, programados, borradores, presupuestos con su espejo CSV, comercios y líneas del flujo) pasa a una copia SUYA con el mismo nombre. Protege lo elegido a mano y la clasificación del puente de Grupos.
8. El canal personal del Modo Nube **no** lleva columna nueva (exigiría DDL + Worker + manifest): cada teléfono deriva el papel con la misma regla sobre campos que ya viajan. Anotado como decidido sin consultar.
9. El importador reconoce por texto (único dato del archivo) transferencias, ajustes y los nombres sembrados de transferencia, y manda esas filas a la subcategoría con ese papel (resolver de transferencias o el de ajustes), no a una con ese nombre.
10. CloudKit: campo en los cuatro `yala*.ckdb`. Despliegue a Development en esta sesión; Production es decisión de Jürgen y paso del release.
11. `CategorySeed.swift` no se toca: la deducción y el relleno cubren la sembrada. `TransferCategoryResolver` e `InitialBalanceService` crean con papel.
