# QA en el iPhone de pruebas — 2.2, 2026-11-05

Tanda del iPhone que dejó el barrido final (`tanda-qa-jurgen-2.2-barrido-2026-11-05-final`): los cuatro montajes del
30-oct (`tanda-qa-jurgen-2.2-barrido-2026-10-30.md`; el A, de `tanda-qa-jurgen-2.2-lote14-grupos-invitar.md`). Corrida
con Jürgen en la Max, conduciendo el iPhone con Device MCP.

- **Aparatos:** iPhone 14 de pruebas (iOS 27.2, por cable, Google `jur211296@gmail.com`) y, como quien invita, el
  simulador del iPad Pro 13 en la Max (Google `admin@yala-app.pe`). Staging limpio para las dos cuentas (lo midió el bot
  con el conector de Supabase).
- **Build:** Yala Dev (`Debug-Dev`) sobre `origin/2.2` en el merge de #809, contra staging, más el arreglo de «Pegar».
- **Evidencia:** `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/` (un vídeo por guion).

## Resultados

| Guion | Cards | Resultado | Lo visto |
|---|---|---|---|
| A · unirse a un grupo con dos aparatos | `046l`, `7xnd`, `ywm1` | **Pasa** (con un arreglo en este PR) | Grupo listo con Invitar y Avisos; mensaje con texto y enlace. «Pegar» no hacía nada → arreglado. El grupo se ve antes de pedir cuenta (bloqueante). «Solicitud enviada» sin volver a tocar «Unirme». Al aceptar, la pantalla cambia sola a «Ya estás en…»; «Apuntar un gasto» trae el grupo. Un solo push «Ya estás en…» y abre el grupo |
| B1 · activar la nube | `ppxk` | **Pasa** | 8 min 25 s (19:17:35 → 19:26:00). La cifra de «Subir tus datos» cambia cada ~6 s; no salió «Esperar a iCloud». Hallazgo: 3333 elementos para 2 registros |
| B2 · iCloud Drive apagado | `n5zw` | **Pasa** | Mismos datos sin Drive, ningún aviso; el registro creado sin Drive sigue al encenderlo |
| B3 · cerrar sesión con cambios | `7e60` | **Falla** | Sin red, la nube no deja cerrar sesión (por diseño; Yala no se cierra). Con red, **Yala se cierra** al terminar el cierre (crash en `ProfileViewModel.loadTransactions` al reaparecer Ajustes). Y «Ya tengo cuenta» › «¡Tu cuenta está lista!» › Empezar vuelve al Welcome. Card al backlog |
| C · barra de abajo personalizada | `fozu` | **Pasa** | Panel, Grupos y Registros: las cuatro vueltas abren su pantalla, sin negro |
| D · renovar en sandbox | `7c97` | **Pendiente** | Sin cuenta de sandbox en el iPhone 14; se sigue otro día. Pasos en la nota de la card |

## Arreglado en este PR

- **«Pegar» de la invitación (L12-16).** El gesto que oculta el teclado (`.dismissKeyboardOnTap()`) colgaba del
  `ScrollView`, padre del `PasteButton`, y se quedaba con su toque. Va en una capa de fondo: pega solo el enlace y tocar
  fuera sigue ocultando el teclado (medido en el iPhone 14). Pin: `PasteButtonTapWiringTests`; regla en
  `.claude/rules/swiftui-ds.md`.
- **AnnotateKit retirado de Yala Dev** (decisión de Jürgen): su píldora flotante tapaba los toques en el iPhone.

## Cómo quedan los guiones

- **C:** el editor está en **Más › Personalizar › Pestañas de abajo**, no en Ajustes.
- **B3:** con cuenta en la nube no existe «perder los cambios»; se prueba con red (cierre completo) y luego «Ya tengo
  cuenta». La opción de perder cambios es del modo iCloud privado.
- **A:** con la sesión ya abierta, el segundo enlace se abre en Yala Dev con
  `xcrun devicectl device process launch --payload-url <enlace> com.jurgenschmidt.yala.dev` (Device MCP pide
  aprobación para `open_url`).

## Hallazgos (cada uno con su ticket y card, versión 2.3)

- `cloud-activation-uploads-thousands-of-items-for-a-few-records`: 3333 elementos para 2 registros.
- `icloud-restore-preview-counts-categories-twice`: 124 y 62 categorías en dos pantallas seguidas.
- `groups-intro-sheet-comes-back-after-closing-it`: la hoja de bienvenida de Grupos vuelve tras la X.
- `invite-join-button-covers-paste-with-a-long-link`: «Unirme al grupo» tapa «Pegar» con teclado y enlace largo.

## Lo que aprendimos del montaje

- Device MCP (gratis, 0.5.0) conduce y graba el iPhone real, pero su teclado escribe como inglés: con un teclado español
  los símbolos salen cambiados. El texto con símbolos lo pega o escribe Jürgen.
- Lo de Google, Face ID, contraseñas y ajustes del sistema (iCloud Drive, modo avión) lo hace Jürgen.
