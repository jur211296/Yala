# Revisión de la experiencia del usuario nuevo (noviembre 2026)

Revisión exploratoria del camino de una persona que instala Yala por primera vez: bienvenida, onboarding, guía
«Primeros pasos», primer Panel y cómo llega a crear una cuenta, un presupuesto y un pago planificado.

**No implementa nada y no elige nada.** Deja el mapa de fricciones, siete perfiles evaluados, alternativas por cada
parte del recorrido y combinaciones para que Jürgen decida. La mascota queda fuera (otra decisión).

| Documento | Qué tiene |
|---|---|
| Este fichero | Fuentes, recorrido medido, mapa de fricciones (§3), matriz de perfiles (§4), «primera utilidad» y abandono (§5), combinaciones (§6) y plan de validación (§7) |
| [`alternativas.md`](alternativas.md) | De 3 a 5 alternativas por parte del recorrido, el onboarding conversacional frente a las opciones deterministas y el revelado progresivo |
| [`capturas/`](capturas/) | 24 capturas del recorrido de hoy |

## 1. De dónde sale y cuánto fiarse

Cada afirmación lleva su tipo de fuente. **Lo medido y lo supuesto van separados en todo el documento.**

| Marca | Fuente | Cuánto pesa |
|---|---|---|
| **[Cap]** | Captura del recorrido del 2026-11-06, en `capturas/` | Medido. Yala Dev instalada desde cero en el simulador iPhone 17 Pro, iOS 27.2, sin cuenta de iCloud, en español, modo oscuro. La build se compiló a las 19:15 de ese día desde una rama de trabajo; no se compiló desde este árbol (la diferencia con `origin/2.3` en Panel y onboarding a esa hora es solo el flujo proyectado de Tendencias). El botón «Annotate» que se ve abajo es una herramienta de desarrollo y no lo ve nadie más. |
| **[Cód]** | Código de `origin/2.3` en `5b45b3260`, con fichero y línea | Medido en el código; no siempre comprobado en pantalla |
| **[Aud]** | Auditoría de UX 2.2 (20 lotes, octubre 2026) y sus cards | Decisión ya tomada o hallazgo ya registrado |
| **[Rep]** | Reporte verbal de Jürgen del 6-nov sobre usuarios reales | Señal real, sin cantidad ni texto literal. No hay registro escrito del feedback. Hay uno parcial anterior: el 13-oct, usuarios que se quedaban en el paso del saldo sin ver «Calculemos tu saldo juntos» |
| **[Hip]** | Hipótesis de esta revisión | Por validar (§7). Nunca se presenta como dato |

**No hubo entrevistas.** Los perfiles del §4 son evaluaciones heurísticas: alguien del equipo se pone en el lugar de
ese perfil y recorre la app. **No hay métricas de uso en este documento** porque todavía no existen para el alta
(ver §7.1).

### 1.1 Sobre qué se construye

La auditoría de UX 2.2 ya revisó esta zona en los lotes 1 (bienvenida y onboarding), 3 (Panel), 5 (primeros días,
guía y tips), 6 (datos previos y nube), 7 (cuentas), 9 (presupuestos) y 10 (pagos planificados). Mapa:
[`docs/ux/mapa-de-flujos-2.2.md`](../mapa-de-flujos-2.2.md). Lo que ya se decidió y **no** se vuelve a proponer aquí:

- Onboarding de 8 a **7 pasos**, con «¿Dónde está tu dinero?» fusionado (L1-9). El saldo se queda en su paso y
  **es obligatorio**: Jürgen descartó hacerlo opcional (L1-7, opción C).
- La pantalla «Reabre Yala» se queda, con una línea que explica por qué (L1-4).
- La oferta de prueba Pro sale tras el primer registro o al completar Primeros pasos, no al terminar el onboarding
  (L1-12).
- Primeros pasos sin candados, con el primer gasto primero, un paso grande con «Empezar», el paso saltado en gris y la
  guía de Ajustes en 3 pasos (L5-1, L5-2, L5-4, L5-9).
- Avisos del Panel de uno en uno, «Aviso 1 de N» (L3-8). Balance del mes con «Entró − salió» (L3-1). «Crea tu primera
  cuenta» cuando no hay ninguna (L3-10).
- Presupuesto con «¿Qué gastos cuenta?» y «Todos mis gastos» preseleccionado (L9-2, opción B; se descartaron C y D).
- Pago planificado con su línea resumen y aviso tras guardar (L10-4, L10-5).

Cuando una alternativa de esta revisión **reabre** una de esas decisiones, lo dice en su fila y explica qué cambió.

## 2. El recorrido, medido hoy

Camino privado, persona nueva, iPhone sin iCloud. **11 pantallas y una salida obligada de la app** antes del Panel
[Cap]:

| # | Pantalla | Qué pide | Captura |
|---|---|---|---|
| 1 | Presentación | «Empezar» (carrusel de 8 tarjetas) | `01-arranque` |
| 2 | Selector | «Es mi primera vez» / «Ya tengo una cuenta» / «Dividir gastos con amigos» | `02-selector` |
| 3 | Comprobación de iCloud | Sin iCloud: «Seguir así» | `03-primera-vez` |
| 4 | «Un último paso: reabre Yala» | Salir a la pantalla de inicio y volver a abrir | `04-reabre-yala` |
| 5 | Paso 1 de 7 | Nombre (obligatorio) | `05-onb-paso1-nombre` |
| 6 | Paso 2 de 7 | «Llevar el control» o «Solo anotar mis gastos» | `06-onb-paso2` |
| 7 | Paso 3 de 7 | «¿Dónde está tu dinero?», sin opción preelegida | `07-onb-paso3-cuentas` |
| 8 | Paso 4 de 7 | Nombre y moneda de la cuenta | `08-onb-paso4` |
| 9 | Paso 5 de 7 | Saldo (obligatorio, «o 0») | `09-onb-paso5-saldo` |
| 10 | Paso 6 de 7 | Categorías: 11 grupos, «Recomendado» | `10-onb-paso6` |
| 11 | Paso 7 de 7 | «Así queda tu Yala» y privacidad | `11-onb-paso7-resumen` |

Con «Solo anotar mis gastos» el onboarding baja a 5 pasos [Cód `Yala/App/Logic/OnboardingStepPlan.swift:64-66`].
Con la opción nube activa aparece además «¿Dónde guardar tus datos?» y desaparece el reinicio
[Cód `WelcomeAccountChoiceLogic.swift:60-74`, `WelcomeMirrorRelaunchLogic.swift:103-104`].

**Lo que ve al llegar al Panel** [Cap `12-primer-panel` a `20-tendencias-vacia`]:

- Balance de noviembre «S/ 0.00», «Aún no tienes registros en este período · Tienes S/ 1,500.00 en tus cuentas».
- Fila de acciones: Nuevo registro, y Voz, Foto y Yala IA **con candado**.
- Avisos en carrusel: **1 de 3** «GUÍA · Este es tu resumen»; **2 de 3** «Primeros pasos · 0 de 7 completados»;
  **3 de 3** «Lleva tus finanzas al siguiente nivel · Pasarme a Pro».
- Tus finanzas (desplegada, una tarjeta), Tendencias de saldo con **un solo punto**, Planificación con «Sin pagos
  próximos» y «Aún no tienes presupuestos» **sin botón**, y Últimos registros con «No hay registros para este periodo
  y filtros».

**Para crear** (desde el Panel, medido en el simulador salvo donde dice [Cód]):

| Qué | Camino | Toques |
|---|---|---|
| Presupuesto | Pestaña Planificación → «Nuevo presupuesto» | 2 [Cap `21`, `22`] |
| Pago planificado | Planificación → chip «Pagos planificados» → «Nuevo pago planificado» | 3 [Cap `25`, `26`] |
| Cuenta | «Tus finanzas» → «+» al final del carrusel de cuentas | 2-3 [Cód `PanelAccountsSection.swift:41-47`; no recorrido hoy] |
| Cualquiera de los tres | Primeros pasos → el paso abre su editor | 2-3, si encuentra la tarjeta en el aviso 2 de 3 |

## 3. Mapa de fricciones

**Severidad.** *Alta*: puede impedir llegar a la primera utilidad (§5) o choca de frente con el reporte de usuarios.
*Media*: suma esfuerzo o confusión, pero hay salida visible. *Baja*: pulido.

La columna **Evidencia** dice qué se midió. La columna **Hipótesis** dice qué se cree que provoca y que nadie midió.
Una fricción solo es «Alta» por evidencia si el reporte de Jürgen [Rep] o una captura la respaldan; si no, la
severidad es la estimada y lo dice.

### 3.1 Bienvenida y entrada

| # | Fricción | Evidencia | Hipótesis | Sev. |
|---|---|---|---|---|
| F1 | El camino privado obliga a **salir de la app y volver a abrirla** antes del primer paso del onboarding | [Cap `04-reabre-yala`]; [Cód `SwiftDataConfiguration.swift:383`, `WelcomeMirrorRelaunchLogic.swift:97-120`]; L1-4 lo mantuvo con una línea explicativa [Aud] | Parte de quien sale no vuelve a entrar ese día; no se sabe cuántos porque la pantalla no emite telemetría (F21) | Alta (estimada) |
| F2 | **11 pantallas** antes de ver la app, más el reinicio | [Cap §2] | Explica una parte del «se agota» [Rep] | Alta |
| F3 | Dos pantallas antes de decidir nada útil: presentación y selector | [Cap `01`, `02`] | Bajo costo por pantalla, pero suma al F2 | Baja |

### 3.2 Onboarding de 7 pasos

| # | Fricción | Evidencia | Hipótesis | Sev. |
|---|---|---|---|---|
| F4 | El saldo es obligatorio y llega en el paso 5 | [Cap `09`]; [Cód `OnboardingNextEnablement.swift:52-53`]; feedback del 13-oct [Rep]; L1-7 lo mantuvo obligatorio [Aud] | Quien no sabe su saldo duda, aunque el texto diga «Escribe 0» | Alta |
| F5 | «¿Dónde está tu dinero?» mezcla una estrategia («Todo junto») con cuatro tipos de cuenta, y no trae nada preelegido | [Cap `07`]; [Cód `OnboardingNextEnablement.swift:48-49`] | El principiante no sabe qué es «cuenta corriente» ni si debe elegir varias | Media |
| F6 | Las categorías se aceptan en bloque: 11 grupos y **62 subcategorías** sembradas sin preguntar cuáles usa | [Cap `10`]; [Cód `Yala/Seed/CategorySeed.swift`, 11 padres y 62 hijas contados] | Es el origen del «demasiadas categorías al presupuestar» (F24) [Rep] | Media |
| F7 | El resumen final habla de «Datos en tu cuenta», «Acceso con tu cuenta» e «IA a través de nuestro servidor» en un camino privado y sin cuenta | [Cap `11`] | El texto no describe lo que acaba de pasar; puede inquietar a quien eligió privado | Baja |
| F8 | «Paso 1 de 7» en el onboarding y, al llegar, «0 de 7 completados» en Primeros pasos | [Cap `05`, `13`] | La persona lo lee como **14 tareas**, no como 7 + 7 distintas; refuerza el «se agota» [Rep] | Alta (estimada) |

### 3.3 Primer Panel

| # | Fricción | Evidencia | Hipótesis | Sev. |
|---|---|---|---|---|
| F9 | Primeros pasos es el **aviso 2 de 3**: queda detrás de la guía «Este es tu resumen» y hay que tocar «Ver el siguiente» para verlo | [Cap `12`, `13`]; [Cód `PanelNoticeQueueLogic.swift:15-31`] | Muchas personas nunca ven la guía de 7 pasos; el orden de L3-8 la ponía antes, y en el día 1 la guía del Panel le gana | Alta |
| F10 | El primer día ya hay una oferta Pro en el Panel (aviso 3 de 3) y candados en Voz, Foto y Yala IA | [Cap `12`, `14`]; [Cód `ProUpsellService.swift:56-74`, sin mínimo de sesiones] | Primera impresión de «app de pago»; choca con el espíritu de L1-12, que alejó la oferta del final del onboarding | Media |
| F11 | Widgets vacíos **sin acción**: «Aún no tienes presupuestos», «Sin pagos próximos» | [Cap `19`]; [Cód `BudgetsWidget.swift:300-311`, `ScheduledPaymentsWidget.swift:195-206`] | Es exactamente «no encuentro cómo crear presupuestos ni pagos» [Rep] | Alta |
| F12 | Tendencias dibuja una gráfica con **un solo punto** y Últimos registros habla de «filtros» que nadie puso | [Cap `20`, `19`]; [Cód `RecentRecordsWidget.swift:266-272`] | «Las gráficas salen vacías» [Rep]: la gráfica no está vacía, está sin sentido, y no dice cuándo lo tendrá | Media |

### 3.4 Primeros pasos (guía de 7)

| # | Fricción | Evidencia | Hipótesis | Sev. |
|---|---|---|---|---|
| F13 | De los 7 pasos, **3 construyen las finanzas** de la persona (gasto, presupuesto, pago). Dos son funciones Pro con candado (voz, foto), uno es abrir Ajustes y otro es el paywall | [Cap `15`]; [Cód `Yala/App/Models/SetupStep.swift:17-24`, `PanelView.swift:123-150`] | La guía mide «conocer la app», no «que la app te sirva»; cansa sin devolver valor [Rep] | Alta |
| F14 | No se puede quitar antes de terminar: «Minimizar» vuelve a desplegarse a las 3 sesiones | [Cód `SetupChecklistManager.swift:36, 283`] | Quien ya entendió la app la vive como insistencia | Media |
| F15 | Encima de la guía hay más capas el primer día: banner GUÍA en cada pantalla nueva, guía de Ajustes, «¡Listo!» a pantalla completa en los 3 primeros registros, «¿Era de prueba?», permiso de notificaciones | [Cód `ContextualGuideBanner.swift`, `TransactionSaveFeedbackLogic.swift:22`, `NotificationPrimerMomentLogic.swift`]; [Cap `21`: dos banners GUÍA en Planificación] | Cada capa está bien sola; juntas, son la sensación de «tutorial que no acaba» | Media |

### 3.5 Crear cuenta, presupuesto y pago

| # | Fricción | Evidencia | Hipótesis | Sev. |
|---|---|---|---|---|
| F24 | Al elegir categorías de un presupuesto salen **11 grupos desplegables a 62 subcategorías**, ordenados por nombre, **incluido «Ingresos»**, cada uno con su «Seleccionar todo» | [Cap `23`, `24`]; [Cód `BudgetEditorViewModel.swift:69-72`] | «Ve demasiadas categorías al presupuestar» [Rep]. «Ingresos» en un límite de gasto confunde | Alta |
| F16 | El formulario de presupuesto enseña a la vez período, activo, widget, alertas y una sección de filtros (cuentas, subcategorías, etiquetas, necesidad del gasto) | [Cap `22`, `23`] | Para el primer presupuesto bastan nombre e importe; el resto parece obligatorio | Media |
| F17 | «Mostrar en el widget» viene apagado en un presupuesto nuevo | [Cap `22`] | Quien crea su primer presupuesto puede no verlo en el Panel. L3-13 enseña los dos más usados si no hay favoritos: **comprobar** si eso lo cubre | Baja (por confirmar) |
| F18 | El pago planificado pide tipo, nombre, importe, categoría (con las mismas 62), cuenta, frecuencia, día y fecha | [Cap `26`] | Para «avísame del alquiler el 5» sobran la mitad de los campos | Media |
| F19 | Para crear una cuenta más hay que ir al final del carrusel de «Tus finanzas»; no hay entrada en un menú de crear | [Cód `PanelAccountsSection.swift:41-47`]; L3-9 eligió la variante con chips [Aud]. No recorrido hoy | «No encuentro cómo crear cuentas» [Rep] | Media (por confirmar en pantalla) |

### 3.6 Navegación y medición

| # | Fricción | Evidencia | Hipótesis | Sev. |
|---|---|---|---|---|
| F20 | La pestaña donde viven presupuestos y pagos se llama «Planificación», y al desplazar el Panel la barra se encoge a Panel y Buscar | [Cap `12`, `16`]; [Cód `TabBarConfiguration.swift:67-69`] | «Planificación» no le dice «presupuestos» a quien los busca; con la barra encogida, desaparece | Media |
| F21 | No hay forma de medir dónde se abandona después del onboarding: sin evento de primer registro, de Primeros pasos ni de la pantalla de reabrir | [Cód `MetricsUse.swift:42-56` cubre hasta `alta.termina`; `registrarMovimiento` cuenta una vez al día] | Sin esto, ninguna alternativa se podrá comparar con datos | Alta (para decidir) |
| F22 | Ningún XCUITest ve lo que ve una persona nueva: Primeros pasos, banners y tips se ocultan en los tests | [Aud: mapa de flujos, «un hueco que afecta a todos los lotes»] | Las regresiones de esta zona solo las ve una persona | Media |
| F23 | El onboarding de 7 pasos no limita el ancho en iPad (la bienvenida sí, a 560 pt) | [Cód `WelcomeForm.swift:30-32`; ausencia en `OnboardingView.swift`] | En iPad horizontal los campos quedan muy anchos. No se miró en pantalla | Baja (por confirmar) |

**Lectura rápida.** Las cuatro quejas del reporte tienen evidencia directa: agotamiento (F1, F2, F8, F13), demasiadas
categorías (F6, F24), gráficas vacías (F12) y no encontrar dónde crear (F9, F11, F19, F20). Lo que **no** está
medido es cuánta gente abandona en cada punto (F21).

## 4. Matriz de siete perfiles

**Evaluación heurística simulada, no entrevistas.** Cada perfil se recorrió mentalmente sobre las capturas del §2 y
el código. El riesgo es la probabilidad estimada de que ese perfil se trabe o abandone en esa parte: **A** alto,
**M** medio, **B** bajo. Nada de esto es un dato de uso.

### 4.1 Los perfiles y por qué estos

| # | Perfil | Por qué está |
|---|---|---|
| P1 | **Migrante de Excel que quiere algo simple** | Pedido por el encargo. Ya tiene sus categorías y su saldo en una hoja; quiere traerlos y no reconfigurar todo |
| P2 | **Principiante abrumado por las finanzas** | Pedido por el encargo. No conoce «presupuesto», «cuenta corriente» ni «saldo inicial»; cada pregunta le cuesta |
| P3 | **Anotador rápido que no lee** | Es el modo «Solo anotar mis gastos» de la app y una de las cinco lentes de la auditoría 2.2. Mide si el camino corto es de verdad corto |
| P4 | **Usuario experto que viene de otra app de finanzas** | Sabe lo que quiere (presupuesto por categoría, pagos fijos) y mide si la app estorba a quien no necesita guía |
| P5 | **Llega por una invitación de grupo** | Es otra puerta de entrada («Dividir gastos con amigos»). No vino a ordenar sus finanzas; mide si el alta personal le estorba |
| P6 | **Varias monedas y tarjeta de crédito** | Perfil frecuente en Perú (soles y dólares, tarjeta). Mide la parte más difícil del onboarding: cuentas, moneda y saldo negativo |
| P7 | **Persona mayor con texto grande, a veces en iPad** | Mide accesibilidad y pantallas grandes, que el encargo pide como compatibilidad, y la tolerancia a pantallas largas |

### 4.2 La matriz

| Parte del recorrido | P1 Excel | P2 Principiante | P3 Anotador | P4 Experto | P5 Grupo | P6 Multimoneda | P7 Texto grande |
|---|---|---|---|---|---|---|---|
| Bienvenida y reinicio (F1-F3) | M: el reinicio le parece un fallo | **A**: no entiende por qué salir | **A**: lo deja ahí | M | B: su camino no pasa por aquí | M | **A**: instrucción fuera de la app |
| Onboarding 7 pasos (F4-F8) | M: quiere importar, no teclear | **A**: saldo y tipos de cuenta | M: 5 pasos con «Solo anotar» | B | — | **A**: una sola moneda «principal», saldo de tarjeta | M: 7 pantallas largas |
| Primer Panel (F9-F12) | M: gráficas sin datos | **A**: no sabe qué tocar primero | B: solo usa «Nuevo registro» | M: candados y oferta Pro | M | M | M: avisos en carrusel |
| Primeros pasos (F13-F15) | M | **A**: 0 de 7 tras 7 pasos | M: le sobra | **A**: lo vive como ruido | B | M | M |
| Crear cuenta (F19) | **A**: tiene varias cuentas que traer | M | B | M | B | **A**: necesita 2-3 cuentas | M |
| Crear presupuesto (F24, F16, F17) | M: ya tiene su lista | **A**: 62 opciones | B: no presupuesta | M: quiere elegir rápido | B | M | **A**: lista larga con texto grande |
| Crear pago planificado (F18) | M | M | B | B | B | M | M |
| Navegación (F20) | M | **A**: «Planificación» | B | B | M | M | M |

### 4.3 Qué es «primera utilidad» para cada uno (heurístico)

| Perfil | Primera utilidad | Qué lo haría abandonar |
|---|---|---|
| P1 Excel | Ver sus cuentas y saldos reales en la app | Tener que teclear lo que ya tiene en la hoja |
| P2 Principiante | Anotar un gasto y ver «te quedan X» | Una pregunta que no entiende y no puede saltar |
| P3 Anotador | Primer gasto guardado en menos de un minuto desde que abre | Cualquier pantalla entre abrir y anotar |
| P4 Experto | Un presupuesto por categoría funcionando | Guías y ofertas que no puede quitar |
| P5 Grupo | Ver el gasto del grupo | Que le pidan su saldo personal para entrar a un grupo |
| P6 Multimoneda | Ver soles y dólares por separado y la deuda de la tarjeta bien | Un total mezclado o un saldo de tarjeta con el signo mal |
| P7 Texto grande | Anotar un gasto sin que nada se corte | Botones tapados o instrucciones fuera de la app |

## 5. Criterios de «primera utilidad» y de abandono

Propuesta para medir, no medición. Están pensados para que se puedan calcular con la telemetría propia que ya
existe más los eventos que faltan (§7.1).

**Primera utilidad (activación).** Una instalación nueva está *activada* cuando, en sus primeras 72 horas, cumple las
dos cosas:

1. Terminó el alta (`alta.termina`, ya existe), y
2. guardó **al menos un registro propio**: un gasto o ingreso que no es el saldo inicial y que no marcó «Era de
   prueba».

Por qué así: el primer registro es lo único que los siete perfiles necesitan para que la app les sirva; los
presupuestos y pagos dependen del perfil (P3 y P5 no los quieren). El umbral de 72 horas es un punto de partida y se
ajusta con los primeros datos, no con una cifra inventada.

**Abandono.** Se miden tres, por separado:

| Tipo | Definición | Cómo se ve |
|---|---|---|
| Abandono en el alta | Llegó a `alta.bienvenida` y no a `alta.termina` | El último `alta.paso.*` dice dónde |
| Abandono en el reinicio | Llegó a la pantalla «Reabre Yala» y no volvió a abrir en 24 h | Necesita el evento nuevo de esa pantalla |
| Abandono temprano | Terminó el alta y no está activada a las 72 h | Necesita el evento de primer registro |

**Secundarios por perfil**, solo para quien eligió esa intención: primer presupuesto en 7 días (si eligió «Llevar el
control»), primer pago planificado en 7 días, segunda cuenta creada.

## 6. Combinaciones para elegir

Cuatro paquetes coherentes. Cada uno junta alternativas de [`alternativas.md`](alternativas.md) (los códigos A1,
B2… son de ahí). **No hay recomendación cerrada**: el último bloque dice qué inclina la balanza.

### Combinación 1 · «Menos capas» (lo mínimo que ataca el reporte)

Sin cambiar el onboarding: estados vacíos con acción (C2), Primeros pasos primero y sin oferta Pro el día 1 (C4),
guía recortada a lo que construye finanzas (D1), selector corto en presupuestos sin «Ingresos» (H2), y la telemetría
del §7.1.

- **Ataca:** F9, F10, F11, F24, F13. Deja F1, F2 y F4 como están.
- **Esfuerzo:** bajo-medio. **Riesgo:** bajo. Todo determinista, sin tocar sync.
- **Para quién:** P2, P3, P4. Poco para P1 y P6.

### Combinación 2 · «Alta corta + Panel que crece»

La 1, más un onboarding de 3 pasos con valores por defecto (B1), plantillas por intención que preconfiguran el Panel
(B5), Panel de día 1 reducido con revelado progresivo (C1) y guía por objetivo (D2).

- **Ataca:** también F2, F5, F6, F8, F12.
- **Reabre:** L1-7 si el saldo pasa a «0 por ahora» con aviso. Se puede mantener obligatorio y la combinación sigue
  en pie.
- **Esfuerzo:** medio. **Riesgo:** medio (Panel por defecto y modos de uso; tocar `PanelDefaults` afecta a la nube).
- **Para quién:** P2, P3, P7. Bien para P1 si se suma importar (E4).

### Combinación 3 · «Conversación guionizada» (determinista con cara de chat)

La 1, más un onboarding en formato de conversación sin IA (B4 / V3): burbujas, respuestas en botones, «¿Qué es esto?»
con explicaciones escritas por paso. Opcionalmente, «Pregúntale a Yala» para Pro con consentimiento (V4).

- **Ataca:** F4, F5 y el miedo del principiante; no acorta el número de preguntas por sí sola.
- **Esfuerzo:** medio-alto (vista nueva, 16 idiomas, VoiceOver de un chat). **Riesgo:** medio.
- **Para quién:** P2 sobre todo; neutral o peor para P3 y P4, que quieren ir rápido.

### Combinación 4 · «Sin reinicio»

Cualquiera de las anteriores más quitar la salida obligada del camino privado (A2 o A4).

- **Ataca:** F1, el único punto donde la persona sale de la app.
- **Reabre:** L1-4.
- **Esfuerzo:** alto. **Riesgo:** alto: toca el arranque de SwiftData con CloudKit, la zona donde un bug sale más
  caro. Exige review adversarial y su propio encargo.

### Qué inclina la balanza

- **Si el reinicio pierde mucha gente** (se sabrá con el evento de §7.1 en dos o tres semanas), la combinación 4 pasa
  delante de todo lo demás.
- **Si el abandono está después del alta** (terminan el onboarding y no registran), la 1 y la 2 dan más por menos.
- **La 3 compite con la 2, no la complementa**: las dos rehacen el onboarding. Elegir una.

## 7. Plan de validación sin métricas inventadas

### 7.1 Primero, poder medir (requisito de todo lo demás)

Ampliar el embudo que ya existe en `Yala/Services/Metrics/MetricsUse.swift` (`alta.*`) con eventos sin datos
personales, uno por instalación:

| Evento propuesto | Cuándo | Para |
|---|---|---|
| `alta.reabrir.mostrada` / `alta.reabrir.vuelve` | Al enseñar «Reabre Yala» y al volver a entrar | Abandono en el reinicio (F1) |
| `primeros.registro` | El primer registro propio (no saldo inicial, no «Era de prueba») | Activación (§5) |
| `primeros.pasos.<paso>.{hecho,saltado}` y `primeros.pasos.minimizar` | En Primeros pasos | Qué pasos sirven (F13, F14) |
| `primeros.presupuesto`, `primeros.pago`, `primeros.cuenta2` | La primera vez de cada uno | Secundarios (§5) y si se encuentran (F11, F19) |
| `panel.vacio.accion.<widget>` | Toque en el botón de un estado vacío (si se implementa C2) | Si el botón se usa |

Esto es código y va con su propio encargo. Hasta que no haya **al menos unas semanas de altas reales** medidas así,
el documento no tiene números y no debe inventarlos.

### 7.2 Después, comparar

1. **Línea base.** Con los eventos de §7.1 en producción, recoger las altas de 2-3 semanas sin otros cambios en esta
   zona. Resultado: dónde se cae la gente hoy, por paso.
2. **Un cambio cada vez, en orden de riesgo.** Primero la combinación 1 (barata y reversible). Comparar contra la
   línea base las mismas tasas de §5. Como el volumen de altas es pequeño, **no se hará un test A/B con significación
   estadística**: se compara antes/después y se dice el tamaño de la muestra junto a cada cifra.
3. **Pruebas de pasillo, declaradas como tales.** Cinco o seis personas reales de los perfiles P1, P2 y P7 (familia,
   amigos, testers de TestFlight que no conocen la app) hacen el alta en un iPhone de pruebas sin ayuda. Se anota
   dónde dudan y qué dicen. Se reporta como observación cualitativa con el número de personas, nunca como porcentaje.
4. **Revisión con las capturas.** Antes de implementar cualquier combinación, Jürgen la aprueba sobre el simulador
   (no sobre un lienzo), como en las auditorías anteriores.
5. **Red de tests.** Un XCUITest que recorra el alta **con** Primeros pasos y banners visibles cerraría F22 y evitaría
   que lo arreglado vuelva.
