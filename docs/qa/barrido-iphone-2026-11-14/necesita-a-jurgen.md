# Lo que necesita a Jürgen en persona — barrido del iPhone 14, parte 1 (14-nov-2026)

Cada fila dice la card, el paso que no se pudo dar sin ti y qué hace falta. Lo que sí se pudo ver
antes de ese paso está en `lista.md`.

## Una cuenta o una mano tuya en el teléfono

| Card | Paso que se para | Qué hace falta |
|---|---|---|
| Apple y Google con el mismo correo (`188b`) | «Entrar con Apple» › Iniciar sesión | Tu Face ID en el iPhone 14. Después, el guion B de la card: que «Ya tienes una cuenta» enseñe test@yala-app.pe y que «Vamos a crear tu cuenta» no diga «cuenta nueva». |
| Textos de entrada y salida (`luc1`) | Caso C: cuenta nueva con Google o Apple | Un Google sin cuenta de Yala que entre sin contraseña. jurgen@2b.pe y la de Zealit piden contraseña en el teléfono. |
| Bienvenida 2.3 · Acceso con Google o Apple (`11hi`) | «Vamos a crear tu cuenta» y los casos especiales | La misma cuenta de Google nueva. El caso «Ya tienes una cuenta» ya se vio y está bien. |
| Bienvenida 2.3 · Entrada por Grupos (`hmaf`) | Llegar a destino por cada uno de los tres caminos | Una cuenta nueva y un enlace de invitación de otra cuenta. Los tres caminos ya salen en «¿Cómo empiezas?». |
| Bienvenida 2.3 · Paso 5: Grupos (`yuyn`) | Crear el primer grupo o unirse desde el tutorial | Una cuenta de Yala nueva, o un enlace de otra cuenta. |
| Bienvenida 2.3 · Paso 2: voz, foto y Yala IA (`d1ab`) | Dictar y fotografiar un recibo con una cuenta Free | Tu voz y un recibo de verdad: es el guion de la card. |
| Bienvenida 2.3 · Final y prueba de Pro (`l1c5`) | La hoja de pago de la App Store | TestFlight con el tester de Sandbox del iPhone 14. Yala Dev instalada desde la Mac no carga precios. |
| En una sesión solo de grupos, «Dónde viven tus datos» (`6dz5`) | Entrar con una cuenta que solo tenga Grupos | Otra cuenta de solo Grupos. La única que había, admin@yala-app.pe, ya tiene parte personal: se la activé en esta sesión. |
| «Tengo una invitación» pide reabrir (`840a`) | Pegar un enlace de invitación | Un enlace de invitación de otra cuenta. |

## Algo que despliegas o decides tú

| Card | Qué falta |
|---|---|
| Registrar movimientos desde correos del banco (`3w7z`) | Activar el buzón y desplegar el gateway (RUNBOOK). |
| Bienvenida 2.3 · Correo automático (`i9d8`) | El mismo despliegue y el dominio, sin comprar. |
| Tu IA registra en Yala (`o9b0`) | Gateway y conector en staging (Dan); después, el guion con Claude o ChatGPT conectados a tu cuenta. |
| Telemetría propia en Cloudflare (`dyhx`) | Elegir en la propuesta y aprobar el panel publicado. |
| Yala IA: medio de pago en el chat (`v466`) | Mirar si te vale que Yala IA pregunte «¿Registrar o preguntar?» antes de cada borrador. El caso de dos gastos en un mensaje necesita el gateway en staging. |

# Parte 2 (14-nov-2026)

## Una cuenta, un dispositivo o una mano tuya en el teléfono

| Card | Paso que se para | Qué hace falta |
|---|---|---|
| Apple Pay en una sesión solo grupos (`qvaz`) | Entrar con una sesión de solo Grupos | La misma cuenta de solo Grupos que pide la parte 1 (admin@ ya tiene parte personal). |
| Activar la nube sube 3333 elementos (`i9wh`) | Dónde viven tus datos › Activar la nube | Un Google o Apple sin cuenta de Yala. Desde iCloud con los datos de prueba, cronometrar y mirar que «Subir tus datos» ronde los 480. |
| Activar la nube tarda minutos: medir el paso (`vfg1`) | La misma activación | La misma cuenta nueva; después, leer la serie de esa instalación en `yala_metrics_staging`. |
| El Pro pagado tarda en aparecer al entrar (`4afh`) | Entrar con la cuenta que tiene Pro pagado | Una cuenta de Yala con Pro pagado en staging. jur211296 es Free. |
| Entrar en la nube con otro Apple ID (`pboq`) | «Usar otra cuenta» › «Otra cuenta de Apple» | Un Apple ID que no sea el del teléfono, con su contraseña. |
| El idioma no llega a tus otros dispositivos (`p9wf`) | Cambiar el idioma en uno y mirarlo en el otro | Un segundo dispositivo con la misma cuenta en la nube. |
| «Volver a iCloud» en el segundo dispositivo (`7usr`) | Abrir Dónde viven tus datos en el segundo | Un segundo dispositivo de una cuenta nacida en la nube. |
| Aviso importante con Ajustes abierto (`ulks`) | Provocar el aviso | Cambiar de Apple ID en el teléfono o vaciar desde otro dispositivo. |
| Cerrar sesión con grupos e iCloud Drive apagado (`jzti`) | Apagar iCloud Drive | Tu mano en Ajustes del iPhone › tu nombre › iCloud › iCloud Drive. El guion de la card es tuyo. |
| Restaurar con iCloud Drive apagado (`6a12`) | Apagar iCloud Drive y reinstalar | Lo mismo; luego el guion del ticket. |
| Yala web: definir y maquetar (`ljz7`) | Entrar con Apple y con Google en staging | Tus cuentas en https://yala-web-staging.misty-surf-6866.workers.dev |

## Algo que despliegas, decides o das tú

| Card | Qué falta |
|---|---|
| Tokens por función de IA (`3z6j`) | El despliegue del gateway a producción (Dan) y leer el coste medio una semana después. |
| Goldens del gateway en paralelo (`j93f`) | Las credenciales de staging de los goldens (`USER_A_PASS`…, `GROUPS_ENC_KEY`) para correrlos y ver que vuelven a ~1/5 de su tope. La sonda ya pasa. |
| Mascota «Yalitto» (`56ze`) | Tus 7 decisiones de la sección 8 de `docs/ux/mascota-yalitto-2.3/`: no entró en la discusión del 9-nov. |

## Para mirar con tu ojo (pasaron; siguen en QA)

| Card | Qué mirar |
|---|---|
| Gastos hormiga (`ea78`) | ¿Las compras que nombra tienen sentido y el tope «compras de hasta S/ 52-68» es razonable? |
| Sugerencias de descripción (`y6du`) | ¿Son las que esperabas y en buen orden? |
| Logos de suscripción (`9nn7`) | ¿Se ve bien el logo en lista, línea de tiempo y calendario? ¿Echas de menos algún servicio? |

# Parte 3 (14-nov-2026)

## Un dispositivo, una cuenta o una mano tuya en el teléfono

| Card | Paso que se para | Qué hace falta |
|---|---|---|
| La señal de vaciado llega antes que la marca del parque (`r380`) | Vaciar datos en el iPhone 14 con otro dispositivo abierto | Un segundo dispositivo con el mismo iCloud y Yala Dev. Guion en la card: el otro se queda en la app con el aviso y el iPhone 14 conserva categorías y recordatorios. |
| Un iPad con versión anterior borra los recordatorios (`z07r`) | Vaciar datos frente a un dispositivo con la 2.1 | Un TestFlight de 2.3 y un dispositivo con la 2.1 del App Store. |
| Las esperas del arranque leen el token de iCloud Drive (`dtex`) | Apagar iCloud Drive | Tu mano en Ajustes del iPhone › tu nombre › iCloud › iCloud Drive; luego cerrar y abrir Yala 3 veces. |
| El conector sepa tu zona horaria (`lhca`) | Cambiar la zona del teléfono y preguntar a Claude | La nube en staging en el iPhone, la zona en Madrid y Claude conectado a `yala-staging`. |
| Conectar Yala en Claude con Apple o Google (`r8hi`) | Entrar en el permiso del conector | Tu Apple y tu Google desde Claude, contra el conector de staging. |

## Algo que decides o despliegas tú

| Card | Qué falta |
|---|---|
| La fila de chips de «Nuevo registro» (`deur`) | Tu decisión A/B/C/D para el iPhone SE. En el iPhone 14 y el 17 Pro «Etiquetas» se ve entera. |
| Endurecer el conector en producción (`pv2l`) | Elegir el dominio (workers.dev o mcp.yala-app.pe); después despliega Dan. |
| Mezcla con voz de los reels IG semana 3 (`vfsf`) | Escuchar los tres reels antes de publicar. Es de marketing (Lola): no lo probé. |
