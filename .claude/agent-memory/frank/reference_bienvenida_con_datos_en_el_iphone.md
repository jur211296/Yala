---
name: reference-bienvenida-con-datos-en-el-iphone
description: Cómo llevar el iPhone 14 a la bienvenida con el iCloud privado bajado y el espejo montado, sin borrar nada; y el argumento que da un falso bloqueo
metadata:
  type: reference
---

Para probar en el iPhone 14 algo de la bienvenida con los datos del iCloud privado en el teléfono (p. ej. «Ya tengo cuenta › Entrar con Google»), basta lanzar Yala Dev con `-hasCompletedOnboarding NO`: aterriza en el chooser con el espejo montado y los datos intactos. Medido el 2026-11-10.

**No añadas `-hasShownWelcomeChooser NO`.** Si el teléfono arrastra `cloudSync.neutralMountArmed = true` de un cierre antiguo, ese argumento hace que el arranque monte NEUTRO (sin espejo) sobre el archivo con datos: el canal de copia sale `.none` y cualquier decisión que dependa de «hay copia en iCloud» da un falso negativo. Costó una vuelta entera de diagnóstico en el QA de la opción B.

Para comprobar que iCloud sigue intacto tras un experimento: desinstalar con `devicectl device uninstall app`, reinstalar y «Restaurar desde iCloud»: la pantalla «¡Hola Jur!» cuenta lo que hay en la zona sin bajar nada. Con «Traer mis datos» el teléfono vuelve a como estaba. Relacionado: [[feedback-qa-fisico-datos-dev-no-preguntes]].
