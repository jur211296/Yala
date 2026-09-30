# Evidencia · ipad-list-detail-for-groups-and-settings-and-chat-inspector (2026-09-29)

Capturas antes y después del paso 7 del carril adaptativo (fase 2): Grupos y Ajustes con lista y detalle, y Yala IA en
una columna junto a Panel, Registros y Estadísticas.

## Cómo se sacaron

- Simuladores del carril, iOS 27.0, siempre por UDID: `YalaLane-Adapt-iPad-Pro-13` (`AE7C6D3F…`),
  `YalaLane-Adapt-iPad-mini` (`8BBAB498…`), `YalaLane-Adapt-iPhone-SE` (`8803FA85…`) y `YalaLane-Adapt-iPhone-ProMax`
  (`CDA87FB8…`). Corridas en cola con `qa/scripts/sim-lock.sh`; sin Cola A viva.
- Un XCUITest temporal (`ZZAdaptivePhase2CaptureUITests`, borrado antes del commit) lanza con Pro y el hook nuevo
  `-uitest-ai-chat-ready` (consentimiento del chat y su onboarding vistos): semilla `grupos` para Grupos, `realista`
  para lo demás.
- «Antes» es `2.1` en `9ed19c56e` con solo el hook de test y el identificador `chat_input` añadidos (no cambian nada
  visible); «después», el árbol del PR.
- Texto grande: `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large` (AX5).
- Nombre: `<dispositivo>__<v|h>-<nn>-<pantalla>.jpg` (`v` vertical, `h` horizontal). JPG con el lado mayor a 640 px;
  las comparaciones se hicieron sobre los PNG originales.

| nn | Pantalla |
|---|---|
| 01 | Grupos (lista) |
| 02 | Grupos con el primer grupo abierto |
| 03 | Ajustes (desde el avatar del Panel) |
| 04 | Ajustes con Divisa y Cambio abierto |
| 05 | Panel con Yala IA abierto |
| 06 | Registros con Yala IA abierto |
| 07 | Estadísticas › Registros con Yala IA abierto |

## Lo que se comprobó

| Dónde | Resultado |
|---|---|
| iPad Pro 13, vertical y horizontal | Grupos: lista y grupo a la vez, con las pestañas de arriba o la barra lateral a la vista (antes: el grupo tapaba todo y ocultaba la navegación). Yala IA: columna de 375 pt a la derecha; el Panel, Registros y Estadísticas se estrechan y siguen a la vista (antes: una hoja encima) |
| iPad mini, vertical | Grupos: la lista flota sobre el detalle vacío y se aparta al abrir un grupo, como Registros en la fase 1. Yala IA: el Panel se queda con el ancho de un iPhone al lado del chat |
| iPad mini, horizontal | Barra lateral + lista + grupo; Yala IA al lado |
| Ajustes en iPad | Hoja de página (antes 575 pt): lista y ajuste en el mismo split. Unas veces ocupa la pantalla con las dos columnas lado a lado y otras mide 810 pt y la lista flota y se aparta al abrir un ajuste (ticket `ipad-settings-sheet-size-depends-on-where-it-opens`). El ajuste se empuja sobre «Elige un ajuste» y lleva «Atrás». `ipad-pro-13__v-04` es del binario final; las demás de Ajustes en iPad, de la iteración anterior, que colocaba lo mismo pero sin pila propia en el detalle (el «+» de Categorías no empujaba: lo cazó el gate) |
| Registros con un registro abierto + Yala IA (iPad Pro 13 vertical) | La lista se aparta sola y el registro se lee entero al lado del chat; la lista vuelve con el botón de la barra |
| iPhone SE y Pro Max, por defecto y AX5 | **Iguales antes y después**. Diff píxel a píxel (umbral 5/255) quitando la barra de estado: 0 px en 10 de 28 pares. En 16 más la diferencia es la hora del separador «Hoy, h:mm» del chat, la hora de «Última actualización» de los tipos de cambio o el destello animado del avatar Pro. Los dos que faltan son Grupos en el SE (por defecto y AX5): en esa corrida el buscador salió desplegado; relanzado dos veces con el binario final sale plegado, como en `2.1` |

## Redimensionado

En `YalaLane-Adapt-iPad-Pro-13` en horizontal, borrado antes (`simctl erase` por UDID, la ventana recuerda su tamaño) y
con Ajustes → Multitarea y gestos → **Apps en ventanas**; un XCUITest temporal (`ZZAdaptivePhase2ResizeUITests`,
borrado) arrastra la esquina `(0.995, 0.995) → (0.4, 0.995)`:

| Captura | Qué se ve |
|---|---|
| `resize__c-01-pantalla-completa-chat-en-columna` | Registros con Yala IA en su columna y una conversación guardada (hook `-uitest-chat-conversation`) |
| `resize__c-02-ventana-estrecha-chat-en-hoja` | Ventana estrecha (compacta): Yala IA pasa a hoja con **la misma conversación** |
| `resize__g-01-pantalla-completa-grupo-en-columna` | Grupo abierto al lado de la lista |
| `resize__g-02-ventana-estrecha-la-app-se-cierra` | Al estrechar, **la app se cierra** y el sistema la vuelve a abrir en la bienvenida |

**El crash no es de esta fase.** Pasa igual con la lista de Grupos sin nada abierto y con una copia limpia de `2.1`
(`git archive`), tres corridas: `-[UITabBarController _tabs_rebuildTabBarItemsAnimated:]` →
`insertObject:atIndex:: object cannot be nil`. Con Registros seleccionado no pasa. Ticket
`ipad-narrowing-the-window-on-groups-crashes-the-app` (high), con la reproducción y lo que se probó.

**La vuelta a ancho no se capturó**, por lo mismo que en la fase 1 (XCUITest no sabe dónde está la esquina de una
ventana centrada). Guion en el ticket.

## Lo que no se pudo capturar

- **iPhone Duo**: no hay simulador del Duo en esta Mac (Xcode 27.1). Queda en `iphone-duo-native-app`.
- Yala IA sin red contesta «no está disponible»: las capturas enseñan la columna y su conversación, no una respuesta.
