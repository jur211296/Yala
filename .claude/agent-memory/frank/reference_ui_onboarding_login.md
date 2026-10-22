---
name: reference-ui-onboarding-login
description: Referencia de UI que Jürgen señaló el 2026-09-15 para el onboarding de Yala — pantalla de entrada con Google, correo y «explorar sin cuenta»; captura en docs/design/referencias, con los rasgos que la hacen buena
metadata:
  type: reference
---

Jürgen mandó el 2026-09-15 una pantalla de entrada de otra app («¡Hola de nuevo!») como «vista
para onboarding de referencia». La captura está en
`docs/design/referencias/2026-09-15-onboarding-login-referencia.jpg`.

**Lo que tiene y por qué funciona:**
1. **Un titular en serif grande y cálido** («¡Hola de nuevo!») y una línea gris que dice las dos
   formas de entrar. Nada de logo ni ilustración: el texto es la bienvenida.
2. **Todo el formulario vive dentro de una sola tarjeta** con borde fino, sin sombra: campos,
   botón, separador «o», Google y «explorar sin cuenta». Fuera de la tarjeta solo queda la
   pregunta de pie.
3. **Etiqueta encima del campo, no placeholder como etiqueta**, y el enlace secundario
   («Olvidé mi contraseña») alineado a la derecha en la misma línea que la etiqueta.
4. **Tres pesos de botón, uno por importancia**: gris relleno para «Entrar» (queda pasivo hasta
   que hay datos), negro lleno para el camino recomendado, «Entrar con Google», y contorno para
   «Explorar sin cuenta». La jerarquía se lee sin leer.
5. **La salida sin cuenta existe y está a la vista**, dentro de la tarjeta, no escondida en un
   enlace. Es la misma idea que el «I got stuck» de [[reference-ui-flujo-por-pasos]].
6. **Voseo** en el copy («Entrá», «tenés»): la app habla al usuario de su región. En Yala manda
   el registro que ya esté decidido, no este.
7. **Botón «Volver» como píldora arriba a la izquierda**, con icono y palabra, no solo chevron.

**Dónde encaja en Yala:** el flujo de bienvenida de `Yala/App/Views/Onboarding/` —
`WelcomeChooserView`, `WelcomeNewChooserView`, `WelcomeExistingChooserView` y sobre todo
`WelcomeCloudSignInView` (1 150+ líneas), que es donde hoy se elige Restaurar iCloud o Sign in
with Apple. Yala no tiene correo ni Google: la referencia es de **jerarquía y contenedor**, no
de proveedores. El «explorar sin cuenta» equivale al modo local sin iCloud.

**How to apply:** cuando se toque la bienvenida, abrir la captura antes de maquetar y contrastar
contra los siete rasgos; proponer con maqueta, porque es identidad
([[feedback-tarjetas-blancas-identidad]]). Sigue mandando
[[feedback-cuando-la-app-pregunta-al-usuario]] para qué se pregunta y qué se informa.
