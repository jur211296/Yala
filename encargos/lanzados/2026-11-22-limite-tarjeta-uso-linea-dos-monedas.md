Yala
# Mostrar el uso de línea también en las tarjetas con dos monedas
---
toca: Yala/App/Views/Panel/Sheets/HojaCuentaTarjeta/,Yala/Resources/de.lproj/LimiteTarjeta.strings,Yala/Resources/en-GB.lproj/LimiteTarjeta.strings,Yala/Resources/en.lproj/LimiteTarjeta.strings,Yala/Resources/es-419.lproj/LimiteTarjeta.strings,Yala/Resources/es-AR.lproj/LimiteTarjeta.strings,Yala/Resources/es-ES.lproj/LimiteTarjeta.strings,Yala/Resources/es.lproj/LimiteTarjeta.strings,Yala/Resources/fr.lproj/LimiteTarjeta.strings,Yala/Resources/it.lproj/LimiteTarjeta.strings,Yala/Resources/ja.lproj/LimiteTarjeta.strings,Yala/Resources/nl.lproj/LimiteTarjeta.strings,Yala/Resources/pl.lproj/LimiteTarjeta.strings,Yala/Resources/pt-BR.lproj/LimiteTarjeta.strings,Yala/Resources/pt-PT.lproj/LimiteTarjeta.strings,Yala/Resources/pt.lproj/LimiteTarjeta.strings,Yala/Resources/zh-Hans.lproj/LimiteTarjeta.strings,YalaTests/LimiteTarjetaDosMonedas/,tickets/backlog/2026-11-22-limite-tarjeta-uso-linea-dos-monedas.md,tickets/done/2026-11-22-limite-tarjeta-uso-linea-dos-monedas.md
esfuerzo: medium
cierre: cierra-sola
---

El 22-nov (decisión registrada t1890u-3) Jürgen pidió que el «uso de línea» («X % usado · N disponible de M») salga también en las tarjetas de crédito con dos monedas. Hoy la hoja de la tarjeta lo oculta cuando hay varias divisas (ticket `tickets/qa/2026-11-22-cuenta-limite-tarjeta-campo-sincronizado.md`, PR #1121 ya en 2.3; campo `Account.creditLimit` en la divisa de la cuenta).

## Qué hacer
- En la hoja de la tarjeta (`HojaCuentaTarjeta*`), cuando la tarjeta tiene límite y deuda en dos monedas, muestra la línea calculando lo usado en la divisa del límite. La deuda en la otra moneda se convierte con el tipo de cambio que la app ya usa (no agregues fuentes nuevas de cambio ni nada de pago).
- Deja claro que incluye un monto convertido, con un texto corto bajo la línea o un «aprox.», sin un botón debajo de otro. Elige la redacción más clara y anótala en «Decidido sin consultar».
- Si no hay tipo de cambio disponible para esa pareja, no muestres la línea (igual que hoy) y anótalo.
- Sin límite, nada (como hoy). Una sola divisa queda igual.
- Textos nuevos en todos los `LimiteTarjeta.strings`, en español neutro latinoamericano (en es-ES también, sin vosotros).
- Tests nuevos en `YalaTests/LimiteTarjetaDosMonedas/`: dos monedas con cambio, sin cambio, saldo a favor en una de ellas y pasarse del límite.
- Semilla: si hace falta, una tarjeta QA con límite en soles y gastos en soles y dólares. Si eso exige tocar `Yala/Seed/`, toca lo mínimo y anótalo.
- Si necesitas tocar algo fuera del toca, toca lo mínimo y anótalo en el cierre.

## Criterios de aceptación
- La hoja de una tarjeta con dos monedas y límite muestra la línea con el porcentaje correcto y la nota de conversión, en iPhone (claro y oscuro) y en iPad. Las capturas van en el cierre.
- Una sola divisa y sin límite se ven igual que antes.
- Tests verdes y PR mergeado en 2.3.

## Dispositivos
Antes de usar un simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre (no lo des por ocupado sin comprobarlo). En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0

- **Divisa del límite:** la de la principal de la tarjeta (`account.currencyCode`), que la hoja recibe explícita.
- **Tipo de cambio:** `CurrencyConverter.convertCheckedWithLatestRate`, el mismo que da el «Total ≈» de la cabecera. «Sin tipo de cambio» = solo la tabla estática de reserva (`.staticFallback`): entonces no hay línea.
- **Saldo a favor:** cuenta como cero por divisa y no descuenta de la otra (regla que ya tenía la hoja).
- **Nota:** «Aprox.: incluye lo que debes en USD, al último tipo de cambio.», en texto pequeño bajo la línea, solo si se convirtió algo.
- **Semilla:** perfil nuevo `tarjeta-limite-dos-monedas` (fuera del toca, mínimo: un `case` y un parámetro).
- **Fuera del toca, mínimo:** `AccountDetailSheet.swift` (pasa la divisa), `LimiteTarjetaTexto.swift` (la clave nueva), el test de cableado de la hoja.
