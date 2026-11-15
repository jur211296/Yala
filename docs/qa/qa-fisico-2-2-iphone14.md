# QA físico de la 2.2 en el iPhone 14 — 2026-11-09

Sesión de Frank sobre el iPhone 14 de pruebas, conectado por cable a la Max y conducido con Device MCP.

- **Build:** Yala Dev 2.2 (7), compilada desde `origin/2.2` al día (`5200c9a21`) e instalada con `xcodebuild` + `devicectl`.
  El `build_and_run` de Device MCP pide la licencia Pro.
- **Teléfono:** iPhone 14 (iPhone14,7), iOS 27.2, en modo oscuro. Al empezar, Yala Dev estaba en la nube (Google) con
  datos de prueba.
- **Alcance:** las 28 cards de 2.2 que estaban en «in qa»: 17 de Frank y 11 de Jürgen. El encargo hablaba de 16 y 12;
  la cuenta de arriba sale del tablero a las 18:05.
- **Capturas:** `/Users/max-jur/Claude/entregas/2026-11-09-qa-fisico-2-2-iphone14/evidencia/` (PNG a resolución
  completa). Cada card lleva en su nota las rutas que la prueban.

## Resultado

| Resultado | Cards |
|---|---|
| Pasa y a done | 6 (Frank) |
| Pasa en el teléfono, sigue en qa | 1 de Frank, que espera el visto bueno de Jürgen · 3 de Jürgen (una entera y dos en el paso que el iPhone 14 permite) |
| Falla para 2.2 | 2 (Frank): el arreglo está en 2.3, no en 2.2 |
| No verificable en el teléfono | 8 (Frank) · 1 (Jürgen, StoreKit) |
| Evidencia para Jürgen (no se mueve) | 7 (Jürgen) |
| Hallazgos nuevos | 3 cards en backlog de 2.2 |

## Cards de Frank

| Card | Resultado | Qué se probó |
|---|---|---|
| Con el texto al máximo, cifras cortadas o partidas | **Pasa → done** | Al tamaño de accesibilidad más grande se leen enteros el saldo de Tendencias, las fichas de Resumen (una por fila) y los botones del pago. La cifra de la lista de Pagos también. El borrador de voz no se puede provocar sin dictar: lo cubre la captura del simulador del PR del arreglo. |
| Con el texto al máximo, la zona fija de «Guardar» pisa el formulario | **Pasa → done** | En Nuevo registro y en el onboarding, lo que pasa bajo el botón se difumina. En Nuevo gasto de Grupos el contenido se esconde bajo la barra con un borde limpio, y nada se lee encima. |
| Crash del refresco en segundo plano del widget | **Pasa → done** | Cerrar sesión en la nube: sale la bienvenida y Yala sigue abierta, con el mismo proceso a los 16 s. No hay `.ips` nuevo; el último es del 6-nov. |
| Crash en `__swift_memcpy17_8` | **Pasa → done** | El arreglo está en 2.2. El camino del crash (cerrar sesión desde la hoja de Ajustes con datos y un grupo) termina sin crash. |
| Ícono Liquid Glass | **Pasa → done** | Guion completo: modos Por omisión, Oscuro, Traslúcido y Tintado (dos colores), el alternativo Neón y la vuelta al Original. |
| Selección de cuentas de doble línea | **Pasa → done** | Con la tarjeta «Sapphire» en PEN y su línea en USD, la hoja Cuenta muestra «Sapphire · PEN» (PEN) y «Sapphire · USD» (USD). |
| Cuentas de sistema de Grupos en una sola «Grupos» | Pasa, **sigue en qa** | Tarjeta «Grupos» con una línea por grupo y chip «Grupos S/ 60». El saldo total cuadra. Espera el visto bueno de Jürgen (pregunta 4 del barrido). |
| La app se congela por completo (YALA-IOS-A) | **Falla para 2.2** | El arreglo de la foto de perfil está mergeado en 2.3, no en 2.2: en `origin/2.2` la foto no se reduce y su test no existe. |
| La app se traba parcialmente (YALA-IOS-9 y D) | **Falla para 2.2** | El mismo arreglo, más el filtro de cuelgues de desarrollo: los dos solo están en 2.3. |
| Yala se cierra por exceso de memoria (YALA-IOS-B) | No verificable | Los avisos eran ruido. El filtro que los quita de las builds de desarrollo está solo en 2.3. |
| CI: tandas de UI del QA programado | No verificable | Es del CI. En GitHub, los QA programados del 7 y del 8-nov salieron en verde con las 9 tandas. |
| iPad: Panel en el esqueleto de carga | No verificable | Es del iPad. El PR del barrido final está mergeado en 2.2 con tests en verde. |
| Evento dentro de la app | No verificable | Es de App Store Connect. |
| Páginas de producto personalizadas | No verificable | Es de App Store Connect. |
| Rehacer capturas App Store 2.2 | No verificable | Son de marketing. |
| Sentry: token y dSYM | No verificable | Es del archivado y de Sentry. |
| Vídeo de vista previa del iPad 13" | No verificable | Es de la ficha. |

## Cards de Jürgen (evidencia; las aprueba él)

| Card | Resultado en el teléfono |
|---|---|
| Pago planificado ya pagado: botones con el mes | **Pasa**: «Noviembre de 2026 ya está pagado», «Próximo: diciembre de 2026», «Ya pagué diciembre» y «Saltar diciembre». |
| Siri gratis con el modelo del iPhone | **Paso 7 pasa**: en el iPhone 14 sin Apple Intelligence y sin Pro, Atajos › «Anotar con Siri» avisa «Activa Yala Pro…» y abre la hoja de Pro. Los pasos 1 a 6 piden un iPhone con Apple Intelligence. |
| Cerrar sesión con cambios: crash | **Paso 1 pasa**: bienvenida, sin crash y sin `.ips`. Los pasos 2 y 3 piden entrar con Google. El caso de cambios sin subir no se provocó. |
| Al renovar desde «Tu suscripción terminó» | **No verificable con Yala Dev**: «No pudimos cargar los precios» también tras Reintentar. Pide la build de TestFlight y la cuenta de Sandbox. |
| Sheets de selector en cristal | Cuenta y Categoría de Nuevo registro, y Cuenta de Nuevo gasto de Grupos, salen en cristal con el monto rosa difuminado detrás. No se probó Yala IA › Detalles, que necesita el servidor de IA. |
| Widgets con profundidad | Widget «Disponible» en la pantalla de inicio en los cuatro modos. |
| Onboarding con los estilos de la app | Onboarding completo en 7 pasos, con títulos centrados y tarjetas a la izquierda. |
| Grupos: degradado del tema y montos en texto normal | Dentro del grupo, los montos van en texto normal. La lista va en verde por el rediseño del 30-oct. El éxito del gasto sigue en verde: es la pregunta abierta. |
| Grupos en blanco, gráficas y Welcome centrado | Grupos con fondo del tema, Gráficas del Flujo de caja, Comparativa y Welcome centrados. La intro de Grupos conserva su degradado: es la pregunta abierta. |
| Grupos tiene que sentirse la misma app | Lista, detalle y alta de gasto. |
| Flujo de caja tiene que sentirse la misma app | Inicio, plan y Gráficas. |

## Hallazgos nuevos (backlog 2.2, Frank)

1. **Dos títulos cortados a tamaño normal en el iPhone 14**: el tercer paso de la intro de Grupos dice «Salda deudas con
   un par de toq…», y la tarjeta del Panel dice «Pagos plani…».
2. **Con el texto al máximo**, los iconos de vista de Pagos planificados se solapan y «Pagado» sale «Paga…». El menú del
   + también parte o corta sus opciones: «Gru-po», «Ima-gen», «Ma…».
3. **Onboarding**: la moneda sale «sol peruano» en minúscula, y en Cuentas, «Sol Peruano».

## Estado en que quedó el teléfono

- Yala Dev salió de la nube y quedó en una cuenta nueva de **iCloud privado** («Jur», «Mi dinero Soles», S/ 1500).
  Volver a la cuenta de Google pide su inicio de sesión.
- En la página 2 de la pantalla de inicio quedó un widget «Disponible» de Yala Dev.
- El aspecto de los íconos volvió a Oscuro, el texto a su tamaño normal y «Simular Pro» quedó apagado.
