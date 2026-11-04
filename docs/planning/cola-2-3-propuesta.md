# Cola de la 2.3: propuesta para conversar

> Borrador del 2026-11-04, para revisarlo con Jürgen. **No mueve ni cierra ninguna card**: donde dice «cerrar»,
> «fusionar» o «mover», es una propuesta. Se armó con el tablero del 4-nov (las cards con `--version 2.3` y las que no
> tienen versión), contrastado con el código de `origin/2.3` y `origin/2.2` y con `docs/ROADMAP.md`, sección «2.3 — Yala
> apunta sola». Las cards se nombran por su título en el tablero.

## En corto

- La 2.3 tiene **130 cards abiertas**. De las 41 sin versión, **19 encajan** en ella. En total son unas 149.
- **9 están resueltas**, o lo estarán cuando pasen el QA. **6 son duplicados.** Otras **4 hay que reescribirlas**,
  porque su premisa ya no es cierta. Quedan unas 134 tareas reales.
- La propuesta las reparte en **10 sesiones de funciones grandes** y **25 lotes chicos**, en **9 olas**. Cada ola corre
  como máximo tres sesiones a la vez: una con simulador en la Mini, otra con simulador en la Max y una tercera sin
  simulador.
- El orden sigue al roadmap. Primero va lo que destraba: el control del coste de la IA, que tiene que estar antes del
  correo; los pasos de consola de Jürgen, y la prueba del atajo en su iPhone. Después vienen el correo del banco, que es
  la prioridad n.º 1 de paridad, y los gastos hormiga, que la ficha ya promete. Las cards de nube de prioridad media se
  reparten entre todas las olas, porque la 2.3 tiene que cerrarlas todas.
- El roadmap pide **4 cards que no están en el tablero**: el widget para apuntar con un toque, la política de privacidad
  del correo, el consejo con IA sobre los gastos hormiga y el lanzamiento de Lola.

---

## 1. Lo resuelto y lo duplicado (propuesto, sin tocar el tablero)

### Ya resuelto: se propone cerrarlo

| Card | Dónde quedó resuelto | Qué falta |
|---|---|---|
| En una sesión solo de grupos, «Dónde viven tus datos» dice que tus datos viven en tu iCloud privado | En 2.2. Su ticket ya está en `tickets/done/` | Cerrar la card |
| «Tengo una invitación» pide reabrir Yala para encender una copia en iCloud que ese camino no usa | En 2.2: desde el 20-oct, ese camino ya no pide reabrir la app (`WelcomeMirrorRelaunchLogic.swift`) | Cerrar la card y mover el ticket a `done` |
| Una compra de Apple Pay en una sesión solo grupos se convierte en un borrador personal que esa sesión no enseña | En 2.2, con el [PR que bloquea el atajo de Apple Pay en la vista de solo grupos](https://github.com/jur211296/Yala/pull/652) | Cerrar la card y mover el ticket a `done` |
| La ayuda dice que mantener pulsado un registro abre la edición masiva, y lo que abre es su menú | En 2.2. El ticket está en `done` y la ayuda ya manda a «··· › Seleccionar» | Cerrar la card |
| El sello del gate cambia al mover un renombrado dentro o fuera del índice, y no ve el fichero borrado del renombrado | En 2.2. El ticket está en `done` | Cerrar la card |
| El XCUITest del carrusel del flujo de caja por tarjeta falla a veces al deslizar *(sin versión)* | En 2.2, el 1-nov: pasó 5 de 5 veces | Cerrar la card y mover el ticket a `done` |
| «Cuánto puedo gastar hoy»: cupo diario vivo desde el presupuesto restante | En 2.3, con el [PR de «Hoy puedes gastar»](https://github.com/jur211296/Yala/pull/769) | Está en QA. Jürgen elige la variante A, B o C |
| Yala IA: detectar medio de pago (Yape, Plin, efectivo, tarjeta) en el chat | En 2.3, con el [PR del medio de pago en el chat](https://github.com/jur211296/Yala/pull/770) | Está en QA. Falta desplegar el gateway a producción |
| Recordatorio de pago de tarjeta antes del vencimiento + Registrar pago (mínimo/total) *(sin versión)* | El recordatorio ya salió en 2.2, con «Avisar antes de pagar» | Reescribir la card solo con «Registrar pago». Le toca la 2.4 |

### Duplicados: se propone fusionarlos

| Card que sobra | Se queda dentro de | Por qué |
|---|---|---|
| Ocultar montos con un botón *(sin versión)* | Ojo para ocultar montos en el Panel | Es la misma función, y la otra ya está en 2.3 |
| Al cambiar de idioma, una transferencia nueva crea otra subcategoría de transferencia | Transferencias y ajustes se reconocen por su nombre, no por su papel | Las dos vienen de buscar la subcategoría por su nombre traducido. Si se reconoce por su papel, se arreglan las dos |
| Dividir pago grupal escaneando un recibo | Grupos: repartir un recibo con IA — foto o voz, «quién comió qué» y elegir a quién se cobra cada cosa (Pro) | Es el mismo flujo. La idea del 23-oct le suma tres cosas, y las tres las decide Jürgen (ver §4): usarlo desde el registro personal, poner nombres libres y compartir un resumen |
| Leer avisos del banco en iOS 27 y voucher de Yape/Plin *(sin versión)* | Atajo del banco: registrar desde la notificación del banco o el correo de Mail, leído en el iPhone (Atajos + App Intent) | Leer los avisos del banco es justo lo que hace el atajo. La lectura del voucher de Yape y Plin ya existe |
| Logros y rachas con la mascota *(sin versión)* | Idea: rachas de registros (umbral, recordatorios, y la mascota si se decide) | Es la misma idea. Las dos son de 2.5 y dependen de lo que se decida sobre la mascota |
| Plugin de Yala para Claude: que Claude lea tus finanzas de la nube, sin poder tocarlas | La sesión de conectores de IA (S4) | La parte de solo lectura ya funciona en staging. Lo que falta ya tiene sus cards: producción, entrar con Apple o Google, y publicar el plugin |

Hay dos pares que **no son duplicados**, pero conviene trabajar juntos:

- «Pedir la verificación de Google para leer Gmail (alertas del banco)» y «Conectar Gmail mínimo para pedir la
  verificación de Google (yala-502622)» buscan lo mismo. La segunda prepara el material y la primera lo envía. Cuando
  la solicitud salga, se cierran las dos.
- «Con iCloud Drive apagado, cerrar sesión con grupos puede guardar en plena importación de iCloud y cerrar la app» y
  «Las esperas del arranque siguen leyendo el token de iCloud Drive» tienen la misma causa: el código mira el token de
  iCloud Drive cuando debería mirar si hay cuenta de iCloud. Las dos se arreglan con un solo cambio.

### Hay que reescribirlas antes de lanzarlas

| Card | Qué ya no es cierto |
|---|---|
| Ninguna llamada de IA pone tope a la longitud de la respuesta… | Nueve rutas del gateway ya tienen tope. Quedan tres o cuatro sin tope explícito, y falta revisar Gemini |
| Telemetría propia en Cloudflare y dashboard en lenguaje natural, para reemplazar TelemetryDeck | TelemetryDeck salió del código en julio, y Yala ya tiene una telemetría propia mínima. Solo falta el dashboard, y antes hay que decidir qué métricas lleva |
| «Dónde viven tus datos» dice «Todo al día» con la sincronización parada y tus movimientos sin subir | Con cambios sin subir, la pantalla ya no dice «Todo al día». Queda la causa de fondo: la nube se congela después de salir de «Volver a iCloud» |
| Mes desde el día del sueldo, visible y fácil de configurar *(sin versión)* | La nota supone que Yala ya tiene un día de cobro, y no lo tiene. Esta card es el «mes financiero» de la 2.4 |

### Resueltas a medias

- **El texto de «no pudimos desasociar» se decide dentro de la vista…:** falta una sola pantalla, la sección de
  asociación de grupos.
- **Los dos tests de edición masiva (`BulkEditUITests`) fallan en el iPhone SE:** hubo un arreglo, pero no se volvió a
  medir en el SE.
- **`test_recordSelectorsOpenAtMediumDetent` falla…:** el test ya pasa. Queda una pregunta de producto: la fila de chips
  no avisa que hay más a la derecha.
- **Tests · tres XCUITest intermitentes…:** el del enlace que pierde el importe parece arreglado. Los otros dos siguen.

---

## 2. Las sesiones de funciones grandes

Cada una es una sesión propia, que arranca con `/spec`. La columna **«Sim»** dice si necesita el simulador.

| Sesión | Cards que lleva | Sim | Decisiones de Jürgen antes de empezar |
|---|---|---|---|
| **S1 · Control del coste de la IA** (el roadmap lo pide antes del correo) | Ninguna llamada de IA pone tope a la longitud de la respuesta (reescrita) · No se guarda cuántos tokens gasta cada función de IA… · Los goldens del gateway hacen en serie las llamadas que el Worker lanza en paralelo… | No | Ninguna |
| **S2 · Correo del banco por reenvío** | Registrar movimientos desde correos de alertas del banco · *(falta)* la política de privacidad al día | Sí, para la guía y la Bandeja | El dominio de las direcciones · el cupo de prueba gratis (cuántos correos) · los bancos con los que empieza · publicar la política, que es un arreglo urgente de la web y sale de `1.0` · el gasto estimado de Cloudflare |
| **S3 · Atajo del banco** | Atajo del banco: registrar desde la notificación del banco o el correo de Mail… · Atajo de Apple Pay instalable en un toque con acciones Gasto/Ingreso/IA desde la notificación *(sin versión)* | Sí | **Primero, la prueba en su iPhone**: si la notificación le pasa su texto al atajo, si Mail le pasa el cuerpo del correo y si funciona con el iPhone bloqueado. El resultado decide el alcance. Además, si el atajo de Apple Pay entra en esta misma sesión |
| **S4 · Conectores de IA** | Endurecer el conector MCP en producción cuando la nube esté estable · Conectar Yala en Claude iniciando sesión con Apple o Google · Tu IA registra en Yala: Claude y ChatGPT (y Grok si se puede)… · Plugin de Yala para Claude (fusionada) · Pedir que Yala salga en los directorios de conectores de Claude y ChatGPT (al final) | No | Que confirme que la nube ya está estable · el despliegue a producción, que hace él · qué ve la persona en la app como «Claude conectado» |
| **S5 · Gastos hormiga y comercios** | Detectar gastos hormiga y decir cuánto suman al mes · Panel: ranking de comercios y reparto del gasto por cuenta o tarjeta · *(falta)* el consejo con IA sobre los gastos hormiga | Sí | La regla; por ejemplo, menos de S/ 5, tres o más veces al mes, en el mismo comercio o la misma subcategoría · dónde se ve: Insights, el Panel o el resumen · el diseño, a elegir entre 3 o 4 propuestas en lienzo |
| **S6 · Suscripciones detectadas** | Detectar pagos recurrentes y suscripciones en el historial y proponer convertirlos en pagos planificados · Logos de suscripción en pagos planificados (Netflix, Spotify…) | Sí | El catálogo de logos (marcas y licencias) · dónde se propone · si el logo necesita un campo nuevo; si lo necesita, va en la ventana de esquema (S9) |
| **S7 · Importar de Splitwise y Tricount** | Importar un grupo desde el export de Splitwise o Tricount para seguir con los mismos saldos | Sí | Si se importa solo a un grupo nuevo o también a uno que ya existe · cómo se emparejan las personas · un export real de cada app para la prueba. **La card dice prioridad baja**, pero el roadmap la pone como gancho del lanzamiento |
| **S8 · Repartir un recibo con IA** | Grupos: repartir un recibo con IA… · Dividir pago grupal escaneando un recibo (fusionada) | Sí | Si entran las tres ideas del 23-oct, que multiplican el alcance: usarlo desde el registro personal, poner nombres libres y compartir un resumen · el diseño, a elegir en lienzo |
| **S9 · La ventana de esquema de la 2.3** (cada menor tiene una sola) | Un pago planificado con fecha de inicio futura enseña fechas anteriores a ese inicio *(sin versión)* · Transferencias y ajustes se reconocen por su nombre, no por su papel (con su duplicado) · el campo del logo, si S6 lo pide | Sí | Qué entra en la ventana · qué papel tiene la subcategoría de transferencia que la app crea al empezar · el despliegue de CloudKit a producción, que hace él |
| **S10 · Yala web beta** | Yala web beta: ver tu Panel y apuntar borradores desde el navegador… · Con Apple solo puedes entrar en la nube con el Apple ID del teléfono (necesita el mismo inicio de sesión con Apple en la web) | No | **El Services ID de Apple y el cliente web de Google**, en las consolas (es una card suya) · dónde se publica y con qué dominio · el gasto estimado |
| **La mascota** (un documento para decidir, no una sesión de código) | Analizar una mascota en la app | No | Al final, si se hace o no. Las rachas de 2.5 dependen de eso |

---

## 3. Los lotes chicos

Cada lote junta de 3 a 5 tareas que tocan los mismos ficheros. La columna **«Rev»** marca los que piden review
adversarial porque tocan la sincronización, la migración, un cálculo financiero o Grupos.

### Nube (la 2.3 tiene que dejar en cero las de prioridad media)

| Lote | Cards | Ficheros en común | Sim | Rev | Decisiones o iPhone |
|---|---|---|---|---|---|
| **N1 · Bienvenida** | Volver atrás desde el acceso a la nube deja el Welcome como ya elegido… · Welcome solo grupos: volver desde la invitación olvida que venías de «Es mi primera vez» · Cerrar Yala en la bienvenida antes de elegir hace que el siguiente arranque baje tu iCloud privado · Los botones de las pantallas de la puerta de Grupos no tienen su identificador de accesibilidad en runtime · Con Ajustes abierto, un aviso importante (cambio de Apple ID, vaciado remoto) puede perderse hasta el siguiente arranque | `ContentView.swift`, `Onboarding/` | Sí | Sí | Ninguna (lo decidió el 26-oct) |
| **N2 · Activar la nube** | Cancelar la activación desde la bienvenida mientras comprueba tus datos te deja en la barra al 35 % sin salida · Modo nube · tres huecos sin card… · Cinco lecturas locales que fallan en silencio… · «Volver a iCloud» no aparece en el segundo dispositivo de quien creó su cuenta en la nube · Antes de conectar el journal, el candado del motor lee la fase de relleno | `MigrationRunner.swift`, `MigrationWorkExecutor.swift` | Sí | Sí | Dos dispositivos para el QA |
| **N3 · Restaurar y Almacenamiento** | Al reinstalar con conexión, Restaurar puede decir «No encontramos tus datos»… · Al reinstalar, Restaurar puede decir que tus datos están a salvo en una cuenta ya borrada… · Restaurar desde iCloud no deja rastro en el log cuando encuentra tus datos… · «Volver a iCloud» dice «Puede ser la conexión» cuando lo que venció fue el plazo de la revisión · «Dónde viven tus datos» dice «Todo al día»… (reescrita) | `WelcomeRestoreView.swift`, `StorageSettingsView.swift`, `SyncStatusSectionLogic.swift` | Sí | Sí | El texto para una cuenta ya borrada |
| **N4 · iCloud Drive y preferencias** | Las esperas del arranque siguen leyendo el token de iCloud Drive · Con iCloud Drive apagado, cerrar sesión con grupos… · Tras cerrar la sesión privada para prestar el móvil, la otra persona ve tu nombre y tu moneda · En una cuenta en la nube, el idioma de la app no llega a tus otros dispositivos… · Falta un test que pruebe que una sesión en la nube no encola el vaciado remoto del Apple ID | `AppBootstrapper.swift`, `PreferenceSyncService.swift` | Sí | Sí | Un iPhone con iCloud Drive apagado |
| **N5 · Cuenta y Pro** | Al entrar con tu cuenta, el Pro pagado puede no aparecer hasta volver a abrir la app · Pro guardado en el teléfono sobrevive a cambiar de Apple ID *(sin versión)* · Avisar unos días antes de que termine la prueba gratis de Yala Pro · Quien crea su cuenta con Google reusando la credencial no revoca el permiso de Google al borrar la cuenta *(sin versión)* · Al darse de alta en la nube, el consentimiento se registra antes de saber si podrás entrar… | `StoreKitManager.swift`, `AccountEntitlementService.swift`, `AccountDeletionService.swift` | Sí | Sí | El texto del aviso de la prueba · un iPhone con dos Apple ID y uno con Google |
| **N6 · Vaciar datos** | Tras «Vaciar datos», los gastos de grupo no vuelven a Registros y al Panel hasta que la app se cierra… · Si la señal de vaciado llega antes que la marca del parque… · Un iPad con versión anterior borra los recordatorios que «Vaciar datos» conserva | `DataWipeService.swift` | Sí | Sí | Si el caso del iPad se acepta como residual |
| **N7 · Grupos en la nube** | «Rechazar» una solicitud en un grupo de la nube puede expulsar a alguien que otro admin ya aprobó *(sin versión)* · «Desasociarla y seguir» suelta también la asociación que otro dispositivo sigue usando · Los comentarios del re-arranque del canal de Grupos prometen una protección que ya no existe · El texto de «no pudimos desasociar» se decide dentro de la vista… · Falta un seam de UI-test que siembre la asociación de grupos… | `GroupService.swift`, `GroupsAssociationSection.swift`, `GroupsSyncClient.swift` | Sí | Sí | Desplegar la función nueva de la base, en staging y en producción |
| **N8 · Divisas** | Cambiar la divisa de una cuenta en un teléfono puede dejar el otro con movimientos en la divisa vieja · Convertir importes de otra fecha hace un fetch de tasas por llamada · Una cuenta cuyo saldo suma cero sale como «€ -0.00» en Cuentas | `EntityApplyMap.swift`, `CurrencyConverter.swift`, `CurrencyUtils.swift` | Sí | Sí | Ninguna |
| **N9 · Diagnóstico** | Con la cola de métricas llena, un envío puede borrar canarios del Modo Nube que nunca salieron · El panel de depuración de la nube dice «red 0»… · «Activar la nube» con pocos datos tarda minutos: falta medir en qué paso | `MetricsSpool.swift`, `CloudSyncDebugView.swift` | Sí | No | Para la tercera: una build de TestFlight y la medida en su iPhone |
| **N10 · Decisiones y medidas de nube** (no es código: es una tanda de Jürgen) | Decidir qué hacer con lo que llega a iCloud después de la comprobación del adopt · Medir en un iPhone por qué fallan filas al volver a iCloud… · Si reinstalas Yala o cierras sesión a mitad de activar la nube… (elegir A, B o C) · Al activar la nube, algunas categorías y movimientos antiguos pueden salir duplicados… (¿se acepta el residual?) · Si la app se cierra mientras borra tus datos viejos de iCloud… · Mirar si Yala Dev dejó filas de prueba en el contenedor de producción… *(sin versión)* | — | — | — | Todas las decide él. Lo que decida pasa a código en N2 o en N6 |

### Producto, rendimiento y pulido

| Lote | Cards | Ficheros en común | Sim | Rev |
|---|---|---|---|---|
| **P1 · Pagos planificados** (antes de S6 y en la misma máquina, porque tocan los mismos ficheros) | Pagos planificados · «Adelantar gasto» ofrece el siguiente borrador, el iPad deja el detalle vacío y el 29 de febrero *(sin versión; son tres)* · Tests · el borrador de un pago vencido no se puede alcanzar en XCUITest *(sin versión)* | `Planning/`, `InboxBulkApproveSuccessView.swift`, `AppBootstrapper.swift` | Sí | No |
| **P2 · Rendimiento del Panel** | Volver al Panel lo recarga y recalcula entero (~0,7 s) · El primer contenido del Panel espera a que termine el arranque · La caché de los widgets bloquea el hilo principal (~0,27 s por reconstrucción) · Con dos necesidades filtradas desde Registros, el Panel enseña solo una… · Al volver a Yala, una pantalla podría quedarse sin actualizar sus números… | `PanelViewModel.swift`, `WidgetDataCache.swift` | Sí, y la medida en un iPhone en Release | No |
| **P3 · Estadísticas** | Entrar en Estadísticas tarda ~1 s, casi todo en pintar · Con «Todo el tiempo», el Sankey de Distribución se recalcula en cada repintado · Distribución recalcula dos veces cada vez que tocas el filtro… · Panel y Estadísticas · un filtro que se quedó puesto tras quitarlo y la guía que tapa las tarjetas *(sin versión)* | `CategoriesTabView.swift`, `StatisticsView.swift` | Sí | No |
| **P4 · Voz y Yala IA** | Perfil de prueba de voz two pone Taxi en Restaurantes · VoiceOver del dictado dice «el iPhone» también en el iPad · Bug · En una instalación nueva, el barrido del signo del chat sigue armado hasta el primer registro *(sin versión)* · Yala IA: guía con ejemplos de cómo pedirle las cosas | `VoiceRecordingView.swift`, `Chat/` | Sí | No |
| **P5 · Formularios y reportes** | En «Profundizar» de Reportes, el centro de la fila no añade la dimensión · Cambiar el tamaño del texto con Exportar abierto devuelve las cuentas a «todas» · «No se pudo guardar» aparece aunque los cambios de la cuenta ya se ven… · Un aviso de la cola que no llega a enseñar nada podría dejar esperando al siguiente | `Reports/`, `ExportWizard/`, `AccountFormViewModel.swift`, `AppRouter.swift` | Sí | No |
| **P6 · Extras de 2.3** (no son hitos del roadmap: se hacen si hay hueco) | Ojo para ocultar montos en el Panel · Nuevo registro · sugerencias de descripción a partir de gastos anteriores · Resumen visual del mes para compartir · Soporte por WhatsApp para quien escribe a Yala | `PanelView.swift`, `NewTransactionView.swift` | Sí | No |
| **P7 · Conector, cosas chicas** (va dentro de S4) | El conector de Claude da otro «saldo de hoy» que la app con un movimiento de fecha futura · Que el conector de Claude sepa en qué zona horaria vives… · Conector de Claude: avisar a quien usa iCloud privado… · Desconectar Claude desde Claude deja abierta una sesión huérfana en Supabase | `mcp/src/` | No | Sí |

Antes de P4 y P6, Jürgen decide cuatro cosas. Para P6: si el ojo oculta los montos solo en el Panel o en toda la app,
qué número de WhatsApp se usa y si las sugerencias también proponen categoría y cuenta. Para P4: el texto de la guía de
Yala IA, que se escribe con Lola.

### Tests, gate y CI (la deuda técnica de la versión)

| Lote | Cards | Ficheros | Sim |
|---|---|---|---|
| **T1 · Aislamiento de los unit tests** | Cada corrida de tests unitarios deja ficheros de preferencias huérfanos… (ya son 96 ficheros, y solo 35 limpian) · Una corrida de tests deja el onboarding marcado como visto… · Los unit tests dejan entradas en el espejo real del App Group… · El test que obliga al aislamiento del espejo de grupos no vigila wipeLocalGroupsDomain · Los tests borran el fichero SQLite con la conexión todavía abierta… | `YalaTests/` | Sí |
| **T2 · XCUITest en iPad** | El XCUITest de ⌘F para abrir Buscar… · En el iPad, el test de la barra lateral falla… · Los XCUITest de navegación buscan la barra de pestañas del iPhone… · Los XCUITest del registro por imagen no llegan al botón flotante en el iPad | `YalaUITests/` | Sí, de iPad |
| **T3 · XCUITest intermitentes en iPhone** | El test del aviso de divisa secundaria sale rojo en el iPhone SE… · El test del paywall retenido tras el aviso de la Bandeja falla solo en lote… · El XCUITest del aviso de pérdida al cambiar de Apple ID falla en iOS 27 · Los dos tests de edición masiva (`BulkEditUITests`) fallan en el iPhone SE · Tests · tres XCUITest intermitentes… *(sin versión)* | `YalaUITests/Flows/` | Sí |
| **T4 · Datos de prueba y relanzar** | Ningún perfil de seed de Grupos tiene un heredero… · No hay datos de prueba con una solicitud de grupo rechazada… · Relanzar un UI-test con la misma siembra y sin reset duplica todos los datos… · Relanzar sin -uitest-reset a veces enseña el Panel con todas las secciones · El botón «OK» del aviso de cierre de sesión bloqueado no tiene identificador… | `Yala/Seed/`, `UITestHooks.swift` | Sí |
| **T5 · Recetas del gate** | El gate local no corre el check de aislamiento de tests que el CI sí bloquea · El gate no ve los warnings de los ficheros de test… · El gate puede filtrar tests por el nombre del fichero… · /l10n-check corre 13 de los 17 tests de paridad y no puede notarlo | `.claude/commands/` | No |
| **T6 · CI** | Dos bancos de pruebas del gate y del CI no los ejecuta nadie… · El CI sigue usando `actions/checkout@v4`… · Un PR que solo toca encargos/ en markdown dispara la suite entera de iOS en CI · El candado anti-atribución no ve rebase, cherry-pick, revert ni los merges hechos en GitHub | `.github/workflows/` | No |
| **T7 · Proceso** | Recetas de traducción y el /qa usan el simulador compartido sin pedir turno… · El guion de la tanda de QA vuelve a dejar fuera, sin avisar, tickets que esperan prueba en el iPhone · Filtro de tickets con Haiku: duplicados y ya resueltos antes de lanzar · Podar el índice de memoria de Frank… *(sin versión)* | `qa/`, `tools/` | No |
| **T8 · Tests que copian la lógica, y el spike** | Los tests del cambio de divisa preferida copian la lógica en vez de ejecutarla · Los ejes 4a y 4b del spike del borrado del store salen rojos de vez en cuando en el gate… · `test_recordSelectorsOpenAtMediumDetent` falla… (falta la pregunta de producto de los chips) | `YalaTests/` | Sí |

Hay tres cards que **no son del repo de Yala**, y se proponen para una sesión de `casa`: «ADR-013 de casa no dice que
Yala tiene su propio hook commit-msg», «El --dry-run del avisador de Grok envía el aviso de verdad si va con --avisar»
y «El aviso de cierre de una sesión puede citar el PR de otra o ninguno, sin avisar».

Otra más es de la rama `1.0`, no de `2.3`: «Un despliegue del gateway desde la rama 1.0 bajaría el manifest del
Worker». Se arregla con un arreglo urgente sobre lo publicado, y conviene hacerlo antes del primer despliegue a
producción de S1 o de S4.

---

## 4. El orden propuesto

Cada ola tiene tres carriles: una sesión de Yala con simulador en cada máquina y una tercera sin simulador, que puede ir
en cualquiera de las dos. Nunca hay más de tres sesiones de Yala vivas, que es el tope de `lanzar-sesion`. **Las
sesiones de una misma fila no tocan los mismos ficheros**, y por eso pueden correr en paralelo.

| Ola | Mini (con simulador) | Max (con simulador) | Sin simulador | Lo que Jürgen tiene que haber hecho antes |
|---|---|---|---|---|
| **0** | — | — | — | Elegir la variante del cupo diario · desplegar el gateway del medio de pago · la prueba del atajo en su iPhone · el Services ID y el cliente web de Google en las consolas · enviar la verificación de Google · confirmar que la nube ya está estable |
| **1** | **N1** Bienvenida | **T1** Aislamiento de los unit tests | **S1** Coste de la IA, y el arreglo urgente del manifest en `1.0` | Nada: esta ola no espera decisiones |
| **2** | **S2** Correo del banco | **N2** Activar la nube | **S4** Conectores (endurecer, Apple y Google, P7) | Las decisiones del correo: dominio, cupo, bancos y política · que confirme que la nube está estable |
| **3** | **S5** Gastos hormiga y comercios | **N3** Restaurar | **S4** sigue con «Tu IA registra» | La regla y el diseño de los gastos hormiga |
| **4** | **S3** Atajo del banco | **N4** iCloud Drive y preferencias | **S10** Yala web beta | El resultado de la prueba del atajo · el Services ID (S10 reusa la vía de borradores que dejó S4) |
| **5** | **P1** Pagos planificados y, después, **S9** Ventana de esquema | **N5** Cuenta y Pro | **S10** sigue · **T5** Recetas del gate | Qué entra en la ventana de esquema · el papel de la subcategoría de transferencia · el texto del aviso de la prueba |
| **6** | **S6** Suscripciones detectadas | **N6** Vaciar datos y, después, **N8** Divisas | **La mascota** (documento) · **T6** CI | El catálogo de logos · la tanda N10 de nube, en su iPhone |
| **7** | **S7** Importar de Splitwise y Tricount | **P2** Rendimiento del Panel | **T7** Proceso | Los exports reales de Splitwise y Tricount · la medida en Release |
| **8** | **S8** Recibo con IA | **P3** Estadísticas y, después, **P4** Voz y Yala IA | Pedir los directorios de conectores (el final de S4) | El alcance del recibo y su diseño · que S7 ya esté mergeada, porque las dos tocan Grupos |
| **9** | **N7** Grupos en la nube | **T2** XCUITest en iPad y, después, **T3** y **T4** | **N9** Diagnóstico (lo que no pide simulador) | Si se hace la mascota o no |
| **Si hay hueco** | **P5** Formularios y reportes | **P6** Extras | **T8** | Las decisiones de P6 |

**Por qué este orden:**

- **S1 va primero y solo en el gateway.** El correo, el recibo y el consejo de los gastos hormiga llaman a la IA, y el
  roadmap pide el control del coste antes que ellos. Mientras S1 está viva, ninguna otra sesión toca `gateway/src/ai/`.
- **S2 y S5 van temprano**, porque son la paridad que se ve el primer día. Los gastos hormiga, además, ya los promete la
  ficha.
- **S3 espera a la prueba en el iPhone de Jürgen**, porque el resultado cambia su alcance. Si la prueba llega antes, se
  adelanta.
- **S4 va antes que S10.** La web escribe por la misma vía estrecha de borradores que los conectores. Si S10 la recibe
  hecha, no quedan dos sesiones tocando el mismo endpoint.
- **P1, S9 y S6 van en ese orden y en la misma máquina.** Los tres tocan los pagos planificados, y S9 junta en la única
  ventana de esquema todos los cambios de modelo de la versión.
- **S7 y S8 no van en paralelo, ni con N7**, porque los tres tocan Grupos.
- **Los lotes de nube van uno por ola, en la Max**, y nunca dos a la vez: N2, N3 y N6 comparten la migración y el
  vaciado.

**Sesiones que NO pueden ir juntas, aunque estén en máquinas distintas:**

- S1 con S2, S5 o S8: las cuatro tocan el gateway de IA.
- S5 con P2 o P6: las tres tocan el Panel.
- S6 con P1 o S9: las tres tocan los pagos planificados.
- S7 con S8 o N7: las tres tocan Grupos.
- N2 con N3 o N6: las tres tocan la migración y el vaciado.
- T5 con cualquier sesión que esté corriendo `/gate`, porque T5 cambia la receta del gate.

---

## 5. Lo que el roadmap pide y no está en el tablero

No se crearon. Se proponen como cards nuevas:

| Falta | Dónde lo pide el roadmap | Propuesta |
|---|---|---|
| **El widget interactivo para apuntar con un toque** | Eje 5: «Widgets: 2.3 (widget interactivo para apuntar con un toque; idea nueva)» | Una card de Frank. Si es chica, va en P6; si crece, es una sesión propia. Antes hay que aclarar si es un widget de la pantalla de inicio o uno del Panel |
| **La política de privacidad, al día para el correo** | 2.3: «Antes del correo, y no después» | Una card de Frank dentro de S2, con el arreglo urgente de la web desde `1.0`. Hoy es solo un paso suelto en la nota de la verificación de Google |
| **El consejo con IA sobre los gastos hormiga (Pro)** | 2.3, hito 5, y lo decidido el 21-oct | La card de los gastos hormiga solo pide el total y la lista. Hay dos caminos: sumarlo a su «hecha cuando» o crear una card propia para S5 |
| **El lanzamiento fuerte de la 2.3**: ficha, capturas y novedades | «Lanzamiento. Es el fuerte del roadmap», que ejecuta Lola | Una card para Lola, en `Yala/marketing`, que hoy no tiene ninguna de 2.3. No la toco: es su territorio |

Hay además una prueba que el roadmap pide «al empezar 2.3»: los disparadores del atajo en el iPhone de Jürgen. Hoy solo
aparece en el «siguiente paso» de la card del atajo. Conviene una card asignada a Jürgen, para que le salga en su lista.

---

## 6. Cards sin versión que no son de la 2.3

Se proponen para otra versión, sin moverlas:

| Card | Versión propuesta |
|---|---|
| Disponible para gastar descontando tarjeta y recurrentes | 2.4. El cupo diario no la cubre: aquel mira el presupuesto y ésta mira el saldo |
| Mes desde el día del sueldo, visible y fácil de configurar | 2.4: es el «mes financiero» |
| Tarjetas con la estética de cada banco peruano | 2.4, con las cuentas con presencia propia. Antes, Jürgen decide si se usan las marcas de los bancos |
| Mover registros a una cuenta en otra divisa cambia la divisa sin convertir el importe | 2.4. Si se trata como bug medio de la versión en curso, va a N8 |
| Las etiquetas y cuentas de colores eligen texto blanco o negro con una fórmula que no es la de WCAG · Accesibilidad · VoiceOver lee las gráficas en inglés… | 2.4, con el pase de accesibilidad |
| Dos rellenos rosa de marca llevan texto blanco por debajo de AA · En el tema Claro, el índigo como texto pequeño sobre el fondo da 4,46:1 | El endurecimiento antes de 3.0, o cuando se toque el área |
| Siri AI: integrar Yala con App Intents, Spotlight semántico y skills (cuando salga iOS 27.3) *(ya en 2.3)* | 2.5, «Yala conversa». Espera a iOS 27.3 y no aparece en el roadmap de 2.3 |
| El widget de pagos del Panel pone mayúscula en cada palabra del mes… · Textos · «1 seleccionadas», «Abrir Inbox»… · «Nuevo registro» con una sola cuenta no la trae elegida… · Nuevo registro: conservar el borrador si iOS cierra Yala · Retirar la hoja de ayuda huérfana de la Comparativa | 2.2, donde ya están en curso. Si no entran en la 2.2, pasan a P5 |
| Roadmap votable por usuarios | Sin versión. Se revisa con la web completa de 3.0 |
| HyperFrames… · Lote marketing de Lola… · Mezcla con voz de los reels IG semana 3 | Son de marketing, no de Frank |
| Limpiar los equipos de QA tras el QA guiado 2.1 | Una tarea física de Jürgen, fuera de cualquier versión |
| Opcional: publicar el issue redactado para supabase/auth… *(ya en 2.3)* | Un paso opcional de Jürgen, sin sesión |

---

## 7. Las decisiones de Jürgen, en una lista

Van en el orden en que frenan la cola:

1. **Que la nube ya está estable**, para poner el conector en producción (S4, ola 2).
2. **El correo**: el dominio de las direcciones, el cupo de prueba, los bancos con los que empieza, la publicación de la
   política de privacidad y el gasto de Cloudflare (S2, ola 2).
3. **Los gastos hormiga**: la regla, dónde se ven y el diseño en lienzo (S5, ola 3).
4. **El atajo**: la prueba en su iPhone y si entra el atajo de Apple Pay (S3, ola 4).
5. **La web**: el Services ID, el dominio y el gasto (S10, ola 4).
6. **La ventana de esquema**: qué entra y qué papel tiene la subcategoría de transferencia (S9, ola 5).
7. **Las suscripciones**: el catálogo de logos (S6, ola 6).
8. **La tanda de nube N10**: qué hacer con lo que llega tarde al adopt, qué motivos de fallo cuentan, A, B o C para
   quien reinstala a mitad, y si se acepta el residual de duplicados (ola 6).
9. **Grupos**: los exports reales de Splitwise y Tricount (S7, ola 7), y el alcance y el diseño del recibo (S8, ola 8).
10. **La mascota**: si se hace o no (ola 9).
11. **Las de la ola 0**, que no frenan nada pero conviene sacar ya: la variante del cupo diario, el despliegue del medio
    de pago y el envío de la verificación de Google.

Hay además un aviso, que no es una decisión. El borrador del PR de «Conectar Gmail» apunta a `2.2`, y su propio título
dice que no se mergee ahí. Si sigue vivo para la 2.3, hay que cambiarle la base a `2.3`:
[«Conectar Gmail» mínimo en Yala Dev y el paquete de la verificación de Google](https://github.com/jur211296/Yala/pull/613).
