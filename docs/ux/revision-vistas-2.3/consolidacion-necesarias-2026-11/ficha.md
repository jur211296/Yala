# Consolidación final 2.3 · Mejoras necesarias de las revisiones por vistas

**Qué es.** Lee las revisiones por vistas 2.3 que seguían sin consolidar (zonas 34 a 41) y separa lo **necesario**
—bugs, fallos de accesibilidad, regresiones y textos que dicen algo falso— de lo que es **preferencia o rediseño**.
Lo necesario queda en **11 lotes** de 3 a 5 arreglos pequeños, cada uno con su card y su encargo listo para encolar.
No cambia la app, no elige alternativas de rediseño y no encola nada: los encargos los encola Frank cuando Jürgen dé el OK.

> **Completa (9-nov-2026): entran las 8 zonas pedidas, de la 34 a la 41.** La 41 · Dónde viven tus datos aterrizó en
> `origin/2.3` a mitad de esta sesión (PR 865). Hasta entonces la entrega iba a salir parcial; se rebasó y se procesó.

Base: `origin/2.3` del 9-nov-2026. Las zonas 30 y 32 ya tuvieron sus lotes de necesarias, Panel y Formulario (PR 854 y
855); no se repiten aquí y su numeración de la cola no es la de estos lotes. La 31 no tuvo lote y queda fuera de este encargo (ver «Fuera de este encargo»).

## Mapa de cobertura real

| Zona | Estado en `origin/2.3` | PR | Evidencia | Qué sale de aquí |
|---|---|---|---|---|
| 30 · Panel | Revisada y consolidada antes | [846](https://github.com/jur211296/Yala/pull/846) | `30-panel/ficha.md` | Lote de Panel, ya mergeado ([854](https://github.com/jur211296/Yala/pull/854)) |
| 31 · Registros | Revisada, sin lote de necesarias | [847](https://github.com/jur211296/Yala/pull/847) | `31-registros/ficha.md` | Fuera del encargo |
| 32 · Nuevo registro | Revisada y consolidada antes | [848](https://github.com/jur211296/Yala/pull/848) | `32-nuevo-registro/ficha.md` | Lote de Formulario, ya mergeado ([855](https://github.com/jur211296/Yala/pull/855)) |
| 34 · Planificación | Revisada, mergeada el 7-nov | [852](https://github.com/jur211296/Yala/pull/852) | `34-planificacion/ficha.md` + 17 secundarios | Lote 04 y un punto del lote 02 |
| 35 · Estadísticas | Revisada, mergeada el 7-nov | [853](https://github.com/jur211296/Yala/pull/853) | `35-estadisticas/ficha.md` + 11 secundarios | Lotes 07, 05 y 02 |
| 36 · Reportes y Flujo | Revisada, mergeada el 7-nov | [859](https://github.com/jur211296/Yala/pull/859) | `36-reportes-flujo/ficha.md` + 12 secundarios | Lotes 08, 05 y 02 |
| 37 · Grupos | Revisada, mergeada el 7-nov, con siete tickets | [856](https://github.com/jur211296/Yala/pull/856) · [857](https://github.com/jur211296/Yala/pull/857) | `37-grupos/ficha.md` + 16 secundarios | Lotes 01, 06 y 02 |
| 38 · Bandeja e IA | Revisada, mergeada el 7-nov, con tres tickets | [860](https://github.com/jur211296/Yala/pull/860) | `38-bandeja-ia/ficha.md` + 12 secundarios | Lotes 03 y 05 |
| 39 · Cuentas y categorías | Revisada, mergeada el 9-nov | [862](https://github.com/jur211296/Yala/pull/862) | `39-cuentas-categorias/ficha.md` + 11 secundarios | Lotes 09 y 05 |
| 40 · Perfil y Ajustes | Revisada, mergeada el 9-nov | [864](https://github.com/jur211296/Yala/pull/864) | `40-perfil-ajustes/ficha.md` + 13 secundarios | Lotes 10 y 05 |
| 41 · Dónde viven tus datos | Revisada, mergeada el 9-nov | [865](https://github.com/jur211296/Yala/pull/865) | `41-nube-almacenamiento/ficha.md` + 10 secundarios | Lote 11; cinco puntos de datos ya en su card de decisión |

Los índices de los PR 850 y 851 se titularon «parcial» y «final» el 7-nov con solo 3 zonas: no cubren nada de esta tabla.
El `README.md` de esta carpeta sigue diciendo que las zonas 34 a 40 están pendientes. Está desactualizado y no se toca aquí.

## Cómo se clasificó

| Clase | Qué entra | Qué se hace |
|---|---|---|
| **Necesaria** | Bug, accesibilidad que impide leer o usar, texto que dice algo falso, regresión | A un lote |
| **Ya en 2.2** | 2.2 ya lo arregló y 2.3 no lo tiene (`git log origin/2.3..origin/2.2`) | Fuera de los lotes: llega con la integración de 2.2 en 2.3, que espera decisión |
| **Decisión** | Pide elegir entre alternativas, cambia el modelo o reabre algo decidido | A la lista de decisiones (están en cada ficha) |
| **Rediseño o preferencia** | Mejora de flujo o de jerarquía sin defecto objetivo | Se queda en la ficha de su zona |
| **Menor** | Defecto real pero cosmético, sin efecto en lo que el usuario entiende | Sin lote; anotado aquí |
| **Por verificar** | Hipótesis sin reproducir y sin forma barata de fijarla | Sin lote; anotado aquí |

**Medido para esta consolidación** (9-nov, en `origin/2.3`): barra naranja al 75 % (`BudgetProgressBar.swift:22`)
frente al 80 % de 2.2; validación del «Único» (`BudgetEditorView.swift:869-879`); gastos sin subcategoría que salta el
desglose (`BudgetsViewModel.swift:640`); `Picker("Tab")` (`ScheduledPaymentsView.swift:127`); hoja de no considerados del
mes en curso (`CashFlowOthersSheet.swift:22-29`); «vs» escrito a mano (`CashFlowCellDetailSheet.swift:452`); «este %@» en
2.3 y en 2.2; «insights» y «Sin conexion… estaran» en `Localizable.strings` (es); cambio de moneda del grupo al apagar
(`GroupSettingsView.swift:460-472`); `prefix(2)` de divisas (`CurrencySettingsView.swift:250`); alto fijo de Etiquetas
(`TagsSettingsListView.swift:127`); «Cancela en Ajustes» (`uxpro.trial.cancelBody`); Siri gratis encendido
(`SiriOnDeviceEntry.isEnabled = true`). **Lo demás sale de la ficha de cada zona**, con su evidencia allí.

## Clasificación por hallazgo

### 34 · Planificación

| Hallazgo | Clase | Razón | Destino |
|---|---|---|---|
| P1 · Al 90 % dice «Te quedan», «En el límite» y «Hoy te pasaste» | Decisión | Unificar umbrales y palabras es S1, un rediseño | Ficha |
| P2 · Al pasarse no ayuda | Rediseño | Añade acciones nuevas (X2) | Ficha |
| P3 · Editar qué cuenta un presupuesto: dos puertas y 7 toques | Rediseño | E2 cambia el flujo | Ficha |
| P4 · Un pago vencido se mezcla con los próximos | Rediseño | Sección nueva (V1) | Ficha |
| P5 · Saltar se anuncia como pagado (D3) | **Necesaria** | Texto falso; ya tenía card | Lote 04 |
| P5 · Apuntar un pago no se deshace (D1); «Ya no está pagado» deja el gasto (D2) | Decisión | Cambia qué pasa con los datos | Ficha |
| P6 · Calendario con cifras de 6-9 pt | Rediseño | C2 pliega la vista | Ficha |
| Mes cerrado dice «Te quedan» | **Necesaria** | Texto falso | Lote 04 |
| Barra naranja desde el 75 % sin palabra | Ya en 2.2 | El 80 % único está en 2.2 | Integración |
| Decimales mezclados en la lista | Ya en 2.2 | «Todas las filas escriben los importes igual» | Integración |
| Alertas apagadas con avisos pedidos | Por verificar | L9-4 lo trató; pide un teléfono recién instalado | — |
| Borrar un presupuesto sin «Deshacer» | Rediseño | Paridad deseable, sin defecto | — |
| «No se apunta nada…» bajo los dos botones | **Necesaria** | Se lee como explicación de «Ya lo pagué», que sí apunta | Lote 04 (con D3) |
| ✓ del editor apagado sin decir qué falta | **Necesaria** | Va con el «Único» de un día, que lo provoca | Lote 04 |
| «Único» de un solo día no se puede guardar | **Necesaria** | Bug: el valor por defecto no se guarda | Lote 04 |
| Reactivar un inactivo sin mirar el límite gratis | **Necesaria** | Saltaría el límite del plan; reproducir antes | Lote 04 |
| «Ya lo apunté» sin destacar la coincidencia | Rediseño | Mejora de búsqueda | — |
| VoiceOver: «Tab», selectores sin nombre, fila sin lo que queda | **Necesaria** | Accesibilidad | Lote 04 |
| «Por categoría» de Gráficas puede no sumar | **Necesaria** | Cifra financiera | Lote 02 |
| Error al cargar pintado como «Aún no tienes presupuestos» | Menor | Falta estado de error; no se vio fallar | — |
| «Periodo» y «Período» | Menor | Ortografía mezclada | — |
| «Categoría» del editor elige una subcategoría | Menor | Rótulo impreciso | — |
| Ingreso en índigo y en turquesa | Menor | Color incoherente | — |
| El teclado tapa «Clasificación» al abrir | Menor | Foco inicial | — |
| Pago compartido propone USD en un grupo en soles (visto en la zona 37) | Por verificar | Salió con la región del simulador | — |

### 35 · Estadísticas

| Hallazgo | Clase | Razón | Destino |
|---|---|---|---|
| P1 · «¿En qué se me fue la plata?» sin respuesta en un sitio | Rediseño | A1 cambia la cifra grande | Ficha |
| P2 · Tocar una categoría filtra en vez de abrirla | Decisión | Reabre lo decidido el 25-26 oct | Ficha |
| P3 · Con texto grande se cortan importes y pestañas | **Necesaria** | Accesibilidad; las fichas de Resumen ya están en 2.2 | Lote 05 (Distribución y pestañas) |
| P4 · «Balance», «Saldo» y «Saldo de cuentas» | Decisión | Nombres, junto con PN-1 del Panel | Ficha |
| P5 · VoiceOver lee recuentos en las gráficas | Decisión | V1 y V2 se preguntan; cruza con las cards de VoiceOver de gráficas | Ficha |
| P6 · Con una semana de datos afirma de más | Decisión | Umbral de datos (F1); el bug «este Este mes» sí entra | Lote 07 (solo el bug) |
| P7 · ~2 s congelada con diez años | Decisión | Pide medir con Instruments antes | Ficha |
| «este Este mes» | **Necesaria** | Texto roto, en 2.3 y en 2.2 | Lote 07 |
| iPad: Distribución a todo el ancho | Decisión | Patrón de ancho en iPad, común a 35, 36, 37 y 39 | Decisiones |
| Los flotantes tapan importes al desplazar | Menor | Patrón ya tratado en L15-14; no tapa acciones | — |
| La comparación cambia en silencio en Tendencias | Decisión | Qué compara cada pestaña | Ficha |
| «8 categorías» frente a «7» de VoiceOver | **Necesaria** | Dos cifras para lo mismo | Lote 07 |
| «11696 registros» sin separador | **Necesaria** | Formato de número | Lote 07 |
| Las guías de Tendencias y Registros dicen lo contrario de lo que enseñan | **Necesaria** | Texto falso | Lote 07 |
| El Sankey corta etiquetas y su botón es «$» con soles | **Necesaria** | Texto cortado y moneda equivocada | Lote 07 |
| «insights» en inglés y «Aún no tienes categorías» con categorías | **Necesaria** | Texto falso o sin traducir | Lote 07 |
| «Día de más gasto» y «tu día más caro» salen de dos cálculos | **Necesaria** | Pueden contradecirse | Lote 02 |
| Un toque sintético a veces no llega | Menor | Del simulador, no del dedo | — |

### 36 · Reportes y Flujo de caja

| Hallazgo | Clase | Razón | Destino |
|---|---|---|---|
| P1 · Cinco cifras para «¿llego a fin de mes?» | Decisión | Rótulos y cifra del mes; reabre el lote 18 | Ficha |
| P2 · Real y estimado iguales, con siete nombres | Decisión | Vocabulario fijo | Ficha |
| P3 · El plan vive en Más › Reportes, con 18 líneas | Rediseño | Reordena el armado | Ficha |
| P4 · Leer un mes son 25 tarjetas iguales | Rediseño | Agrupar | Ficha |
| P5 · Con AX3 se pierden nombres; «No-viem-bre» | **Necesaria** | Accesibilidad | Lote 05 |
| P6 · «Noviembre» comparando del 1 al 7 | Decisión | Rótulo del tramo, se pregunta junto con abrir desglosada | Ficha |
| P7 · Primera semana sin ingresos: «Te faltan S/ 2,573» | Decisión | A añade una pregunta nueva | Ficha |
| El ritmo sin plan cuenta dos veces el sueldo | **Necesaria** | Cálculo; la ficha pide card propia con review adversarial | Lote 02 |
| iPad a todo el ancho | Decisión | Patrón de ancho en iPad | Decisiones |
| «Gastos no considerados» siempre del mes en curso | **Necesaria** | Bug, medido en el código | Lote 08 |
| La hoja de configurar una línea es inalcanzable | Menor | Código muerto que no ve nadie | — |
| Free ve el flujo de caja avanzado | Decisión | Monetización: ¿es a propósito? | Decisiones |
| «vs» escrito a mano en los 16 idiomas | **Necesaria** | Sin traducir | Lote 08 |
| Widget: tramo punteado confuso | Decisión | Lo decidió la 12A; reabrirlo es de Jürgen | Ficha |
| «Disponible» en el widget y «Saldo» en el Panel | Decisión | Nombres, con P4 de Estadísticas | Ficha |
| Índigo y rosa como texto, por debajo de AA | **Necesaria** | Contraste | Lote 08 |
| Gráficas da otra cifra para la misma línea | Decisión | Promedio frente a mes; la hoja lo explica | Ficha |
| Vacío «No hay registros en este periodo» | **Necesaria** | Texto falso | Lote 08 |
| La proyección depende de «Empezaste con» en 0 | Por verificar | Visto solo con la semilla de rendimiento | — |

### 37 · Grupos

| Hallazgo | Clase | Razón | Destino |
|---|---|---|---|
| P1 · «No le debes nada a nadie» sobre «Tú pagas a Ana» (A4) | **Necesaria** | Texto que se contradice | Lote 06 |
| P1 · «Menos pagos» apagado por defecto (A1) | Decisión | Cambia el valor por defecto | Ficha |
| P2 · «1,100.00» al escribir | **Necesaria** | Ya tenía ticket | Lote 01 |
| P2 · Un reparto que suma 399,99 se guarda | **Necesaria** | Cifra financiera: medir adónde va el céntimo | Lote 02 |
| P2 · Partir desigual cuesta 11 toques (B2) | Rediseño | Cambia el modelo del reparto | Ficha |
| P3 · Saldar: quién apunta, pagar de más, sin confirmación | Decisión | C1 a C3 se preguntan | Ficha |
| P4 · Soles y dólares sin compensar | Decisión | D1 y D4, con tasa a elegir | Ficha |
| P5 · Con texto grande se corta lo que se decide | **Necesaria** | Accesibilidad; botones de la lista y cabecera ya están en 2.2 | Lote 06 (VoiceOver) · el resto, en 2.2 |
| P5 · VoiceOver lee «0.00» | **Necesaria** | Accesibilidad | Lote 06 |
| P6 · La X tira el gasto a medias | Decisión | Se pregunta F1 y dónde aplica | Ficha |
| P7 · El iPad se estira | Decisión | Patrón de ancho en iPad | Decisiones |
| «¡Están al día!» en un grupo nuevo | **Necesaria** | Texto falso | Lote 06 |
| Un grupo archivado deja apuntar | **Necesaria** | Ya tenía ticket | Lote 01 |
| El reintento duplica el pago | **Necesaria** | Ya tenía ticket | Lote 01 |
| El saldo inicial se reemplaza sin avisar | **Necesaria** | Mueve datos sin preguntar | Lote 01 |
| Los pendientes de confirmar solo salen en Saldos | Rediseño | Dónde se listan | — |
| «¿Quién puso más?» tapa los nombres | **Necesaria** | Ya tenía ticket | Lote 06 |
| Vocabulario de saldar (L13-5) y del puente (L13-14) | Decisión | Pendiente desde 2.2 | Ficha |
| Las opciones de Ajustes del grupo leen de una sección perezosa | Por verificar | Ya tenía ticket, sin reproducir | Ticket en backlog |
| Apagar «deudas en una moneda» cambia la moneda para todos | Decisión | Qué debe pasar con la moneda del grupo | Decisiones |
| «Importar todo el historial» solo si ya hay reflejados | **Necesaria** | Ya tenía ticket; la lógica va al revés | Lote 01 |
| «Desde un recibo» no deja corregir el importe | Rediseño | Función nueva | — |
| El «+» tapa el importe al desplazar | Menor | Igual que en la zona 35 | — |
| «Tus grupos te esperan» no dice qué espera | Menor | Texto vago, no falso | — |
| «Salir del grupo» tras un rechazo, sin confirmar | Menor | El grupo no era tuyo: no se pierden datos | — |

### 38 · Bandeja, Yala IA, correo del banco, Apple Pay y Siri

| Hallazgo | Clase | Razón | Destino |
|---|---|---|---|
| P1 · Lo que se apunta solo vive en tres sitios | Rediseño | A2 es una pantalla nueva | Ficha |
| P2 · Revisar 8: deslizar guarda sin pista | Decisión | Se pregunta si se queda | Ficha |
| P3 · El lote y deslizar no miran duplicados | **Necesaria** | Ya tenía ticket; puede guardar dos veces | Lote 03 |
| P3 · «55 %» y un duplicado sin nombre (C1) | Rediseño | Búsqueda al llegar | Ficha |
| P4 · El gasto de grupo pregunta mal | Rediseño | D1 cambia la hoja | Ficha |
| P5 · Yala IA sin servidor dice «en unos minutos» | Decisión | F1 y F3 se preguntan | Ficha |
| P6 · Correo del banco sin estado | Rediseño | E1 es un estado nuevo | Ficha |
| P7 · Con texto grande se parten los botones | **Necesaria** | Accesibilidad | Lote 05 |
| Siri dice «Requiere Yala Pro» a quien no le hace falta | **Necesaria** | Texto falso; Siri gratis está encendido | Lote 03 |
| Tope de 500 con archivados | **Necesaria** | Ya tenía ticket; puede esconder un pendiente | Lote 03 |
| Cuatro nombres para la Bandeja | Decisión | Se pregunta «Bandeja» en toda la app | Ficha |
| Los textos no nombran el correo del banco | Rediseño | Va en A4 | Ficha |
| «Hoy» repetido y una cabecera que pisa | Menor | Va en B4 | Ficha |
| El aviso de archivar tapa los botones | Menor | Solo con 30 s forzados | — |
| La caja del chat dice «Escribe tu pregunta…» | Menor | Va en F4 | Ficha |
| Conversación de ejemplo sin rotular tras el muro | Menor | No se confunde con datos guardados | — |
| «registro automático» sin decir de dónde | Menor | Texto vago | — |
| «Correos que llegaron sin leerse: 3» | Decisión | Qué pasa al pasar a Pro | Ficha |
| Guía de Apple Pay: «Nombre respectivamente» y su contador | **Necesaria** | Instrucción rota | Lote 03 |
| El atajo de Apple Pay no enlaza a su guía | Rediseño | Va en A4 | Ficha |

### 39 · Cuentas, tarjetas, categorías, etiquetas y divisas

| Hallazgo | Clase | Razón | Destino |
|---|---|---|---|
| P1 · Archivar aparta lo gastado | Decisión | Opción A decidida el 8-oct y sin hacer; trabajo grande con card propia | Decisiones |
| P2 · Las categorías no se pueden ordenar | Rediseño | B1 es una función nueva | Ficha |
| P8 · Con AX3, Cuentas pierde los nombres | Ya en 2.2 | Fila con `AdaptiveRowStack` en 2.2 | Integración |
| P8 · Con AX3, Etiquetas pierde la última fila (H2) | **Necesaria** | Accesibilidad | Lote 05 |
| P3 · Crear una categoría pide la subcategoría al final | Rediseño | C1 cambia el flujo | Ficha |
| P4 · El ajuste de saldo preelige reescribir todos los meses | Decisión | Qué opción va por defecto | Decisiones |
| P5 · La lista enseña el número de cuenta | Decisión | E1 está aprobado (3-oct); E2 toca lo guardado | Decisiones |
| P6 · «Monedas secundarias» confunde | Rediseño | F1 renombra la sección | Ficha |
| P7 · «No lo uses al registrar» de cuatro formas | Decisión | G1 elige un nombre | Ficha |
| Saldos con «PEN» en la lista y «S/» en el resto | **Necesaria** | La misma cifra escrita de dos formas | Lote 09 |
| USD y EUR elegidas sin pedirlo | Decisión | Va con el problema 6 | Ficha |
| Sin secundarias, «Tipo de cambio» enseña dos al azar | **Necesaria** | Bug (`prefix(2)`) | Lote 09 |
| El «+» crea una categoría vacía antes de escribir | **Necesaria** | Puede dejar una categoría sin nombre; reproducir antes | Lote 09 |
| Cabecera de una categoría nueva | Menor | Se corrige al escribir | — |
| «Gastos por necesidad» y «Necesidad» | Menor | Rótulos distintos | — |
| La X de Etiquetas no pregunta; corta a 20; «#5E5CE6» | **Necesaria** | Pierde cambios y oculta el corte | Lote 09 |
| Se guarda el número completo de una tarjeta | Decisión | Privacidad: pedir cuatro dígitos y recortar lo guardado | Decisiones |
| iPad: la ficha va en una hoja de media pantalla | Decisión | Patrón de ancho en iPad | Decisiones |
| Aviso de varias divisas a toda tarjeta nueva | Menor | Bien explicado | — |

### 40 · Perfil, Más, Ajustes, Pro y ayuda

| Hallazgo | Clase | Razón | Destino |
|---|---|---|---|
| P1 · 31 filas sin buscador | Rediseño | A2 reordena | Ficha |
| P2 · Filas que no abren lo que dicen | Decisión | B1 renombra y mueve | Ficha |
| P3 · Pro enseña primero el precio | Rediseño | C1 es una tabla nueva | Ficha |
| P4 · Exportar abre en «Todo» | Rediseño | D1 añade opciones; el motivo de la fila apagada (D4) sí entra | Lote 10 (D4) |
| P5 · La ayuda vive al fondo | Rediseño | E1 | Ficha |
| P6 · «Cómo usas Yala» y «Modo de uso» | Decisión | F1 o F2 | Ficha |
| P7 · Con AX3 los títulos se parten por sílabas | **Necesaria** | Accesibilidad; los iconos (G1) se preguntan | Lote 05 |
| Cabecera «Usuario / Editar perfil» | Rediseño | Jerarquía | — |
| «Más sobre tus datos» abre una web | Menor | Sin conexión no carga | — |
| Dos «‹» en Proteger con Face ID | Menor | Aspecto | — |
| «Cancela en Ajustes» | **Necesaria** | Manda al sitio equivocado | Lote 10 |
| «Temas» abre «Apariencia» | Menor | Nombre distinto | — |
| «Abrir el teclado en» dentro de Formato | Rediseño | Sitio | — |
| Dos filas sobre dónde están los datos | Decisión | Es el problema 7 de la zona 41 | Zona 41 |
| «Resumen con IA» sin marca Pro | **Necesaria** | Presenta como gratis algo que es Pro | Lote 10 |
| Notificaciones no avisa del permiso denegado | Menor | Avisa al encender | — |
| «Ajustes» al final de Más | Rediseño | Sitio | — |
| «Vaciar datos» junto a Exportar | Rediseño | Separación | — |
| Pestañas: dos textos para lo mismo | Menor | Redundante | — |
| «Versión 2.2 (Build 7)» en 2.3 | Menor | Número de versión de la rama; lo pone el release | — |
| Ajustes tarda ~1 s con diez años | Decisión | ¿Se suma a la card del App Hang de Perfil? | Ficha |

### 41 · Dónde viven tus datos: nube, iCloud y cierre de sesión

La ficha marca cinco decisiones como **(datos)** y ya las llevó a la card «Decidir: cinco puntos de datos de la revisión
de “Dónde viven tus datos”» (`tablero-decidir-cinco-puntos-de-datos-de-la-revi-46yz`, en «espera decisión»). No se duplican.

| Hallazgo | Clase | Razón | Destino |
|---|---|---|---|
| P1 · Nueve nombres y seis verbos para dos sitios | Decisión | T1 o T2 eligen los nombres | Ficha |
| P2 · Cifrado y fotos plegados en «Ver los detalles» | Decisión (datos) | Lo que se acepta al activar | Card de datos |
| P3 · Volver a iCloud promete «en pausa por si vuelves» | Decisión (datos) | V1, V2 o V4 | Card de datos |
| P7 · Con iCloud apagado, el estado afirma una copia que no existe (S2) | Decisión (datos) | Texto falso sobre los datos; la ficha lo manda a la card de datos | Card de datos |
| P7 · Dos filas para la misma pregunta (S1) | Decisión | Juntar filas | Card de datos |
| P4 · «Desasociar» encima de la acción | Decisión (datos) | G1 acerca un gesto que mueve datos | Card de datos |
| P5 · 43 textos de fallo con solo «Reintentar» | Rediseño | E1 es una plantilla nueva | Ficha |
| P6 · La subida no dice cuánto falta; «Ya casi está» dice «Sesión cerrada» | Decisión | R1 y R2 se preguntan | Ficha |
| P8 · Con texto grande el estado se aprieta y el pie ocupa media pantalla | **Necesaria** | Accesibilidad; la ficha dice que puede ir sin esperar | Lote 11 |
| «Activar sin borrar» cancela un borrado pedido, en un globo | Decisión (datos) | Toca datos | Card de datos |
| «Iniciar sesión con Apple» y «Continuar con Apple» | Menor | Dos rótulos para el mismo gesto | — |
| Cifras con tres formatos | **Necesaria** | La misma cifra escrita de tres formas | Lote 11 |
| El consentimiento manda a «Exportar datos», que se llama «Exportar registros» | **Necesaria** | Manda a una fila que no existe con ese nombre | Lote 11 |
| «Sí, cancelar» no dice qué cancela | Decisión | Globos de cancelar de un flujo que mueve datos | Ficha |
| Nota de cuenta rechazada en naranja como texto | **Necesaria** | Contraste por debajo de AA en claro | Lote 11 |
| La tarjeta «Grupos» bajo el error con el mismo peso | Rediseño | Jerarquía | — |
| «Salir de mis grupos»: palabras internas y «retomarlo desde Vaciar datos» | **Necesaria** | Manda a una fila distinta de la que se usó | Lote 11 |
| «Desasociar»: la diferencia entre las dos opciones solo en un párrafo | Decisión (datos) | Va con G1 | Card de datos |
| Paneles de QA en «Sincronización iCloud» de Yala Dev | Por verificar | Van tras `#if DEV_BUILD` y `#if DEBUG`; comprobar en TestFlight | — |

## Lotes, en orden

El orden pone primero lo que pierde o duplica datos y las cifras financieras, después la accesibilidad y al final los
textos; el 11 entró al final, con la zona 41. Los once están en `encargos/pendientes/`, **sin encolar**. Cada card está en backlog, firmada por Frank.

| Orden | Lote | Puntos | Card | Encargo |
|---|---|---|---|---|
| 1 | Grupos: pagos que se duplican, dígitos que se pierden y cambios sin aviso | 5 (cuatro tickets ya escritos) | `tablero-mejoras-necesarias-2-3-grupos-pagos-que-d8nx` | `2026-11-09-necesarias-01-grupos-dinero-y-datos.md` |
| 2 | Cifras que no cuadran: ritmo, desglose de presupuesto, día más caro y céntimo del reparto | 4 | `tablero-mejoras-necesarias-2-3-cifras-que-no-cua-efqj` | `2026-11-09-necesarias-02-cifras-que-no-cuadran.md` |
| 3 | Bandeja: duplicados en el lote, borradores fuera de la lista y textos de Siri y Apple Pay | 4 (tres tickets ya escritos) | `tablero-mejoras-necesarias-2-3-bandeja-duplicado-btrx` | `2026-11-09-necesarias-03-bandeja-duplicados-y-textos.md` |
| 4 | Planificación: saltar no es pagar, mes cerrado, presupuesto de un día y límite gratis | 5 (reusa la card de «Saltar») | `tablero-mejoras-necesarias-2-3-planificacion-sal-7nwx` | `2026-11-09-necesarias-04-planificacion-saltar-y-limites.md` |
| 5 | Texto grande en Estadísticas, Reportes, Bandeja, Ajustes y Etiquetas | 5 | `tablero-mejoras-necesarias-2-3-texto-grande-en-e-zoid` | `2026-11-09-necesarias-05-texto-grande-pantallas-secundarias.md` |
| 6 | Grupos: saldos que se contradicen y lectura con VoiceOver | 5 (dos tickets ya escritos) | `tablero-mejoras-necesarias-2-3-grupos-saldos-que-pl00` | `2026-11-09-necesarias-06-grupos-saldos-y-voiceover.md` |
| 7 | Estadísticas: textos que dicen lo que no es | 5 | `tablero-mejoras-necesarias-2-3-estadisticas-text-9qip` | `2026-11-09-necesarias-07-estadisticas-textos.md` |
| 8 | Flujo de caja: mes equivocado, «vs» sin traducir, vacío y contraste | 4 | `tablero-mejoras-necesarias-2-3-flujo-de-caja-mes-tyuj` | `2026-11-09-necesarias-08-flujo-de-caja-mes-y-textos.md` |
| 9 | Cuentas, categorías, etiquetas y divisas: lo que aparece sin pedirlo | 4 | `tablero-mejoras-necesarias-2-3-cuentas-categoria-u8nd` | `2026-11-09-necesarias-09-cuentas-categorias-etiquetas.md` |
| 10 | Ajustes y Pro: textos que mandan al sitio equivocado | 3 | `tablero-mejoras-necesarias-2-3-ajustes-y-pro-tex-t1w8` | `2026-11-09-necesarias-10-ajustes-y-pro-textos.md` |
| 11 | Dónde viven tus datos: textos que mandan a otra fila, cifras y texto grande | 5 | `tablero-mejoras-necesarias-2-3-donde-viven-tus-d-s0v6` | `2026-11-09-necesarias-11-donde-viven-tus-datos-textos-y-texto-grande.md` |

Los lotes 1 y 2, y el primer punto del 3, piden review adversarial: tocan pagos entre personas, el puente con tus
cuentas, cifras financieras y el paso de borrador a registro. El 11 toca solo textos y maquetación de la zona de la nube: la lógica que mueve datos espera su card de decisión. Los lotes 1 y 6 tocan Grupos: van en serie y detrás del PR
abierto de 2.2 sobre borradores de grupo duplicados. Cada encargo manda comprobar antes si 2.2 ya lo arregló.

## Decisiones que quedan para Jürgen

Las listas completas de cada zona siguen en su ficha. Aquí van solo las que **frenan algo necesario** o se repiten
entre zonas:

1. **¿Cuándo entra 2.2 en 2.3?** Ya está en «espera decisión» (`tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c`).
   Cinco hallazgos de esta tanda ya están arreglados en 2.2 y no van en ningún lote: la barra naranja al 80 %, los
   decimales iguales en Presupuestos, las fichas de Resumen y Pagos planificados con texto grande, los botones de Grupos
   apilados y la fila de Cuentas con texto grande. Si eliges dejar divergir las ramas, hay que portarlos a mano.
2. **Free ve el flujo de caja avanzado** (zona 36): `cashFlowAdvanced` no es solo Pro, así que el recorte de 3 meses y
   el aviso de Pro nunca actúan. ¿Es a propósito o se cierra? Ticket:
   `tickets/backlog/cash-flow-advanced-gate-never-limits-free-users.md`.
3. **Apagar «Ver las deudas en una sola moneda»** (zona 37) cambia la moneda del grupo a la de quien lo apaga, para
   todos y sin preguntar. ¿Se conserva la moneda del grupo, se pregunta o se deja así? Ticket:
   `tickets/backlog/group-single-currency-off-changes-the-group-currency-for-everyone.md`.
4. **Número de cuenta** (zona 39): el campo guarda el número completo de una tarjeta. ¿Solo cuatro dígitos, y se
   recortan los ya guardados (E2)? Es privacidad.
5. **Ajustar el saldo** (zona 39): la opción preelegida puede reescribir todos los meses. ¿«Registro de ajuste» siempre
   por defecto (D2)?
6. **Archivar conserva el historial** (zona 39): la opción A del 8-oct sigue sin hacer y es trabajo grande con su card
   (`tablero-archivar-una-cuenta-decidir-si-oculta-su-9brj`). ¿Cuándo entra?
7. **Ancho en el iPad** (zonas 35, 36, 37 y 39): cuatro zonas piden lo mismo, ancho legible o dos columnas. ¿Un patrón
   común antes de tocar cada una?

## Fuera de este encargo

- **Zona 31 · Registros**: no tuvo lote de necesarias y el encargo no la nombra. Su ficha trae arreglos baratos de texto
  (B3, F1 + F3, L3, T1 y E2) que nadie ha consolidado.
- **Hallazgos menores y por verificar**: quedan en las tablas de arriba, sin card ni lote, para no fabricar trabajo.

## Cómo se reanuda si aparece otra revisión

Ninguna zona del encargo queda pendiente. Si se revisa otra (por ejemplo, la 31 · Registros), su consolidación sigue el
mismo método: clasificar problemas y secundarios, cruzarlos con el tablero, con lo que ya trae 2.2 y con estos once lotes,
y añadir un lote nuevo si hace falta. Se pide como un encargo nuevo en la cola, sin rutinas nuevas.
