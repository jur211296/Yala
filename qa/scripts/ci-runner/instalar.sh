#!/bin/bash
# Monta el runner propio de GitHub Actions en la Mini, en el usuario de macOS `ci`
# (fase 4 del plan `~/Claude/casa/docs/ci-propio-yala.md`, ADR-053 de casa).
#
# Lo corre JÜRGEN en su Terminal, como su usuario y SIN sudo delante:
#
#     bash qa/scripts/ci-runner/instalar.sh              # instala o repara
#     bash qa/scripts/ci-runner/instalar.sh --desinstalar
#
# El script pide la contraseña de administrador UNA vez (la de `sudo`) y hace el resto.
#
# ## Qué hace, en orden
#
# 1. Como Jürgen: genera una contraseña aleatoria para `ci` y la guarda en SU llavero
#    (servicio `yala-ci-usuario-macos`), en el mismo gesto — nunca vive solo en pantalla.
#    Pide a GitHub el token de registro con `gh`. **Ninguno de los dos se imprime.** Si
#    `gh` no puede, lo pide con `read -s` (no hace eco) y dice dónde generarlo.
# 2. Como root: crea `ci` (usuario ESTÁNDAR, oculto en la pantalla de login), lo mete en
#    `_developer` para que `xcodebuild test` no pida autorización de depurador, y activa
#    `DevToolsSecurity` por la misma razón.
# 3. Descarga el runner con su SHA-256 verificado y lo registra con la etiqueta `yala-mini`.
# 4. Lo instala como LaunchDaemon con `UserName=ci`: arranca solo tras un reinicio sin que
#    nadie inicie sesión como `ci`, y los simuladores corren sin primer plano.
#
# ## Dónde queda cada cosa
#
# Todo en el disco INTERNO, en el home de `ci`:
#
# | Qué | Dónde |
# |---|---|
# | Runner (binarios, credenciales) | `/Users/ci/actions-runner` |
# | Checkout de cada job | `/Users/ci/_work` |
# | DerivedData persistente (sobrevive al `git clean` del checkout) | `/Users/ci/DerivedData` |
# | Simuladores de `ci`: juego PROPIO, no toca los de Jürgen | `/Users/ci/Library/Developer/CoreSimulator` |
#
# **No en ExtDev, medido el 2026-09-30:** macOS (TCC) no deja a un LaunchDaemon entrar en un
# volumen externo — `Operation not permitted` al listar `/Volumes/ExtDev/ci/_work`, aunque el
# `-d` pase. Abrirlo pide Acceso total al disco para el binario del runner, que se
# auto-actualiza y perdería el permiso. Coste: ~12 GB del interno (checkout, ~3 GB de
# DerivedData y ~7 GB de un simulador). Vigílalo con `qa/scripts/disk-report.sh`.

set -euo pipefail

REPO="jur211296/Yala"
RUNNER_VER="2.337.0"
RUNNER_SHA="5a2cd92908a93d7276a194e1de6008099f3e7946f3f8e14aa7a1a7b4a31fdec2"
RUNNER_NAME="mini-ci"
RUNNER_LABELS="yala-mini"
CI_USER="ci"
CI_HOME="/Users/ci"
RUNNER_DIR="$CI_HOME/actions-runner"
WORK="$CI_HOME/_work"
DDATA="$CI_HOME/DerivedData"
PLIST="/Library/LaunchDaemons/com.yala.ci-runner.plist"
LABEL="com.yala.ci-runner"
LLAVERO_SERVICIO="yala-ci-usuario-macos"

paso() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
falla() { printf '\n\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- fase root
if [[ "${1:-}" == "--como-root" ]]; then
  [[ $EUID -eq 0 ]] || falla "la fase root tiene que correr con sudo"
  cd /   # el cwd de Jürgen no lo puede leer `ci`, y `sudo -u ci` se queja
  MODO="${2:-instalar}"

  if [[ "$MODO" == "desinstalar" ]]; then
    paso "Parando el servicio"
    launchctl bootout system "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    if [[ -x "$RUNNER_DIR/config.sh" && -n "${YALA_CI_REMOVE_TOKEN:-}" ]]; then
      paso "Dando de baja el runner en GitHub"
      ACTIONS_RUNNER_INPUT_TOKEN="$YALA_CI_REMOVE_TOKEN" \
        sudo -u "$CI_USER" -H --preserve-env=ACTIONS_RUNNER_INPUT_TOKEN \
        bash -c "cd '$RUNNER_DIR' && ./config.sh remove" || true
    fi
    rm -rf "$RUNNER_DIR"
    echo
    echo "Hecho. El usuario '$CI_USER' sigue ahí. Para borrarlo con su home:"
    echo "    sudo sysadminctl -deleteUser $CI_USER"
    exit 0
  fi

  [[ -n "${YALA_CI_TOKEN:-}" ]] || falla "falta el token de registro"

  if dscl . -read "/Users/$CI_USER" >/dev/null 2>&1; then
    paso "El usuario '$CI_USER' ya existe: no se toca su contraseña"
  else
    [[ -n "${YALA_CI_PW:-}" ]] || falla "falta la contraseña del usuario nuevo"
    paso "Creando el usuario estándar '$CI_USER'"
    sysadminctl -addUser "$CI_USER" -fullName "CI Yala" -password "$YALA_CI_PW" -home "$CI_HOME"
    createhomedir -c -u "$CI_USER" >/dev/null
  fi
  dscl . -create "/Users/$CI_USER" IsHidden 1

  paso "Permisos de desarrollo (_developer + DevToolsSecurity)"
  dseditgroup -o edit -a "$CI_USER" -t user _developer
  DevToolsSecurity -enable

  paso "Directorios de trabajo"
  sudo -u "$CI_USER" mkdir -p "$WORK" "$DDATA"

  paso "Descargando el runner v$RUNNER_VER"
  launchctl bootout system "$PLIST" 2>/dev/null || true
  # Desde cero: con un `.runner` viejo, `config.sh` se niega a reconfigurar. El registro en
  # GitHub lo sustituye `--replace` por nombre.
  rm -rf "$RUNNER_DIR"
  sudo -u "$CI_USER" mkdir -p "$RUNNER_DIR"
  TMPD="$(mktemp -d /tmp/yala-ci-runner.XXXXXX)"
  TGZ="$TMPD/runner.tar.gz"
  curl -fsSL -o "$TGZ" \
    "https://github.com/actions/runner/releases/download/v$RUNNER_VER/actions-runner-osx-arm64-$RUNNER_VER.tar.gz"
  echo "$RUNNER_SHA  $TGZ" | shasum -a 256 -c - >/dev/null || falla "el SHA-256 del runner no coincide"
  chmod 755 "$TMPD"; chmod 644 "$TGZ"
  sudo -u "$CI_USER" tar xzf "$TGZ" -C "$RUNNER_DIR"
  rm -rf "$TMPD"

  paso "Registrando el runner '$RUNNER_NAME' (etiqueta $RUNNER_LABELS)"
  # El token va por el ENTORNO, no por argumentos: así no aparece en `ps`. El runner lee
  # cualquier `--opción` de la variable `ACTIONS_RUNNER_INPUT_<OPCIÓN>`.
  ACTIONS_RUNNER_INPUT_TOKEN="$YALA_CI_TOKEN" \
    sudo -u "$CI_USER" -H --preserve-env=ACTIONS_RUNNER_INPUT_TOKEN \
    bash -c "cd '$RUNNER_DIR' && ./config.sh --unattended --replace \
      --url 'https://github.com/$REPO' --name '$RUNNER_NAME' \
      --labels '$RUNNER_LABELS' --work '$WORK'"

  paso "Arranque"
  cat > "$RUNNER_DIR/arranque.sh" <<EOF
#!/bin/bash
# Lo lanza launchd ($LABEL).
cd "$RUNNER_DIR"
exec ./run.sh
EOF
  chown "$CI_USER":staff "$RUNNER_DIR/arranque.sh"; chmod 755 "$RUNNER_DIR/arranque.sh"

  paso "LaunchDaemon $PLIST"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>UserName</key><string>$CI_USER</string>
  <key>GroupName</key><string>staff</string>
  <key>SessionCreate</key><true/>
  <key>ProgramArguments</key><array><string>$RUNNER_DIR/arranque.sh</string></array>
  <key>WorkingDirectory</key><string>$RUNNER_DIR</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Interactive</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>$CI_HOME</string>
    <key>USER</key><string>$CI_USER</string>
    <key>LANG</key><string>en_US.UTF-8</string>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>DEVELOPER_DIR</key><string>/Applications/Xcode.app/Contents/Developer</string>
  </dict>
  <key>StandardOutPath</key><string>$RUNNER_DIR/launchd.log</string>
  <key>StandardErrorPath</key><string>$RUNNER_DIR/launchd.log</string>
</dict>
</plist>
EOF
  chown root:wheel "$PLIST"; chmod 644 "$PLIST"
  launchctl bootstrap system "$PLIST"
  sleep 5
  launchctl print "system/$LABEL" | grep -E '^\s*(state|pid) ' || true
  echo
  echo "Listo. En 1 min el runner '$RUNNER_NAME' debería salir 'Idle' en"
  echo "  https://github.com/$REPO/settings/actions/runners"
  exit 0
fi

# ---------------------------------------------------------------- fase usuario
[[ $EUID -ne 0 ]] || falla "córrelo SIN sudo delante: el script lo pide él cuando toca"
command -v gh >/dev/null || falla "falta gh"

if [[ "${1:-}" == "--desinstalar" ]]; then
  YALA_CI_REMOVE_TOKEN="$(gh api -X POST "repos/$REPO/actions/runners/remove-token" --jq .token 2>/dev/null || true)"
  export YALA_CI_REMOVE_TOKEN
  echo "Te va a pedir la contraseña de administrador (la de sudo)."
  exec sudo --preserve-env=YALA_CI_REMOVE_TOKEN bash "$0" --como-root desinstalar
fi

YALA_CI_PW=""
if ! dscl . -read "/Users/$CI_USER" >/dev/null 2>&1; then
  paso "Contraseña del usuario '$CI_USER' → tu llavero (servicio $LLAVERO_SERVICIO)"
  YALA_CI_PW="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
  security add-generic-password -U -a "$CI_USER" -s "$LLAVERO_SERVICIO" \
    -l "Usuario macOS ci (runner de Yala)" -w "$YALA_CI_PW"
  echo "Guardada. Para verla: security find-generic-password -s $LLAVERO_SERVICIO -w"
fi
export YALA_CI_PW

paso "Token de registro del runner"
YALA_CI_TOKEN="$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token 2>/dev/null || true)"
if [[ -z "$YALA_CI_TOKEN" ]]; then
  echo "gh no pudo pedirlo. Genéralo tú en:"
  echo "  https://github.com/$REPO/settings/actions/runners/new?arch=arm64&os=osx"
  echo "Copia SOLO el valor que va detrás de '--token' (caduca en 1 h)."
  read -rs -p "Pégalo aquí (no se verá): " YALA_CI_TOKEN; echo
  [[ -n "$YALA_CI_TOKEN" ]] || falla "token vacío"
else
  echo "Obtenido con gh (no se imprime)."
fi
export YALA_CI_TOKEN

echo
echo "Ahora te va a pedir la contraseña de administrador (la de sudo)."
exec sudo --preserve-env=YALA_CI_TOKEN,YALA_CI_PW bash "$0" --como-root instalar
