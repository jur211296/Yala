---
name: arnes-de-maquetas-dentro-de-la-app
description: Para maquetas «realistas» de una hoja de Yala, un arnés DEBUG con `-mockupNR` dentro de la app pinta la hoja real y las variantes con piezas reales; se guarda como parche, no como rama.
metadata:
  type: reference
---
Ronda 2 de Nuevo registro (2026-11-19): el arnés sustituye a `ContentView` en `YalaApp.leaderContent` cuando hay
`-mockupNR <variante>:<escenario>`, espera `isBootstrapSettled`, siembra lo suyo y presenta con `.sheet(item:)`.
La columna «hoy» es la vista real con `prefillFromChatDraft` (monto, cuenta, subcategoría, etiquetas); las variantes
usan `SelectionChip`, `YalaPrimaryButton`, `ExchangeRateCapsule`, `AmountText`. 176 capturas en ~30 min con un bucle de
`simctl launch` + `io screenshot` (8-10 s por captura; teclado real con `ConnectHardwareKeyboard` apagado).
Parche: `~/Claude/entregas/2026-11-19-nuevo-registro-b-realista-maquetas/arnes-maquetas-nuevo-registro.patch`.

**Why:** el pre-commit bloquea Swift sin gate, así que la «rama descartable» no puede tener commits; y con
`.sheet(isPresented:)` el contenido salió vacío la primera vez (regla de swiftui-ds.md).
**How to apply:** próxima maqueta de una hoja, aplicar el parche y cambiar las vistas; la transferencia (o cualquier
estado sin precarga) se consigue tocando con `tap` de XcodeBuildMCP, nunca con axe — [[axe-no-ve-las-hojas]].
En zsh, `set -- $x` no parte palabras: usa `a=(${=x})` en los bucles de capturas.
