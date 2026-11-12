Sesión «Auditoría UX 2.2 · siguiente lote». Arranca sobre origin/2.2, sin esperar ningún CI.
Busca en el tablero la card paraguas de la auditoría UX de 2.2 (tablero listar --proyecto Yala --version 2.2) y su mapa de lotes. Toma el siguiente lote pendiente en el orden del mapa (si el lote 02 del formulario de registro no está hecho, ese) e impleméntalo. Lo que sea UI sin decidir queda como propuesta para Jürgen, no lo inventes. Simulador únicamente. Nunca «OpenAI» en textos. No toques Yala.xcscheme ni encargos/pendientes/ del checkout de Jürgen. Antes de abrir el PR a 2.2: git fetch y rebase sobre origin/2.2. Capturas antes y después para el digest.
Además: cuando el PR #588 ya esté mergeado en 2.2, despliega g22_01 y su Worker en staging y luego en producción (Jürgen ya autorizó los despliegues de 2.2); si no ha entrado, déjalo anotado en la card «Desplegar cambiar el rol de un miembro».
/cerrar-total

## Paso 0 (Frank, 2026-10-22)

**Qué lote es.** Las 20 cards de la auditoría (fase 2) están hechas. La cola que sigue es la de los lotes
*decididos*: hechos 01, 03-06, 09-11, 13-15. El primero pendiente es el **02 · formulario de registro**
(brief `~/Claude/tmp-frank/lote-decidido-2-2-02-formulario-registro.md`), que va en dos sesiones en serie.
Esta hace la **sesión A (flujo y datos, 11 cards)**; la B (textos y visual, 14 cards) va cuando A esté en 2.2.

**Medido antes de decidir.**
- uipg, mitad Panel: el subtítulo «Tienes X en N cuentas» del panorama **ya no se pinta** (`panoramaCollapsedSummary`
  no tiene consumidor; el hero dice «Tienes X en tus cuentas», sin número). Queda solo la mitad del formulario.
- La guía de arriba ya dice «Pon el monto, la cuenta y en qué fue» (es:3274), como dice L2-2.
- `FavoritePayment` se emite al Modo Nube (`EntityEmissionMap.favoritePayment`, tabla `favorite_payments`).

**Decisiones asumidas (técnicas o de lectura de la nota; ninguna cambia lo que Jürgen eligió).**
1. **L2-14, esquema:** relación nueva `FavoritePayment.destinationAccount` (a-uno, `.nullify`) con inversa
   `Account.destinationFavoritePayments`. Es un campo `STRING` en los cuatro `.ckdb` personales. La cuenta que se
   funde o se borra la arrastra como `account`. **No se emite al Modo Nube**: la columna nueva exige DDL en Supabase y
   el despliegue no es de esta sesión. Sin ella, un favorito llega a otro teléfono en la nube sin destino, que es
   justo el caso «favorito viejo» que la nota ya resuelve. Queda ticket + card.
2. **L2-5, «Editar» del aviso:** el aviso vive en su `UIWindow` (molde `DraftDiscardUndoNotice`) y el editor lo abre
   la pantalla que abrió el formulario, con un modificador por pantalla (`savedRecordEditing`). Nunca dos anclas
   sobre el mismo estado.
3. **L2-5, «Cambios guardados»:** aviso sin botones (la nota no pide deshacer una edición).
4. **L2-15, «Deshacer» del aviso «Guardado · se repetirá cada mes»:** deshace lo que se acaba de hacer: el registro
   de hoy y el pago planificado. Nombre del pago = la descripción; sin descripción, el nombre de la subcategoría.
   Aviso «el día» = `notifyOnDueDate` sin aviso previo (el texto de la hoja solo promete el día).
5. **L2-7:** los atajos y el cierre al tocar un día van solo en el formulario de registro (`DatePickerSheet` con un
   modo nuevo); los otros cuatro usos de la hoja no cambian.
6. **L2-2:** la línea sale siempre que «Guardar» esté apagado; los bordes, solo con monto. La lista de lo que falta
   la une el formateador de listas del idioma.
7. **L2-1:** la regla vive en una función pura (`TransactionAccountPrefillLogic`) que lee el filtro global de
   `SessionState` (es el del Panel, Registros y Estadísticas), así que vale desde cualquier pantalla que abra el
   formulario.
8. **Review adversarial** sobre el Deshacer (L2-5/L2-15) y la migración (L2-14), como pide el brief.

## Resultado (2026-10-22)

- **Sesión A del lote decidido 2.2 · 02 hecha**: L2-1, L2-2, L2-4, L2-5, L2-6, L2-7, L2-13, L2-14, L2-15, 4k2q y uipg (en uipg,
  la mitad del Panel ya no existía: medido). Detalle en el PR.
- **Gate**: build de las dos schemes, 11.232 unit, XCUITest de las 74 suites de las áreas tocadas (lotes A y B) más las
  del formulario. Único rojo: el intermitente previo `external-entry-panel-link-loses-the-typed-amount-intermittently`,
  reproducido también en la base `d72ff0263`.
- **Review adversarial** (Deshacer y migración): 8 hallazgos reales, arreglados en el mismo PR; dos quedan como ticket
  (editor de Ajustes con favoritos de transferencia; el aviso tapa el «+» del Panel, decisión de posición).
- **Despliegue de «cambiar el rol de un miembro»**: g22_01 y Worker en staging y producción. Falta la prueba con dos
  iPhone (ticket en `qa`).
- **Pendiente de Jürgen**: desplegar `CD_destinationAccount` a CloudKit Production (`docs/despliegue-cloudkit-2-2.md`);
  decidir la posición del aviso tras guardar; la sesión B del lote 02 cuando esto esté en 2.2.
