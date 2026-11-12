#!/usr/bin/env bash
# Lanza Yala (Debug) en el simulador del molde, en el idioma de la ficha, con el reloj en idiomas.json:reloj,
# tema oscuro, Pro y la semilla `ficha` en la divisa del idioma. Espera a que la app termine de sembrar.
#   capturas/lanzar.sh <idioma> <iphone|ipad> [--sin-semilla] [args extra para la app…]
#   --sin-semilla: relanza conservando los datos (sin -uitest-reset ni -uitest-seed: sembrar otra vez duplicaría todo).
# La app tiene que estar instalada (la compila Frank: scheme Yala, Debug).
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
APARATO="${2:?Falta iphone o ipad}"; shift 2
U="$(udid "$APARATO")"
SEMILLA=(-uitest-reset -uitest-seed ficha)
# YALA_FICHA_MARKETING=1: material público de lanzamiento, con los grupos de casa en vez de los viajes y sin nombres
# propios (`-uitest-seed-marketing`, ver DevSeedGroups.FichaCasa). Solo cuenta al sembrar.
[ "${YALA_FICHA_MARKETING:-}" = 1 ] && SEMILLA+=(-uitest-seed-marketing)
if [ "${1:-}" = "--sin-semilla" ]; then SEMILLA=(); shift; fi
# El Panel de usuario nuevo (`PanelDefaults`: Tendencias, Planificación y Últimos registros), fijado por el dominio de
# argumentos. Medido el 16-oct-2026: al relanzar sin -uitest-reset, la migración del Panel a veces encuentra la
# configuración vieja de widgets que dejó el arranque anterior y lo enseña TODO (3 de 5 relanzamientos en inglés); con
# estos argumentos, 3 de 3 curados. Si cambian los predeterminados del Panel, cambian aquí.
PANEL_NUEVO=(-panelPrefsMigratedV2 YES -panelSectionsHidden "health,distribucion,tools"
  -panelTendenciasOrder "tendencia_saldo,gasto_por_dia,flujo_efectivo" -panelTendenciasHidden "gasto_por_dia,flujo_efectivo"
  -panelDistribucionOrder "categorias_torta,subcategorias_torta,gastos_por_naturaleza,categorias_principales,subcategorias_principales,distribucion_por_etiquetas"
  -panelDistribucionHidden "categorias_principales,subcategorias_principales,distribucion_por_etiquetas"
  -panelPlanificacionOrder "pagos_planificados,presupuestos")
# El carrusel de «Tus finanzas» empieza por efectivo y tarjeta: son los chips de la 08 («Cash», «Card»), y en el iPhone
# solo se ve una tarjeta entera y asoma la siguiente. Sin orden guardado iría por nombre («Cartão» antes que «Dinheiro»).
ORDEN_CUENTAS="$CUENTA_EFECTIVO|$CUENTA_TARJETA|$CUENTA_PRINCIPAL|$CUENTA_EXTRANJERA"
RELOJ_DYLIB="$("$MOLDE/reloj/compilar.sh")"
DESFASE=$(( $(date -j -f "%Y-%m-%d %H:%M:%S" "$RELOJ" +%s) - $(date +%s) ))
xcrun simctl ui "$U" appearance dark
barra "$U"
xcrun simctl terminate "$U" "$BUNDLE" 2>/dev/null || true
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$RELOJ_DYLIB" SIMCTL_CHILD_YALA_RELOJ_DESFASE="$DESFASE" \
xcrun simctl launch "$U" "$BUNDLE" -uitest ${SEMILLA[@]+"${SEMILLA[@]}"} -uitest-skip-onboarding -uitest-pro -uitest-ai-consent \
  -userTheme 2 -defaultCurrencyCode "$MONEDA" -AppleLanguages "$APPLE_LANGUAGES" -AppleLocale "$APPLE_LOCALE" \
  "${PANEL_NUEVO[@]}" -accountsSortOrderNames "$ORDEN_CUENTAS" "$@" >/dev/null
# La semilla de dos años tarda: se espera a la señal de la app (`uitest_ready` en el árbol de accesibilidad).
for _ in $(seq 1 90); do
  # Sin `grep -q`: con `pipefail`, cortar la tubería al primer acierto mata a `axe` por SIGPIPE y la condición da falso
  # aunque la app esté lista. Pasa con árboles de más de 64 KB (el iPhone Duo, 2026-10-24); el iPhone cabía en el búfer.
  if axe describe-ui --udid "$U" 2>/dev/null | grep '"uitest_ready"' >/dev/null; then echo "✓ $IDIOMA · $APARATO listo"; exit 0; fi
  sleep 2
done
echo "✗ la app no llegó a uitest_ready en 180 s" >&2; exit 1
