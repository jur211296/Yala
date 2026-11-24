---
id: 2026-11-23-avisos-del-banco-claridad-y-region
status: qa
priority: medium
area: "captura-atajo-banco-parte-2, ajustes"
created: 2026-11-23
updated: 2026-11-24
source: "pruebas de Yala 2.3 de Jürgen en el iPhone (23-nov), pantalla «Avisos del banco»"
---

# «Avisos del banco»: clara para principiantes, bancos según el país y activa solo cuando lo está

Jürgen probó «Avisos del banco» en el iPhone y reportó cinco problemas:

1. Poco intuitiva: mucha gente no sabe qué es la app Atajos ni qué es una automatización.
2. «Aviso» no dice a qué se refiere.
3. Con los datos en la cuenta de Yala, quien recibe los avisos por correo debería ir a «Correo del banco», no a Atajos.
4. La lista enseña siempre bancos de Perú (BCP, Yape, Interbank, Plin, BBVA, Scotiabank), también fuera de Perú.
5. Basta abrir un banco para que salga en «Activos · Esperando el primer aviso».

## Hecho cuando

- La lista explica qué es un aviso, con un ejemplo, y cómo funciona en tres líneas.
- Fuera de Perú (región del iPhone distinta de PE y moneda principal distinta de PEN) solo se ofrece «Tu banco o app».
- Abrir un banco no lo activa: «Aún no está activo» hasta «Ya lo configuré» o hasta que llegue un aviso.
- Un banco activo se puede quitar de «Activos», con confirmación.
- Con los datos en la cuenta de Yala y sesión, la lista y la pantalla del banco llevan a «Correo del banco».
- Tests unitarios de región y de activación, y un XCUITest del recorrido entrar → confirmar → quitar.

## Resolución (2026-11-23)

- `BankNoticeChoiceLogic` (nuevo, en `Views/Settings/AtajoBanco/`): qué bancos se ofrecen, cuándo un banco está activo
  y `BankNoticeActivityStore.deactivate`.
- `BankNoticesView`: «Un aviso es…», «Cómo funciona», lista filtrada por región o moneda, fila «Reenvía tus correos a
  Yala» con los datos en la cuenta de Yala.
- `BankNoticeBankView`: sin la activación al abrir; «Antes de empezar»; guía de seis pasos con los botones de Atajos;
  «Ya lo configuré»; «Quitar de Activos»; correo hacia «Correo del banco» con la cuenta de Yala.
- Textos en los 16 idiomas de `CapturaAtajoParte2.strings`.
- Pruebas: `YalaTests/AvisosDelBanco/AvisosDelBancoClaridadTests`,
  `YalaUITests/AvisosDelBanco/AvisosDelBancoActivacionUITests`, y el caso existente de `CapturaAtajoParte2UITests`
  pasa a esperar «Aún no está activo».

## Fuera, a propósito

- No se menciona SMS: no está confirmado que la automatización de notificación los lea.
- El aviso de ejemplo de «Tu banco o app» sigue en soles («S/ 25.00 en Starbucks Larcomar»), también fuera de Perú.
- Los nombres de los botones de Atajos en los 16 idiomas están escritos de memoria, sin un iPhone en cada idioma.

## Guion de QA en el iPhone 14 (Yala Dev, región Perú)

1. Ajustes › «Avisos del banco»: arriba se lee «Un aviso es…» y «Cómo funciona» en tres líneas.
2. Toca BCP: dice «Aún no está activo». Vuelve atrás: el BCP NO aparece en «Activos».
3. Entra al BCP y sigue los seis pasos en la app Atajos de verdad. Esperado: cada botón que nombra la guía
   («Automatización», «+», «Notificación», «App», «Ejecutar inmediatamente», «Siguiente», «Nueva automatización en
   blanco», «Agregar acción», «Texto», «Banco», «OK») existe con ese nombre. Apunta los que no coincidan.
4. Toca «Ya lo configuré»: el BCP pasa a «Activos · Esperando el primer aviso».
5. Haz una compra pequeña con la tarjeta: el estado pasa a «Funcionando» y el gasto llega a la Bandeja.
6. En el BCP, al final, «Quitar de Activos» › «Quitar»: vuelve a la lista y el BCP sale de «Activos».
7. Con los datos en tu cuenta de Yala: la lista enseña «¿Tu banco te avisa por correo?» y lleva a «Correo del banco».

## Barrido de QA 2026-11-24

Pasos 1, 2, 4 y 6 bien en el iPhone 14 (iOS 27.2.1), y «Probar» con el aviso de ejemplo también. El paso 3 falla: la guía describe el Atajos de iOS 26; en iOS 27.2 «Automatización» es una fila de Biblioteca, el «+» abre «Nuevo atajo» y no existen «Ejecutar inmediatamente», «Siguiente» ni «Nueva automatización en blanco». Sigue en QA hasta que cierre la card de bug «Avisos del banco: la guía de Atajos no casa con iOS 27» (`tablero-bug-2-3-avisos-del-banco-la-guia-de-ataj-zyaf`). El paso 5 (una compra real) va después. Detalle: `docs/qa/barrido-2-3-antes-build-8/lista.md`.
