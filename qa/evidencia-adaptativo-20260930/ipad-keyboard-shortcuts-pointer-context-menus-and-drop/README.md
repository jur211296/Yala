# iPad · fase 3: atajos, puntero, menús contextuales y soltar recibos — evidencia

Simuladores del carril, por UDID: `YalaLane-Adapt-iPad-Pro-13` (horizontal, barra lateral) y
`YalaLane-Adapt-iPhone-ProMax`. Seed `realista` + Pro; los menús de grupo, con el seed `grupos`. 2026-09-30.

Las capturas del iPad salen de XCUITest en horizontal, y por eso llevan una franja negra: es cómo el runner
encuadra la pantalla girada, no la app.

| Captura | Qué enseña |
|---|---|
| `ipad-02-cmdN-nuevo-registro` | ⌘N abre Nuevo registro |
| `ipad-03-cmdShiftN-gasto-grupo` | ⌘⇧N lleva a Grupos. El seed `realista` no trae grupos, así que el formulario de gasto espera al primero, como el FAB del Panel |
| `ipad-04-cmdK-yala-ia` | ⌘K abre Yala IA por su camino. Sin consentimiento previo, el aviso de consentimiento |
| `ipad-05-cmdComa-ajustes` | ⌘, abre Ajustes |
| `ipad-06-cmdF-buscar` | ⌘F lleva a Buscar con el campo activo |
| `ipad-07-cmd1…cmd6` | ⌘1…⌘6 en el orden de la barra lateral |
| `ipad-20` → `ipad-21` | Con un registro abierto, ↓ abre el siguiente («Bus» → «Mercado») |
| `ipad-13-borrar-tecla-fisica-confirmacion` | ⌫ con el registro abierto pide confirmación. Tecla física HID, ver abajo |
| `*-menu-registro` | Editar, Duplicar, Cambiar categoría y Eliminar |
| `*-menu-presupuesto` | Editar |
| `*-menu-grupo` | Abrir grupo y Nuevo gasto |
| `*-menu-cuenta` | Filtrar por esta cuenta y Editar cuenta |

## Lo que el simulador no enseña

- **La lista de atajos al mantener ⌘** no sale en las capturas de XCUITest: es una capa del sistema. Va al
  guion de `qa` para un iPad con teclado.
- **⌫ desde XCUITest no llega.** `typeKey` con Delete, Backspace o ⌘⌫ no dispara el atajo, mientras que ↓ sin
  modificador sí llega. Con la tecla física simulada (HID 42, XcodeBuildMCP) sí llega y sale la confirmación.
  Por eso el XCUITest de la fase cubre ⌘N, ⌘F, ⌘4 y ⌘E, y ⌫ queda en esta captura y en el guion.
- **Con el foco en la barra lateral, ↑↓ mueven la barra lateral**, no el registro. Es el comportamiento del
  sistema: al pasar con ⌘número de una página a otra, el foco se queda en la barra. Tocar un registro devuelve
  las flechas a la lista.
- **El resaltado del puntero y soltar una imagen desde el Mac** se comprueban a mano (guion del ticket).
