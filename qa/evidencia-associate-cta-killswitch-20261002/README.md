# Evidencia · «Asociar una cuenta para grupos» con el canal de Grupos apagado

`canal-apagado-sin-boton.jpg` — iPhone 17 Pro, iOS 27.0, `Yala Dev`, seed `minimal` (sesión privada sin cuenta de
grupos). Capturada con un build LOCAL que forzaba `channelOn = false` en `GroupsAssociationSection`; ese cambio no
está en el commit. El canal apagado no se puede montar de otra forma en el simulador: bajo `-uitest` el flag nace ON.

Lo que se ve: la sección «Grupos» mantiene su texto y, en lugar del botón, la nota de pausa. No hay forma de abrir el
inicio de sesión desde aquí.
