# Checklist de confiabilidad — primera parte de P4 (17-nov-2026)

El fichero es `qa/checklist-confiabilidad.yaml`, con 30 ítems. Cada uno trae cuatro cosas: lo que tiene que
aparecer en un diff para que importe, qué comprobar, qué pruebas correr y los incidentes que lo justifican. Viene
de la propuesta P4 de `docs/verificacion/README.md`, que Jürgen aprobó el 17-nov.

La segunda parte de P4 tendrá dos piezas, el script que elige los ítems de un PR y el revisor que los recibe con el
diff. Las dos se leen de `origin/2.3` y arrancan en modo observar. Esta parte deja el fichero, su banco y la medición.

- **Banco:** `bash qa/scripts/checklist-confiabilidad-test.sh`. Valida la forma con 29 casos de mentira. Exige además
  que todo lo nombrado exista hoy en el árbol: globs, símbolos, pruebas, líneas de regla y tickets.
- **Las reglas no se tocan.** El mapa de abajo dice qué entrada de prosa cubre cada ítem. La sesión de poda (P5)
  decide qué archivar.

## Cómo se dispara un ítem

- `rutas` son globs tipo fnmatch sobre las rutas del diff, y el `*` cruza carpetas. Acotan **dónde**.
- `simbolos` (palabra entera) y `patrones` (regex de Python) acotan **qué**. Se buscan en las líneas añadidas o quitadas
  de los ficheros que pasaron el filtro de rutas.
- El ítem salta si alguna ruta casa, o no tiene rutas, **y** algún símbolo o patrón casa, o no tiene ninguno.

## Criterio de entrada

1. El disparador se ve en un diff.
2. Hay **al menos dos incidentes o PRs distintos**. Dos PRs cuentan como dos si arreglan el patrón en **sitios distintos
   del código**, aunque uno lo encontrara el barrido del otro. No cuentan tres casos:
   - el mismo fallo parcheado y luego arreglado de raíz;
   - el PR que introdujo la función;
   - un origen cuyo diff no trata el patrón del título.
3. Es lógica cara: nube, migraciones, dinero, fechas, formulario de registro, puente de Grupos, o pruebas que un PR
   rompe sin que su gate las corra.
4. No lo vigila ya una prueba automática. Lo que una prueba vigila no necesita revisor.

El revisor adversarial leyó la regla 2 más estricta: el barrido de otro PR no contaba como origen. Con su lectura, la
lista habría bajado a unos 22 ítems. La regla adoptada sigue el texto del encargo, «dos incidentes o PRs». El motivo es
que un patrón arreglado en dos sitios ya demostró que se repite. Afecta a cinco ítems, que tienen orígenes de una misma
tanda de barrido: `importe-convertido-cero`, `syncid-cambiado-escribe-testigo`, `borrados-que-conservan-grupos`,
`dos-rutas-de-tasa-coinciden` y `token-nil-no-es-sesion-caducada`. Si se aplica la lectura estricta, son los primeros
que salen.

## Qué se midió

Todo se midió sobre `origin/2.3` en `9f0e7d8e1`. Los scripts de medición no van en el PR. Su lógica de disparo es la
del contrato de arriba y la usará el selector.

| Medida | Resultado |
|---|---|
| Ítems cuyo disparador se enciende en el diff de al menos uno de sus orígenes | **30 de 30** |
| Orígenes en los que se enciende (diff del PR o commit de arreglo) | 82 de 87 |
| PRs mergeados a 2.3 desde el 3-nov que no reciben ningún ítem | 113 de 215 |
| PRs que reciben de 1 a 3 ítems | 90 |
| PRs que reciben de 4 a 10 ítems | 12 |
| Máximo de ítems en un PR | 6 |
| El PR de categorías a un toque, que rompió 4 pruebas de interfaz el 16-nov | recibe `nuevo-registro-cambia-de-alto`, que manda correr `SplitCalculatorUITests` y `AccountCardPickersUITests`, las dos clases que rompió |
| Los dos que no saltaron en esas dos semanas | `salir-de-fase-repone-pendientes` y `syncid-cambiado-escribe-testigo` |

Lo **inferido**, sin medir:

- La medición enciende el ítem con el diff del **arreglo**, porque el PR que metió el bug casi nunca se sabe.
- Algunos disparadores casan con la forma del error, no solo con el ayudante que trajo el arreglo:
  `periodo-que-cierra-en-medianoche`, `signout-se-verifica`, `hlc-sendlocal-y-orden-de-subida`,
  `drain-y-apply-sin-tablas-enteras`, `guard-de-migracion-no-falla-abierto` y `borrador-sobrevive-a-la-hoja`. Esos
  saltarían también ante un PR que repitiera el error.
- Los que dependen de símbolos del arreglo no saltarían si el error vuelve sin nombrar al ayudante. Ese hueco lo cubren
  sus rutas.

### Por ítem: disparos en sus orígenes y PRs de las dos semanas en los que salta

| Ítem | Área | Orígenes en los que salta | PRs en los que salta (de 215) |
|---|---|---|---|
| `lectura-fallida-no-es-vacio` | nube | 3/5 | 15 |
| `cierre-sin-perder-lo-pendiente` | nube | 4/4 | 5 |
| `hlc-sendlocal-y-orden-de-subida` | nube | 2/2 | 1 |
| `columna-de-sync-declara-since` | nube | 2/2 | 1 |
| `campo-de-modelo-es-campo-de-cloudkit` | nube | 2/2 | 2 |
| `drain-y-apply-sin-tablas-enteras` | nube | 2/2 | 2 |
| `token-nil-no-es-sesion-caducada` | nube | 3/3 | 1 |
| `signout-se-verifica` | nube | 2/2 | 1 |
| `frontera-de-persona-no-hereda` | nube | 5/5 | 1 |
| `borrados-que-conservan-grupos` | dinero | 3/3 | 1 |
| `puente-materializa-lo-que-llega` | dinero | 3/3 | 7 |
| `gasto-de-grupo-cuenta-mi-parte-una-vez` | dinero | 2/3 | 8 |
| `guard-de-migracion-no-falla-abierto` | migracion | 3/3 | 3 |
| `esperas-de-migracion-con-techo` | migracion | 4/4 | 3 |
| `salir-de-fase-repone-pendientes` | migracion | 2/2 | 0 |
| `syncid-cambiado-escribe-testigo` | migracion | 3/3 | 0 |
| `dos-rutas-de-tasa-coinciden` | dinero | 3/3 | 3 |
| `importe-convertido-cero` | dinero | 4/4 | 1 |
| `saldo-en-el-tiempo-por-divisa` | dinero | 2/2 | 8 |
| `widget-cuenta-con-las-funciones-de-la-app` | dinero | 3/3 | 14 |
| `ingreso-o-gasto-en-un-sitio` | dinero | 4/4 | 10 |
| `marca-aproximado-sobre-lo-mostrado` | dinero | 3/3 | 20 |
| `periodo-que-cierra-en-medianoche` | fechas | 4/4 | 9 |
| `saldo-filas-que-entran` | fechas | 2/2 | 3 |
| `nuevo-registro-cambia-de-alto` | formulario | 2/2 | 10 |
| `borrador-sobrevive-a-la-hoja` | formulario | 2/2 | 3 |
| `tocar-tras-escribir-en-xcuitest` | pruebas | 2/3 | 32 |
| `aviso-deshacer-no-cabe-en-5s` | pruebas | 2/2 | 15 |
| `ahora-fijo-en-pruebas` | pruebas | 2/3 | 23 |
| `defaults-aislados-en-pruebas` | pruebas | 2/2 | 12 |

Los más ruidosos son los de pruebas (`tocar-tras-escribir-en-xcuitest` 32, `ahora-fijo-en-pruebas` 23) y
`marca-aproximado-sobre-lo-mostrado` (20). Si en observar resultan ruido, son los primeros que hay que estrechar.

## Lo que cambió la refutación

Un revisor adversarial independiente, que no conocía las conclusiones, abrió en git los orígenes de los 40 candidatos
que salieron de las reglas. La lista quedó en 30.

- **Fuera por no tener dos incidentes de verdad:**
  - `predicate-con-tipo-concreto`: dos patrones distintos, y uno de ellos es un spike.
  - `identidad-regenerada-arrastra-referencias`: el segundo origen es un `feat`.
  - `subir-a-cuenta-poblada-prueba-linaje` y `adopt-con-espejo-adjunto`: una sola cascada, con orígenes que no tratan
    el patrón.
  - `selector-de-cuenta-y-tarjeta`: lo rompió otro PR fuera de sus rutas.
  - `nuevo-registro-con-texto-grande`: un origen solo tocaba pruebas.
  - `reabrir-fila-al-reparador`: ningún origen es una fila buena pisada.
  - `test-con-centro-de-avisos-propio`: un parche y su arreglo de raíz cuentan como uno.
  - `journal-nuevo-entra-en-undecodable`: su comprobación pasa a `guard-de-migracion-no-falla-abierto`.
- **Fuera porque ya lo vigila una prueba:** `model-configuration-sin-cloudkit`, que vigila
  `ModelConfigurationCloudKitWiringTests`.
- **Fuera porque el disparador no ve el error:** `fixture-que-discrimina`. No saltaba en ninguno de sus orígenes y
  salía en el 25 % de los PRs.
- **Fusionados:** `cierre-captura-antes-de-borrar` y `borrar-local-sin-perder-lo-pendiente` pasan a ser
  `cierre-sin-perder-lo-pendiente`. `sello-del-claim-cambia-de-persona` y `prefs-y-consent-en-fronteras-de-cuenta`
  pasan a ser `frontera-de-persona-no-hereda`, con cinco incidentes del 21-jul al 1-oct.
- **Nuevos:** el ítem de frontera de persona, `puente-materializa-lo-que-llega`, `gasto-de-grupo-cuenta-mi-parte-una-vez`
  y `widget-cuenta-con-las-funciones-de-la-app`. Los tres últimos salen del historial de arreglos (`git log --grep=^fix`
  sobre el puente y los widgets), no de una entrada de regla.
- **Corregidos:** se quitaron unos 15 orígenes que eran barrido, revisión o introducción, y no un incidente. También se
  estrecharon patrones que salían en cualquier PR del área y se arreglaron dos que nunca casaban: la forma de un `.ckdb`
  y la comparación de importes con cero.

## Mapa regla → ítem

Sirve a la sesión de poda. Una entrada de la tabla ya está cubierta por un ítem con disparador, y su prosa se puede
archivar o recortar. Lo que no aparece aquí sigue viviendo solo en la regla.

| Regla (fichero:líneas) | Entrada | Ítem |
|---|---|---|
| `.claude/rules/currency-fx.md:18-71` | La forma del bug que se repite en este módulo | `dos-rutas-de-tasa-coinciden` |
| `.claude/rules/currency-fx.md:72-95` | Lo mismo con un importe ya convertido (2026-10-11). | `importe-convertido-cero` |
| `.claude/rules/currency-fx.md:97-148` | Un SALDO en el tiempo vale lo que había en cada divisa, por la tasa de esa fecha (2026-10-16) | `saldo-en-el-tiempo-por-divisa` |
| `.claude/rules/currency-fx.md:117-133` | El saldo de HOY deja fuera lo fechado después de hoy (2026-10-18) | `saldo-filas-que-entran` |
| `.claude/rules/currency-fx.md:190-248` | La marca de aproximado en un total | `marca-aproximado-sobre-lo-mostrado` |
| `.claude/rules/ingreso-gasto.md:25-65` | Ingreso o gasto: `TransactionClassificationLogic.isIncome` | `ingreso-o-gasto-en-un-sitio` |
| `.claude/rules/ingreso-gasto.md:67-75` | Qué filas entran en un saldo: `LiveBalanceCalculator.entersBalance` | `saldo-filas-que-entran` |
| `.claude/rules/ingreso-gasto.md:77-81` | Lo gastado de un presupuesto: `BudgetsViewModel.calculateSpending` | `gasto-de-grupo-cuenta-mi-parte-una-vez` |
| `.claude/rules/session-filters.md:198-202` | El interruptor de Estadísticas (`includeGroupTransactionsInStats`) también lo recibe, desde el 2026-10-12 | `gasto-de-grupo-cuenta-mi-parte-una-vez` |
| `.claude/rules/swiftdata-cloudkit.md:177-177` | Schema del container de GRUPOS — campo nuevo = deploy a Production en el MISMO PR: | `campo-de-modelo-es-campo-de-cloudkit` |
| `.claude/rules/swiftdata-cloudkit.md:179-187` | Una columna nueva del canal personal del Modo Nube lleva `since` en el manifest, y sube `manifest_version` (20… | `columna-de-sync-declara-since` |
| `.claude/rules/swiftdata-cloudkit.md:221-323` | Un journal que no se deja leer NO es `notStarted`, y una lectura no escribe (2026-09-22). | `guard-de-migracion-no-falla-abierto` |
| `.claude/rules/swiftdata-cloudkit.md:325-383` | El push-all del cierre de sesión también pasa por el candado del motor, y «pendiente» incluye el History (2026… | `cierre-sin-perder-lo-pendiente` |
| `.claude/rules/swiftdata-cloudkit.md:385-420` | En el apply del pull, «no pude leer» NUNCA es «no hay nada» (2026-09-22). | `lectura-fallida-no-es-vacio` |
| `.claude/rules/swiftdata-cloudkit.md:475-523` | El de Grupos también devuelve si terminó (2026-09-26), y ahí la traducción cortada SÍ es `false` | `cierre-sin-perder-lo-pendiente` |
| `.claude/rules/swiftdata-cloudkit.md:524-583` | **Y el drain de Grupos estampa con `HLCClock.sendLocal(eventTime: tx.timestamp)`, no con `send` (2026-09-26, | `hlc-sendlocal-y-orden-de-subida` |
| `.claude/rules/swiftdata-cloudkit.md:593-648` | Y el Merkle tampoco, en ninguno de los dos canales (2026-09-22 personal · 2026-09-23 Grupos). | `lectura-fallida-no-es-vacio` |
| `.claude/rules/swiftdata-cloudkit.md:683-845` | La subida del snapshot de la IDA también tiene techo y salida, con dos relojes (2026-09-22). | `esperas-de-migracion-con-techo` |
| `.claude/rules/archivo/swiftdata-cloudkit.md:42-94` · `.claude/rules/swiftdata-cloudkit.md:1084-1161` | Y lo que el líder desplazado exporta TARDE a iCloud no le cambia la identidad al relevo (2026-09-24). | `syncid-cambiado-escribe-testigo` |
| `.claude/rules/archivo/swiftdata-cloudkit.md:79-87` | una lectura que falla es avería local, también la de los metadatos de CloudKit | `lectura-fallida-no-es-vacio` |
| `.claude/rules/swiftdata-cloudkit.md:1343-1380` | Y la sesión que abrió el adopt se cierra cuando el adopt sale (2026-09-23). | `signout-se-verifica` |
| `.claude/rules/swiftdata-cloudkit.md:1384-1384` | La espera de `reverseUpload` también lleva techo, y mide el tiempo SIN AVANZAR, no el total (2026-09-16). | `esperas-de-migracion-con-techo` |
| `.claude/rules/swiftdata-cloudkit.md:1386-1386` | El claim de la reversa tampoco puede quedarse sin salida: todo `.rejected` vuelve al origen (2026-09-16). | `salir-de-fase-repone-pendientes` |
| `.claude/rules/swiftdata-cloudkit.md:1411-1548` | Y las cuatro fases previas al montaje también tienen techo y salida, con efectos CERO (2026-09-21). | `esperas-de-migracion-con-techo` |
| `.claude/rules/swiftdata-cloudkit.md:1607-1620` | «Activar la nube» devuelve lo que tiró si sale antes del claim (2026-09-27). | `salir-de-fase-repone-pendientes` |
| `.claude/rules/archivo/swiftdata-cloudkit.md:100-100` | Las altas solo-grupos retiran en LOCAL las preferencias que dejó el arranque neutro, y las copias en memoria c… | `frontera-de-persona-no-hereda` |
| `.claude/rules/swiftdata-cloudkit.md:1693-1693` | `isCurrentUser` es un flag del canal CloudKit y en el BACKEND nace APAGADO para casi todo el mundo — toda reso… | `puente-materializa-lo-que-llega` |
| `.claude/rules/swiftdata-cloudkit.md:1705-1705` · `.claude/rules/archivo/swiftdata-cloudkit.md:106-106` | Un CONSENT no es una preferencia, y por eso el de Grupos SALIÓ del canal de prefs (C1, 2026-08-11). | `frontera-de-persona-no-hereda` |
| `.claude/rules/swiftdata-cloudkit.md:1711-1711` | El resolvedor canónico de identidad NO es un reemplazo mecánico del flag: contesta otra pregunta en DOS ejes (… | `puente-materializa-lo-que-llega` |
| `.claude/rules/swiftdata-cloudkit.md:1741-1741` · `.claude/rules/archivo/swiftdata-cloudkit.md:112-112` | Una salida que borra lo local con el espejo montado borra ARCHIVOS antes del mount, nunca FILAS, y solo despué… | `cierre-sin-perder-lo-pendiente` |
| `.claude/rules/archivo/swiftdata-cloudkit.md:118-124` | Un token que no llega NO es una sesión caducada: pregúntale al SDK si la conserva (2026-09-15). | `token-nil-no-es-sesion-caducada` |
| `.claude/rules/swiftdata-cloudkit.md:1776-1802` | Que `signOut()` volviera no dice que la sesión se fuera: pregúntale a su valor de retorno (2026-09-26). | `signout-se-verifica` |
| `.claude/rules/swiftdata-cloudkit.md:1804-1814` · `.claude/rules/archivo/swiftdata-cloudkit.md:130-130` | Tras un borrado de filas que conserva los grupos (`.importedRows`), las patas de las liquidaciones vuelven por… | `borrados-que-conservan-grupos` |
| `.claude/rules/swiftdata-cloudkit.md:1902-1923` | El sello del claim se olvida cuando el teléfono cambia de persona (2026-09-29). | `frontera-de-persona-no-hereda` |
| `.claude/rules/swiftdata-cloudkit.md:1943-1961` | El drain no carga tablas ENTERAS en cada vuelta: corre en el hilo principal (2026-10-31, YALA-IOS-2). | `drain-y-apply-sin-tablas-enteras` |
| `.claude/rules/swiftdata-cloudkit.md:2019-2036` | El apply de una página busca por LOTE, no fila a fila: corre en el hilo principal (2026-11-13, YALA-IOS-J). | `drain-y-apply-sin-tablas-enteras` |
| `.claude/rules/swiftdata-cloudkit.md:2019-2036` | El apply de una página busca por LOTE, no fila a fila: corre en el hilo principal (2026-11-13, YALA-IOS-J). | `lectura-fallida-no-es-vacio` |
| `.claude/rules/swiftui-ds.md:23-30` | El contenido de una hoja puede rehacerse SIN cerrarla, y su `@State` nace de cero (medido el 2026-11-04). | `borrador-sobrevive-a-la-hoja` |
| `.claude/rules/swiftui-ds.md:425-431` | Una pantalla que reparte su alto con `Spacer`s y no tiene scroll no cabe en un iPhone SE (medido 2026-09-28). | `nuevo-registro-cambia-de-alto` |
| `.claude/rules/testing.md:78-78` | Nunca `UserDefaults(suiteName:)` pelado (2026-11-04) | `defaults-aislados-en-pruebas` |
| `.claude/rules/testing.md:99-111` | NUNCA tocar singletons `.shared` sin `@Suite(.serialized)` + `defer { restore }` o `_testReset()`. | `defaults-aislados-en-pruebas` |
| `.claude/rules/testing.md:134-153` · `.claude/rules/archivo/testing.md:24-31` | NUNCA `Date()` / `Calendar.current` en lógica testeada — inyectar vía param opcional `now: Date = .now` (patró… | `ahora-fijo-en-pruebas` |
| `.claude/rules/testing.md:179-179` | Tocar algo justo después de `typeText` pierde el toque en iOS 27.0: el teclado sigue entrando y la pantalla se… | `tocar-tras-escribir-en-xcuitest` |
| `.claude/rules/archivo/testing.md:37-50` | **Un XCUITest no cabe en los 5 s del aviso con «Deshacer» si encadena dos gestos (medido el 2026-10-25, iOS 27… | `aviso-deshacer-no-cabe-en-5s` |
| `.claude/rules/testing.md:205-217` | Lo mismo bajo una `.safeAreaBar(edge: .bottom)` con el teclado abierto (medido el 2026-11-09, iOS 27.2). | `tocar-tras-escribir-en-xcuitest` |
| `.claude/rules/widgets.md:41-44` | Lo que el widget deduce de la foto vive en `WidgetInsightsLogic` | `widget-cuenta-con-las-funciones-de-la-app` |
| `.claude/rules/widgets.md:85-88` | Los grupos de la foto los calcula `WidgetGroupsSnapshotBuilder` con las funciones de la app | `widget-cuenta-con-las-funciones-de-la-app` |
| `CLAUDE.md:46-50` | Cálculos con fechas | `periodo-que-cierra-en-medianoche` |
| `tickets/done/2026-11-16-ui-tests-rojos-tandas.md:64-69` | Cómo evitar que se repita | `nuevo-registro-cambia-de-alto` |

`puente-materializa-lo-que-llega` no tiene una regla de prosa propia: su lección vive solo en los tres commits de
arreglo. Apunta a las dos entradas de identidad del canal («`isCurrentUser` es un flag…» y «El resolvedor canónico…»),
que cubren el caso de quien se une.

> **2026-11-17 (poda de P5):** los punteros de esta tabla y los `regla:` del YAML se recalcularon buscando el
> texto tras mover 12 entradas a `.claude/rules/archivo/`. Si una entrada cambia de sitio, se vuelven a calcular igual:
> `docs/verificacion/revision-de-escapes.md`, «La poda».

## Qué queda en observar y cuándo se promueve

- **Ahora:** el fichero y su banco. No hay nada que lo lea en el gate ni en el CI. Engancharlo al job
  `coverage-index` toca `.github/workflows/qa.yml`, que queda fuera de este encargo.
- **Segunda parte de P4:** el script selector y el revisor con rondas, leídos de `origin/2.3` y en modo observar. El
  selector rellena `ultimo_disparo`.
- **Propuesta para promoverlo a obligatorio** (la fija la segunda parte, con el visto bueno de Jürgen): que se cumplan dos condiciones en dos semanas de observar: el revisor no deja ningún
  hallazgo sin respuesta en más de 3 de 10 PRs, y ningún ítem salta en más del 20 % de los PRs sin producir hallazgos.
  Lo que salta y nunca encuentra nada se estrecha o sale.
- **A los 90 días** (P5) se revisa lo que no se haya disparado. Hoy hay dos candidatos: `salir-de-fase-repone-pendientes`
  y `syncid-cambiado-escribe-testigo`.
- **Un ítem nuevo** entra por el mismo criterio. P5 lo propone desde la revisión mensual de escapes, un revisor lo
  refuta y Jürgen lo aprueba en el PR.
