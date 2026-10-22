# Piloto XCUITest DemoIAPizza + simctl recordVideo/screenshot → Remotion

Card 805a2473-3830-4c83-9daf-48428b999fa1 (Yala/marketing). Effort high.

## AUTONOMÍA Y REGLAS (léelo primero)
- Jürgen y Lola están dormidos. **Nunca uses AskUserQuestion y nunca esperes respuesta**: decide tú, apunta cada decisión en el README/cierre y cierra con `/cerrar-total`.
- Destino: marketing de Yala (carril de Lola). Si hay trabajo visual, lee primero `~/Claude/referencias-ui/README.md` (inspiración de patrones, nunca copiar).
- **No publiques ni subas nada**: ni a App Store Connect ni a redes sociales (IG, X, TikTok…). Todo queda como borrador en disco.
- Simuladores: uno como máximo; al terminar (y antes de cerrar) `xcrun simctl shutdown all`; nunca entre 9:00 y 11:00 Lima. `nice -n 10 xcodebuild -jobs 2`, carga < 8.
- PR contra 2.1 **solo si cambian archivos del repo**: `git fetch origin && git rebase origin/2.1` antes de abrirlo. Si no cambia nada del repo, sin PR.
- Copy siempre fiel a la app y a la política 2.1 (PR #469): «más de 50 divisas», Grupos en la nube (no iCloud), exportación gratis de todos los períodos, sin Modo Nube ni conector de Claude en lo público, nada de «no almacenamos nada en servidores».

## Contexto (de la card)
Piloto de captura automática en el simulador (XCUITest + `xcrun simctl io <dev> recordVideo` / `screenshot`) para sacar H.264 usable en Remotion. Es el carril de piezas de marketing de Yala. Compara además con Recordly y RemoCN (pendientes sin card).

## Qué se pide
1. Un XCUITest `DemoIAPizza` (o el nombre que encaje en `YalaUITests/`) que, con una semilla de datos realistas (reutiliza `ficha-mx-vida` si sirve), recorra la demo «registrar una pizza con Yala IA» de principio a fin, con pausas pensadas para vídeo. Si la IA necesita red, usa el modo/hook de demo o stub que exista; no llames a producción.
2. Script reproducible (`qa/scripts/` o `marketing/`) que arranque el simulador (uno solo), fije la barra de estado, grabe con `simctl io recordVideo --codec h264` mientras corre el test, y saque capturas clave.
3. Comprueba que el H.264 entra en Remotion (render de prueba corto si Remotion está en el repo o instalable sin login).
4. Nota: qué sirve frente a Recordly y RemoCN (prueba rápida si son instalables sin login; si no, documéntalo).

## Salida
Clip y capturas en `~/Claude/propuestas/demo-ia-pizza-2026-10-13/` con `README.md` (cómo reproducir, nota comparativa). El test y el script van al repo ⇒ PR a 2.1.

## Cómo se sabe
Pipeline reproducible DemoIAPizza → captura → clip listo para Remotion, con nota comparativa; PR a 2.1 con test y script; simuladores apagados.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

| Decisión | Tomada | Por qué |
|---|---|---|
| Quién escribe el XCUITest y el hook | **Frank** (subagente), en este mismo worktree | `YalaUITests/` y `Yala/` son de Frank; Lola solo toca `marketing/`. Compilar también es suyo |
| Cómo contesta Yala IA sin red | Hook DEBUG nuevo `-uitest-chat-reply pizza`: el chat responde a lo que se escribe con un borrador de Pizza · 280 · Restaurantes, por la misma UI que un borrador real | En simulador Yala IA no contesta (sin App Attest); `-uitest-chat-draft` abre con taxi + súper ya puestos y no deja ver escribir. No se llama a producción |
| Semilla | `ficha-mx-vida` (MXN, es-MX) | La pide el encargo y casa con las capturas de la ficha 2.1 |
| Apariencia | Modo oscuro, barra de estado 9:41 | El pack 2.1 de Remotion es Liquid Glass oscuro; la toma piloto era clara y era deuda (OPERACION.md) |
| Simulador | iPhone 17 Pro, iOS 27.0 (el único disponible) | Uno como máximo |
| Dónde va el script | `marketing/remotion/scripts/grabar-demo-sim.sh` | Territorio de Lola, al lado de los `render-*.sh` que consumen el clip |
| Marcas de montaje | El test imprime `DEMO-MARCA:<id>` en cada beat; el script apunta su segundo y saca la captura en ese momento | Da `fromSec` medidos para `copy.ts` en vez de estimados |
| Clip | `demo.mp4` H.264 60 fps CFR recortado de «inicio» a «fin» | simctl graba a frecuencia variable; Remotion cuenta frames |
| Prueba en Remotion | Render corto en una copia de `marketing/remotion` en el scratchpad, con una pieza de prueba | Demuestra que el H.264 entra sin tocar el guion de `copy.ts`: escribir los beats de la pieza nueva es otro encargo |
| Clip en el repo | No se commitea | Va a `~/Claude/propuestas/`; entra en `public/footage/` cuando haya pieza |
| Recordly / Remocn | Investigación sin instalar en el sistema: Recordly es app GUI (dmg), Remocn se prueba en la copia del scratchpad | Recordly no tiene CLI: no entra en un pipeline automático |
