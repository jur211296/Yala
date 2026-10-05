# Formulario de cuenta a media altura — evidencia (2026-10-03)

Capturas del alta y la edición de cuenta (Perfil › Cuentas), tomadas con un XCUITest temporal
que no se commitea. Simuladores `YalaLane-Adapt-*` por UDID, uno a la vez, borrados al acabar.

| Prefijo | Aparato | Qué se ve |
|---|---|---|
| `iphone-se__` | iPhone SE | Abre a media altura sobre la lista; arrastrar sube a pantalla completa. |
| `iphone-se-ax__` | iPhone SE, texto AX | Abre grande: a media altura solo cabía un campo. |
| `iphone-promax__` | iPhone Pro Max | Igual que el SE, con más lista visible por encima. |
| `ipad-pro-13__` | iPad Pro 13, ventana completa | Hoja centrada a tamaño completo: `.yalaSheetDetents` fuerza `.large` en ventana ancha. |

Pasos: `01` alta con el teclado abierto (el sistema sube la hoja para dejar sitio), `02` alta sin
teclado, `03` alta tras arrastrar la hoja hacia arriba, `04` edición de una cuenta del seed.
