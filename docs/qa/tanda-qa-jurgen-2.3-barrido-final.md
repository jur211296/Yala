# Tanda de QA de Jürgen — 2.3, barrido final (15-nov-2026)

<!-- guion-check:inicio -->
> ⚠️ **Este guion NO cubre todo lo que espera prueba** (`tickets/qa/` y las cards «in qa» del tablero) · comprobado el 2026-11-15 con `qa/scripts/guion-tanda-check.py`. Hasta que `/barrido-qa` lo reparta, una tanda que siga solo el guion se deja lo de abajo.
>
> **Esperan prueba y el guion no los nombra (50 de 73):**
> (un ticket o card que el barrido decidió no traer al iPhone también se nombra, en la tabla «lo que se queda»)
> - `amounts-cut-or-split-at-the-largest-text-size`
> - `app-closed-by-ios-for-memory-yala-ios-b`
> - `app-uploads-its-timezone-to-the-cloud`
> - `attest-session-token-rejected-by-the-gateway-stays-cached`
> - `borncloud-consent-epoch-written-before-the-guard-decides`
> - `bottom-save-bar-overlaps-the-form-at-the-largest-text-size`
> - `budget-category-picker-offers-income-categories`
> - `bulk-move-to-another-currency-account-relabels-the-amount`
> - `claude-mcp-consent-with-apple-and-google`
> - `cloud-activation-time-is-unmeasured-between-the-claim-and-the-cutover`
> - `cloud-activation-uploads-thousands-of-items-for-a-few-records`
> - `cloud-activation-verify-loops-on-accounts`
> - `cloud-progress-shows-real-steps-and-counts`
> - `cloud-sign-in-cannot-choose-another-apple-id`
> - `daily-allowance-how-much-can-i-spend-today`
> - `entitlement-sync-forzado-es-noop-si-hay-otro-en-vuelo`
> - `external-entry-panel-link-loses-the-typed-amount-intermittently`
> - `flujo-de-caja-nutre-el-proyectado`
> - `flujo-proyectado-en-tendencias-y-panel`
> - `group-expense-from-a-receipt-with-ai`
> - `groups-intro-sheet-comes-back-after-closing-it`
> - `icloud-restore-preview-counts-categories-twice`
> - `insights-ant-expenses-ai-version-for-pro`
> - `insights-small-recurring-spending-card`
> - `invite-join-button-covers-paste-with-a-long-link`
> - `month-year-titles-capitalize-every-word`
> - `multi-currency-accounts`
> - `multi-currency-accounts-2-card-view`
> - `new-record-suggests-previous-descriptions`
> - `onboarding-2-3-bank-email-step`
> - `onboarding-2-3-getting-started-complete-and-pro-trial`
> - `onboarding-2-3-groups-entry`
> - `onboarding-2-3-learn-to-record-courtesy-trial`
> - `onboarding-2-3-single-provider-access`
> - `onboarding-sigue-los-estilos-del-resto-de-la-app`
> - `own-telemetry-panel-by-sections`
> - `owner-preferences-return-via-ikv-after-private-sign-out`
> - `panel-eye-hides-amounts`
> - `panel-fresh-seed-reads-the-icloud-drive-token`
> - `restore-found-copy-says-icloud-for-groups-that-never-were`
> - `scheduled-payment-actions-name-the-month-they-apply-to`
> - `scheduled-payments-show-subscription-logos`
> - `sign-out-in-place-leaves-a-screen-with-nothing-to-tap`
> - `siri-free-users-on-device-model-awaits-decision`
> - `start-fresh-dialog-promises-what-the-gate-undoes`
> - `statistics-and-records-filter-onchange-may-fall-asleep-like-the-panel`
> - `tag-selector-from-the-panel-form-shows-no-rows-in-2-3`
> - `transfer-subcategory-is-looked-up-in-the-current-language`
> - `voice-live-transcript-label-says-iphone-on-ipad`
> - `welcome-adopt-cancel-then-close-mounts-the-icloud-mirror`
<!-- guion-check:fin -->

Resumen: 65 cards revisadas; 40 a done, 2 fallaron (a backlog), 5 bugs nuevos, 6 pruebas para el iPhone de Jürgen (22 min), 4 vistos buenos y 8 en espera. Informe: https://claude.ai/artifact/NcBeAxfFcFwg4i3aiuZf1a · Lista: `docs/qa/barrido-2-3-final/lista.md`.

## Pruebas, por montaje

### Entrar con Apple, en la app y en la web (4 min)

1. Yala Dev en el iPhone 14 › Ajustes › Cerrar sesión. En la bienvenida, «Entrar con Apple» (Face ID).
2. Debe decir «Ya tienes una cuenta» si tu Apple ID usa el correo de una cuenta con Yala. Si una pantalla dice que es la misma cuenta y otra que sería nueva, haz captura de las dos.
3. En esa hoja, abajo, «Otra cuenta de Apple»: entra con otro Apple ID. Debe abrir esa cuenta y seguir dentro al cerrar y abrir Yala.
4. Safari › yala-web-staging.misty-surf-6866.workers.dev › «Continuar con Apple»: el saldo total debe ser el del Panel de Yala Dev.

Cards: `188b`, `pboq`, `4yc7`, `ljz7`. Por qué no se cerró en el barrido: Apple pide tu Face ID y, para la segunda parte, otro Apple ID con su contraseña.

### Pro con la compra de Sandbox (8 min)

1. Con el TestFlight de 2.3 en el iPhone 14, entra con una cuenta Free y termina los 7 Primeros pasos.
2. En el final, toca la prueba de Pro y confírmala con el tester de Sandbox. Ajustes › Yala Pro debe decir Pro.
3. Ajustes › Cerrar sesión y vuelve a entrar con la misma cuenta: Yala Pro debe seguir en Pro sin cerrar la app.

Cards: `l1c5`, `4afh`. Por qué no se cerró en el barrido: La hoja de pago real solo sale en TestFlight y la confirma tu tester de Sandbox. Va con el primer TestFlight de 2.3.

### Voz y foto de verdad (3 min)

1. Con una instalación nueva y cuenta Free: Panel › Primeros pasos › «Aprender a registrar». Toca Voz y di «almuerzo dieciocho soles»; luego Foto de un recibo. Los dos dejan un borrador correcto.
2. Grupos › Depa Barranco › Voz: «pizza cuarenta entre todos, cerveza doce Jurgen». Luego Foto de un recibo de restaurante.
3. El reparto debe salir bien a la primera o con un ajuste, y guardarse como gasto del grupo.

Cards: `d1ab`, `fu74`. Por qué no se cerró en el barrido: Desde la Mac no se puede hablar al iPhone ni apuntar la cámara a un recibo. La parte escrita ya pasó.

### Un aviso real de tu banco (3 min)

1. En tu iPhone: Atajos › + › Automatización › Notificación › App: la de tu banco.
2. Añade «Registrar movimiento desde texto» de Yala › Texto › Notificación.
3. Haz un pago pequeño: debe aparecer en la Bandeja de Yala con su monto y comercio.

Cards: `phhl`. Por qué no se cerró en el barrido: El iPhone 14 no tiene la app del banco; la lectura del aviso ya se probó con uno simulado.

### El conector de Yala en tu Claude (3 min)

1. En Claude › Conectores, añade el conector de Yala de staging y entra con Google; repite con Apple.
2. Pregunta «¿cuánto gasté este mes?»: debe responder con tus datos de staging.

Cards: `r8hi`. Por qué no se cerró en el barrido: Es tu cuenta de Claude, y entrar pide tu Apple o tu Google.

### Entrar a la web con el QR del iPhone (1 min)

1. En el Mac abre yala-web-staging.misty-surf-6866.workers.dev y toca «Entrar con tu iPhone».
2. Escanea el QR con la cámara del iPhone 14 (Yala Dev con sesión en la nube) y confirma: la web debe entrar con tu cuenta.

Cards: `7yhc`. Por qué no se cerró en el barrido: La cámara del iPhone tiene que apuntar a la pantalla de otro aparato.

## Lo que pasó a done

| Card | Motivo y evidencia |
|---|---|
| `gphj` 2.3 · Con texto al máximo el Panel se sale de la pantalla por los dos lados (carrusel de cuentas) | Accesibilidad/tamaño de texto (criterio de Jürgen: se confía en el código). PanelQuickActionsLargeTextUITests y StatisticsHeroLikePanelUITests verdes en la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro); BugsUILote1Tests en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `4wqy` 2.3 · Hueco de más bajo los chips en Estadísticas › Registros (el buscador oculto ocupa sitio) | StatisticsHeroLikePanelUITests (en todas las pestañas) y RecordsListSearchUITests verdes en la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro): sin hueco bajo los chips y el buscador sigue asomando al tirar. — |
| `i9wh` Activar la nube sube 3333 elementos para 2 registros y 2 cuentas, y por eso tarda 8 minutos | Medido en el almacén del teléfono (devicectl + sqlite) en modo iCloud con 0 registros: 446 elementos (366 tipos de cambio, 62 subcategorías, 11 categorías, 7 avisos), y la vuelta a iCloud subió exactamente «446». Antes eran 3.333 por copias repetidas de los tipos de cambio; hoy hay una por día. Cientos, no miles. [H04-en-tu-icloud-terminado.jpg](evidencia/H04-en-tu-icloud-terminado.jpg) |
| `56ze` Exploración 2.3 · Mascota «Yalitto»: direcciones visuales, dónde vive en la app y prototipos animados | Jürgen decidió las 7 preguntas de la mascota el 14-nov, todas la opción A: se hace después de 2.3 (gota, encendida en siete sitios, nombre tras revisar marcas, SwiftUI nativo). La 7.ª (texto de presupuesto pasado) ya está hecha en 2.3. La exploración de 2.3 queda cerrada. — |
| `11hi` Bienvenida 2.3 · Acceso con Google o Apple: el servidor decide | Casos vistos en el teléfono con Google: «Ya tienes una cuenta» (correo arriba, tres cosas, «Cargar mis datos y entrar») y «Vamos a crear tu cuenta» (cuenta nueva, consentimiento de la nube en la misma hoja, nota de Apple y Google con el mismo correo). Bienvenida23AltaUITests (8) y WelcomeAccountExistsUITests verdes en la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro), incluidos Apple sin web y «Usar otra cuenta». Lo de Apple con Face ID va en la prueba de Apple de Jürgen. [G01-vamos-a-crear-tu-cuenta.jpg](evidencia/G01-vamos-a-crear-tu-cuenta.jpg) · [G02-hemos-creado-tu-cuenta.jpg](evidencia/G02-hemos-creado-tu-cuenta.jpg) · [A01-cuenta-lista-15s.jpg](evidencia/A01-cuenta-lista-15s.jpg) |
| `hmaf` Bienvenida 2.3 · Entrada por Grupos | Puerta de Grupos: «¿Cómo empiezas?» con los tres caminos; «Entra aquí» con cuenta existente aterriza en Grupos; «Crear mi primer grupo» deja Grupos en «Ponle nombre al grupo e invita». Bienvenida23AltaUITests.test_groupsDoor_hasNoICloud_andLeadsToThreePaths verde. Ver la card nueva del bug: una intención de Grupos vieja sobrevive a cerrar sesión y secuestra la entrada siguiente. [C01-como-empiezas.jpg](evidencia/C01-como-empiezas.jpg) · [C02-puerta-grupos-aterriza-en-grupos.jpg](evidencia/C02-puerta-grupos-aterriza-en-grupos.jpg) · [E06-test-solo-grupos-donde-guardamos.jpg](evidencia/E06-test-solo-grupos-donde-guardamos.jpg) |
| `yuyn` Bienvenida 2.3 · Paso 5: Grupos con el estilo del tutorial | El paso 5 lo recorre entero Bienvenida23PlanificacionUITests (consentimiento, «Ahora no», mazo a 6 de 7), verde en la nocturna completa del 14-nov; la lógica, Bienvenida23PasosPlanificacionTests. En el iPhone vi el estado final de Grupos «Tu primer grupo, en tres pasos» con los dos primeros tachados. [E06-test-solo-grupos-donde-guardamos.jpg](evidencia/E06-test-solo-grupos-donde-guardamos.jpg) |
| `l4m0` Cancelar la activación desde la bienvenida mientras comprueba tus datos te deja en la barra al 35 % sin salida | Entrar con Google › Cargar mis datos y entrar › Cancelar la activación: el aviso trae «Sí, cancelar» y «Seguir pasando a mi cuenta de Yala», sin nombrar «Ya tengo cuenta». «Sí, cancelar» → «Cancelando…» ~3 s → bienvenida. [D01-cancelar-activacion-dialogo.jpg](evidencia/D01-cancelar-activacion-dialogo.jpg) · [D02-cancelada-vuelve-a-bienvenida.jpg](evidencia/D02-cancelada-vuelve-a-bienvenida.jpg) · [D-cancelar-y-reabrir.mp4](evidencia/D-cancelar-y-reabrir.mp4) |
| `0f7h` Cancelar la entrada a la cuenta en la bienvenida y cerrar la app monta el iCloud privado y entra a la app | Tras «Sí, cancelar», cerrar Yala y abrirla: bienvenida, y no retoma «Conectando con tu cuenta» (8 s mirando). [D02-cancelada-vuelve-a-bienvenida.jpg](evidencia/D02-cancelada-vuelve-a-bienvenida.jpg) · [D-cancelar-y-reabrir.mp4](evidencia/D-cancelar-y-reabrir.mp4) |
| `p9q0` Cerrar sesión: una vista propia con spinner y sin pedir reabrir Yala salvo que haya iCloud de por medio | Cuenta en la nube › Ajustes › Cerrar sesión: «Cerrando sesión…» con spinner ~6 s y vuelve a la bienvenida sin pedir reabrir (3 de 3). Eliminar mi cuenta (test@, solo Grupos): «Eliminando tu cuenta…» → «Tu cuenta se ha eliminado» → Continuar → bienvenida. [B01-cerrar-sesion-vuelve-a-bienvenida.jpg](evidencia/B01-cerrar-sesion-vuelve-a-bienvenida.jpg) · [B02-cuenta-eliminada.jpg](evidencia/B02-cuenta-eliminada.jpg) |
| `ulks` Con Ajustes abierto, un aviso importante (cambio de Apple ID, vaciado remoto) puede perderse hasta el siguiente arranque | ShellNoticeOverSettingsUITests verde en la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro). Caso raro (cambio de Apple ID o vaciado remoto con Ajustes abierto). — |
| `jzti` Con iCloud Drive apagado, cerrar sesión con grupos puede guardar en plena importación de iCloud y cerrar la app | Caso de pocos usuarios (iCloud Drive apagado + grupos + cerrar sesión). CloudSignOutFlowLogicTests y BootWaitsICloudAccountWiringTests verdes en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `g8un` Conectar con la cuenta tarda 22–50 s sin progreso real (se queda en 0 % y salta a lista) | Instalación limpia › Entrar con Google (cuenta con datos) › Cargar mis datos y entrar: «¡Tu cuenta está lista!» en 13,5–15 s (tres veces) y la barra avanza de verdad (22 % → 28 % → 74 % → lista). Antes, 22–50 s en 0 %. [A01-cuenta-lista-15s.jpg](evidencia/A01-cuenta-lista-15s.jpg) · [A-entrar-cuenta-panel-vacio-10s.mp4](evidencia/A-entrar-cuenta-panel-vacio-10s.mp4) |
| `39ww` «Dónde viven tus datos» dice «Todo al día» con la sincronización parada y tus movimientos sin subir | Ya arreglada (ticket en done); SyncStatusSectionLogicTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). Solo se ve si la sincronización se para, y no se dio en el barrido. — |
| `p9wf` En una cuenta en la nube, el idioma de la app no llega a tus otros dispositivos y va al iCloud del teléfono | Necesitaría dos dispositivos y no rompe datos (es el idioma). LanguageOverrideCloudChannelTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `6dz5` En una sesión solo de grupos, «Dónde viven tus datos» dice que tus datos viven en tu iCloud privado | Sesión solo Grupos (test@): Ajustes ya no tiene la fila «Dónde viven tus datos»; en Tu cuenta de Yala dice «Tu cuenta solo guarda tus grupos; en este dispositivo no hay datos personales». XCUITest GroupsAssociationRowUITests en la corrida del barrido. [F01-solo-grupos-ajustes-sin-donde-viven.jpg](evidencia/F01-solo-grupos-ajustes-sin-donde-viven.jpg) · [F02-solo-grupos-donde-viven-correcto.jpg](evidencia/F02-solo-grupos-donde-viven-correcto.jpg) |
| `x5tm` Entrar por «Dividir con amigos» lleva al Panel personal en vez de a Grupos | Bienvenida › Dividir gastos con amigos › Entrar con Google › «¿Cómo empiezas?» › Entra aquí › Google › Cargar mis datos y entrar › Empezar: aterriza en Grupos y a los ~3 s salen sus dos grupos. Al reabrir, el Panel con datos (la cuenta tiene parte personal). [C01-como-empiezas.jpg](evidencia/C01-como-empiezas.jpg) · [C02-puerta-grupos-aterriza-en-grupos.jpg](evidencia/C02-puerta-grupos-aterriza-en-grupos.jpg) · [C-puerta-grupos-aterriza-en-grupos.mp4](evidencia/C-puerta-grupos-aterriza-en-grupos.mp4) |
| `eqw2` Flujo de caja: ¿una línea de un mes pasado dice «Te quedan»? (mismo patrón que el mes cerrado de Presupuestos) | BugsUILote1Tests verdes en los tests unitarios del barrido (254 tests en 32 suites, verdes) («Te sobró» en un mes pasado por debajo de lo planeado); la sesión del arreglo lo vio en el iPhone 14 en inglés. — |
| `zy1d` iCloud recién vaciado: Yala dice «Ya tienes datos en tu iCloud — 62 categorías» y «copia de antes de pasar a tu cuenta» | iCloud sin registros ni cuentas (solo categorías) › reinstalar › Entrar con iCloud privado: va directo a «Un último paso: reabre Yala», sin «Ya tienes datos»; al reabrir, las tres preguntas desde cero, sin nombre recordado y sin el aviso de copia antigua. «Revisando qué hay en tu iCloud» tardó ~31 s (ticket aparte, ya abierto). [J01-icloud-vacio-sin-ya-tienes-datos.jpg](evidencia/J01-icloud-vacio-sin-ya-tienes-datos.jpg) · [J02-icloud-vacio-tres-preguntas.jpg](evidencia/J02-icloud-vacio-tres-preguntas.jpg) · [K-icloud-vacio-y-recuperar.mp4](evidencia/K-icloud-vacio-y-recuperar.mp4) |
| `9a98` La app se cuelga del todo al aplicar cambios de la nube (sincronización) · YALA-IOS-J | Entré 4 veces en una cuenta en la nube con datos y grupos (jur211296) y toqué Panel, Registros y Grupos mientras bajaba: respondió siempre. ApplyPageBatchLookupTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). [A-entrar-cuenta-panel-vacio-10s.mp4](evidencia/A-entrar-cuenta-panel-vacio-10s.mp4) |
| `deur` ¿La fila de chips de «Nuevo registro» avisa de que hay un chip más a la derecha en un iPhone de 402 pt? | Jürgen eligió el 14-nov la opción A, «Dejarlo como está» (artifact de decisiones del barrido anterior). No hay nada que construir. — |
| `dtex` Las esperas del arranque siguen leyendo el token de iCloud Drive | Caso de pocos usuarios (iCloud Drive apagado). BootWaitsICloudAccountWiringTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `b72m` «Pega tu enlace de invitación»: con el teclado abierto, el aviso de enlace no válido queda debajo de «Unirme al grupo» | InviteRecoveryPasteVisibleUITests verde en la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro): con el teclado abierto el aviso de enlace no válido se lee entero encima de «Unirme al grupo». Es de tamaño/teclado, y la sesión del arreglo lo midió en el iPhone 14. — |
| `lhca` Que el conector de Claude sepa en qué zona horaria vives para que «este mes» cuadre con la app | Tests del conector (mcp/test/app.test.ts) cubren la zona horaria de la persona (Europe/Madrid) y una zona inválida; la app sube timeZoneIdentifier con sus preferencias. CI «mcp» en verde. Es caso de pocos usuarios (fuera de la hora de Lima). — |
| `ptuf` Quien recupera sus datos no pasa por las tres preguntas (nombre, moneda, qué llevar) | Tras recuperar desde iCloud, «Continuar» lleva directo al Panel (S/ 250, la cuenta Efectivo) sin ninguna de las tres preguntas y recordando el nombre. [K03-hola-de-nuevo-un-continuar-62.jpg](evidencia/K03-hola-de-nuevo-un-continuar-62.jpg) · [K-icloud-vacio-y-recuperar.mp4](evidencia/K-icloud-vacio-y-recuperar.mp4) |
| `iio7` Recuperar desde iCloud: el resumen dice 63 categorías y dos pantallas después 65 | iCloud con 1 cuenta y 1 registro › reinstalar › Entrar con iCloud privado: «Ya tienes datos» dice 62 categorías, «Trayendo tus datos» 62 y «¡Hola Barrido! Qué bien volver a verte» 62. El mismo número en las tres pantallas. [K01-ya-tienes-datos-62-categorias.jpg](evidencia/K01-ya-tienes-datos-62-categorias.jpg) · [K02-trayendo-62-categorias.jpg](evidencia/K02-trayendo-62-categorias.jpg) · [K03-hola-de-nuevo-un-continuar-62.jpg](evidencia/K03-hola-de-nuevo-un-continuar-62.jpg) · [K-icloud-vacio-y-recuperar.mp4](evidencia/K-icloud-vacio-y-recuperar.mp4) |
| `lwv1` Recuperar desde iCloud: un solo «Continuar», sin volver a preguntar «Traer mis datos» ni flecha atrás | Traer mis datos › reabrir › carga › «¡Hola Barrido! Qué bien volver a verte»: un solo botón «Continuar», sin volver a preguntar «Traer mis datos» y sin flecha atrás. [K03-hola-de-nuevo-un-continuar-62.jpg](evidencia/K03-hola-de-nuevo-un-continuar-62.jpg) · [K-icloud-vacio-y-recuperar.mp4](evidencia/K-icloud-vacio-y-recuperar.mp4) |
| `6a12` Restaurar no trae nada con iCloud Drive apagado | Caso de pocos usuarios (iCloud Drive apagado). RestoreICloudDriveOffUITests verde en la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro) y RestoreICloudDriveOffTests en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `f8pd` Revisión por vistas 2.3 · Índice de cobertura y resumen de decisiones pendientes | docs/ux/revision-vistas-2.3/README.md dice «Las 11 zonas están revisadas», con su estado, enlaces (los 11 existen) y las decisiones del 9-nov marcadas como «Decidido». — |
| `ca5b` Si la app se cierra mientras borra tus datos viejos de iCloud, pueden volver a aparecer | Cerrar la app en un instante preciso del borrado. CorpusWipeCrossingTheZoneMountTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). En el iPhone probé el caso vecino (cerrar durante «Borrar los datos de antes» de la vuelta a iCloud): no volvieron datos viejos; la vuelta se canceló sin aviso (hallazgo menor, en la lista). — |
| `r380` Si la señal de vaciado llega antes que la marca del parque, el receptor se lleva la semilla del origen | Carrera entre dos dispositivos, imposible de provocar a mano. RemoteWipeSignalDetectionTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `w90g` Si reinstalas Yala o cierras sesión a mitad de activar la nube, ese iPhone no puede volver a intentarlo | Reinstalar a mitad de activar la nube: caso raro. StorageMigrationIdentityBlockUITests verde en la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro) y StorageMigrationIdentityGateLogicTests en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `840a` «Tengo una invitación» pide reabrir Yala para encender una copia en iCloud que ese camino no usa | Arreglado en 2.1; InviteThreeDoorsTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). Es la puerta del invitado, cubierta también por la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro) (InviteRecoveryPasteVisibleUITests). — |
| `luc1` Textos de entrada y salida que no cuentan lo que acaba de pasar | Los cinco textos: (1) eliminar cuenta termina en «Tu cuenta se ha eliminado»; (2) cuenta nueva sin «Descargando tus datos…» (sale un esqueleto de carga); (3) «Hemos creado tu cuenta. Ahora, tres preguntas rápidas» antes de las preguntas; (4) nombre de Apple en mayúsculas → «Jurgen» (WelcomeConversationLogic.naturalCase, test SameEmailAndHonestCopyTests verde); (5) Vaciar datos: hoja de alcance + una confirmación, sin la línea de Pro. [B02-cuenta-eliminada.jpg](evidencia/B02-cuenta-eliminada.jpg) · [G02-hemos-creado-tu-cuenta.jpg](evidencia/G02-hemos-creado-tu-cuenta.jpg) |
| `spfw` Tras «Vaciar datos», los gastos de grupo no vuelven a Registros y al Panel hasta que la app se cierra y se abre de nuevo | WipeDataGroupRowsInSessionUITests verde en la corrida de XCUITest del barrido (43/43 verdes, simulador iPhone 17 Pro): tras «Vaciar datos» los gastos de grupo vuelven en la misma sesión. — |
| `z07r` Un iPad con versión anterior borra los recordatorios que «Vaciar datos» conserva | iPad con la versión vieja: pocos usuarios. KeepingWipeOldReceiverRemindersTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `qvaz` Una compra de Apple Pay en una sesión solo grupos se convierte en un borrador personal que esa sesión no enseña | Apple Pay en una sesión solo Grupos: pocos usuarios. PrivateExitInboundCaptureLogicTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes). — |
| `4lld` Una cuenta en la nube copia sus datos al iCloud privado del teléfono | Cuenta en la nube recién creada y vacía: «Volver a tu iCloud» dijo que el iCloud tenía 2.351 registros, 2 cuentas y 6 presupuestos, que son los datos de prueba viejos que ya estaban ahí (la cuenta tenía 0). Con la vuelta hecha, el iCloud solo tenía lo que subió la vuelta. Coincide con la medición del arreglo (14-nov): la cifra igual era por la semilla fija de los datos de prueba, sin exportar nada al espejo. [H02-tu-icloud-ya-tiene-datos.jpg](evidencia/H02-tu-icloud-ya-tiene-datos.jpg) |
| `7usr` «Volver a iCloud» no aparece en el segundo dispositivo de quien creó su cuenta en la nube | Segundo dispositivo de una cuenta nacida en la nube: caso raro; CloudIdentityDiscoveryTests verde en los tests unitarios del barrido (254 tests en 32 suites, verdes) (ticket ya en done). — |
| `atde` «Volver a tu iCloud» se queda en «Traer tus datos de tu cuenta de Yala» más de 6 minutos, también tras reabrir | Cuenta en la nube recién creada › Dónde viven tus datos › Volver a tu iCloud › Empezar sin ellos › Borrar y volver: «Borrar los datos de antes» con contador (2.800 borrados), «Traer tus datos» al momento, pide reabrir; al reabrir «iCloud revisa lo que ya tiene» y «Subir a iCloud · 446 por subir» con «Cancelar y seguir en tu cuenta de Yala» activo. Terminó en «En tu iCloud» en ~3,5 min, casi todo borrando ~2.900 elementos viejos del iCloud. Ya no se queda en «Traer tus datos». [H01-donde-viven-cuenta-nueva.jpg](evidencia/H01-donde-viven-cuenta-nueva.jpg) · [H02-tu-icloud-ya-tiene-datos.jpg](evidencia/H02-tu-icloud-ya-tiene-datos.jpg) · [H03-vuelta-icloud-ya-casi-esta.jpg](evidencia/H03-vuelta-icloud-ya-casi-esta.jpg) · [H04-en-tu-icloud-terminado.jpg](evidencia/H04-en-tu-icloud-terminado.jpg) · [H-volver-a-icloud.mp4](evidencia/H-volver-a-icloud.mp4) |

## Lo que se queda

| Card | Qué lo retiene |
|---|---|
| `3w7z` Registrar movimientos desde correos de alertas del banco | En espera: Lo activan Jürgen o Dan (dominio, buzón y despliegue); después se prueba con un reenvío real. |
| `phhl` Atajo del banco: registrar desde la notificación del banco o el correo de Mail, leído en el iPhone (Atajos + App Intent) | Prueba de Jürgen: Solo un aviso real de tu banco dice si funciona. |
| `vfg1` «Activar la nube» con pocos datos tarda minutos: falta medir en qué paso (canarios nuevos) | En espera: Necesita una cuenta de Apple o Google sin Yala que entre sin contraseña; en el iPhone 14 no queda ninguna. Se mide en la próxima activación real (TestFlight). |
| `4afh` Al entrar con tu cuenta, el Pro pagado puede no aparecer hasta volver a abrir la app | Prueba de Jürgen: Necesita una cuenta con Pro pagado (la compra de Sandbox de la prueba anterior). |
| `188b` Apple y Google con el mismo correo: una pantalla dice que es la misma cuenta y otra que sería una cuenta nueva | Prueba de Jürgen: La otra mitad es entrar con Apple (Face ID). |
| `i9d8` Bienvenida 2.3 · Correo automático | En espera: Depende de que se active el correo por reenvío. |
| `l1c5` Bienvenida 2.3 · Final: Primeros pasos completos y prueba de Pro | Prueba de Jürgen: La hoja de pago real solo sale en TestFlight con el tester de Sandbox (contraseña o Face ID tuyos). |
| `d1ab` Bienvenida 2.3 · Paso 2: voz, foto y Yala IA con prueba de cortesía | Prueba de Jürgen: Necesita tu voz y la cámara. |
| `pboq` Con Apple solo puedes entrar en la nube con el Apple ID del teléfono | Prueba de Jürgen: Card tuya: necesita Face ID y otro Apple ID con su contraseña. |
| `r8hi` Conectar Yala en Claude iniciando sesión con Apple o Google | Prueba de Jürgen: Es tu cuenta de Claude: conectar el conector de Yala de staging entrando con Apple y con Google. |
| `ea78` Detectar gastos hormiga y decir cuánto suman al mes | Visto bueno de Jürgen: ¿Te convence el texto y dónde sale la tarjeta? Capturas en el barrido del 14-nov. |
| `pv2l` Endurecer el conector MCP en producción cuando la nube esté estable | En espera: Lo despliega Dan; no es una prueba. |
| `fu74` Grupos: repartir un recibo con IA — foto o voz, «quién comió qué» y elegir a quién se cobra cada cosa (Pro) | Prueba de Jürgen: Voz y foto del recibo necesitan tu voz y la cámara. |
| `9nn7` Logos de suscripción en pagos planificados (Netflix, Spotify…) | Visto bueno de Jürgen: ¿Se ven bien los logos? Es un visto bueno de diseño. |
| `j93f` Los goldens del gateway hacen en serie las llamadas que el Worker lanza en paralelo: el fetch de Node 26 encola los POST | En espera: Necesitan USER_A/B/C_PASS y GROUPS_ENC_KEY de staging, que el barrido no tiene. |
| `vfsf` Mezcla con voz de los reels IG semana 3 | En espera: Fuera del territorio de Frank: lo escucha Jürgen con Lola. |
| `3z6j` No se guarda cuántos tokens gasta cada función de IA, así que no hay coste por pregunta, foto o nota de voz | En espera: Depende del despliegue de Dan; no es una prueba. |
| `y6du` Nuevo registro · sugerencias de descripción a partir de gastos anteriores | Visto bueno de Jürgen: ¿Son las sugerencias que esperabas y en ese orden? |
| `dyhx` Telemetría propia en Cloudflare y dashboard en lenguaje natural, para reemplazar TelemetryDeck | En espera: Decisión tuya, no prueba. |
| `c8i9` Tras «¡Tu cuenta está lista!» el Panel sale vacío (S/ 0, «Crea tu primera cuenta») hasta salir y volver | Falló: Entrar con Google › Cargar mis datos y entrar › «¡Tu cuenta está lista!» › Empezar. Esperado: el Panel con los datos. Pasó (2 de 2, también en la primera entrada tras instalar): el Panel sale ~10 s con «S/ 0 · Aún no tienes registros en este período» y «Crear categorías · aún no tienes ninguna»; Registros ya tenía 7 movimientos (−S/ 127). A los ~10 s, sin tocar nada, pasa a S/ 1353. Mismo patrón en Grupos: «Tu primer grupo, en tres pasos» ~3 s antes de cargar los grupos. Es justo lo que Jürgen pidió evitar el 13-nov («pongamos un spinner, pero no confundamos al usuario»). Una cuenta NUEVA sí muestra esqueleto de carga, aunque dura ~40 s. Repetido una 4.ª vez antes de probar la web: S/ 1353 llegó 18 s después de «Empezar». |
| `v466` Yala IA: detectar medio de pago (Yape, Plin, efectivo, tarjeta) en el chat | Visto bueno de Jürgen: ¿Te gusta que Yala IA pregunte antes de cada borrador? Es un texto/flujo que eliges tú. |
| `4yc7` Yala web beta: ver tu Panel y apuntar borradores desde el navegador (cuentas en la nube) | Prueba de Jürgen: Entrar con Apple pide Face ID: solo Jürgen. |
| `ljz7` Yala web: definir y maquetar la app web como un dispositivo más en modo nube | Prueba de Jürgen: Card de Jürgen; Apple pide Face ID. |
| `7yhc` Yala web, lote 2 según el plan aprobado | Prueba de Jürgen: El QR se escanea con la cámara del iPhone apuntando a la pantalla de un ordenador: es una prueba física. |
| `qf6g` Yala web, lote 3 según el plan aprobado | Falló: Arreglar antes de encender la escritura de Grupos de la web en producción (decisión del 14-nov). Producción aún no tiene la web. |
