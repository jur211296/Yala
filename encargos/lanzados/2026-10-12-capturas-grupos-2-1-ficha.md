# Capturas de Grupos 2.1 para la ficha (iPhone 1206x2622 e iPad 13" 2064x2752)

Pedido de Lola, 2026-10-12. Effort medium. Cierre: entregar las capturas a Lola (sin PR salvo que toques código o hooks de UITest).

## Contexto
Lola prepara la ficha de 2.1 en App Store Connect (solo es-MX). Necesita capturas de la pantalla de Grupos de 2.1 con datos de ejemplo realistas. En ASC el hueco 4 de las capturas de iPad parece vacío.

## Qué se pide
1. Desde origin/2.1, build del scheme `Yala Dev` en simulador y captura de la pantalla principal de Grupos 2.1 (y una de detalle de grupo con saldos si luce mejor) con datos realistas: nombres creíbles de México, montos en MXN, 3-5 miembros, varios gastos y saldos. Usa los hooks de UITest / datos semilla existentes (busca `-uitest-*` y fixtures de Grupos); no uses cuentas reales ni toques staging/producción.
2. Tamaños exactos, sin marco, PNG: iPhone 1206x2622 (iPhone 17 Pro) e iPad 13" 2064x2752 (iPad Pro 13-inch M5), modo claro, es-MX, barra de estado limpia (`xcrun simctl status_bar override`: 9:41, batería y señal llenas). Verifica con `sips -g pixelWidth -g pixelHeight`.
3. Guarda en `~/Claude/capturas-ficha/2.1/` (créala): `grupos-iphone-1206x2622.png`, `grupos-ipad-2064x2752.png` (y `-detalle` si haces la segunda).
4. Hueco 4 de iPad en ASC: con la ASC CLI (credenciales ya en la Mini; SOLO lectura) lista las capturas de iPad 13" es-MX de la versión actual/2.1 y di qué hay en el hueco 4 (archivo, estado, vacío o error de procesamiento). NO subas ni borres nada en ASC; eso lo hace Lola.

## Qué NO tocar
App Store Connect (solo leer), textos de la ficha, Vercel, datos reales. Sin deploy.

## Reglas de build y Mini
NO correr entre 9:00 y 11:00 Lima (franja de Lola). `nice -n 10 xcodebuild -jobs 2`, carga < 8. Primero iPhone, apagarlo, luego iPad.

## Gate tras el CI del PR anterior
Arranca cuando cierre la sesión fixes-migracion-y-aviso-dispositivo (l36m+gwfi).

## PR a 2.1
Solo si tocas código o hooks de UITest para sembrar datos: `git fetch origin && git rebase origin/2.1` y PR a 2.1.

## Cómo se sabe
Capturas en `~/Claude/capturas-ficha/2.1/` con tamaños exactos, sin marco, datos realistas; el cierre dice qué había en el hueco 4 de iPad en ASC.

## SIMULADORES iOS EN LA MINI (regla nueva, 2026-10-12)
Nunca más de un simulador encendido a la vez, y al terminar (y antes de cerrar) ejecuta `xcrun simctl shutdown all`. La Mini se cayó por memoria el 2026-10-12 ~13:30.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Datos de México: perfil de semilla nuevo `ficha-mx`, no editar el de Grupos.** La semilla `grupos` es peruana (PEN, Cusco/Lima) y la usan los XCUITest; cambiarla movería sus aserciones. El perfil nuevo siembra tres grupos en MXN (Viaje a Oaxaca ×4, Depa Roma Norte ×3, Carne asada del sábado ×5) y ninguna vida personal. ⇒ toca código: rama + PR a 2.1.
2. **Modo claro con el tema de la app, no solo con el simulador.** Yala tiene tema propio (por defecto Liquid Glass, oscuro); se arranca con `-userTheme 1` (Claro) en el dominio de argumentos, sin tocar código. Divisa con `-defaultCurrencyCode MXN`, idioma `-AppleLanguages (es-MX) -AppleLocale es_MX`.
3. **Detalle: pestaña Balances en iPhone; en iPad la vista dividida ya trae el detalle, así que la principal es lista + gastos de Oaxaca y la «detalle» es lista + balances.**
4. **PNG sin canal alfa** (ASC rechaza alfa); se aplanan sobre blanco.
5. **Hueco 4 de iPad:** no existe versión 2.1 en ASC; se lee la versión vigente (2.0.4, es-MX). Solo lectura.
6. **Bug de iPad encontrado (detalle de grupo desfasado al cambiar de grupo):** no se arregla aquí (fuera del encargo); ticket en `tickets/backlog/`.
