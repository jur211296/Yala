#!/bin/bash
# Instala los git hooks de QA (versionados en qa/hooks/) en .git/hooks/.
# Usa symlink para que futuras actualizaciones del hook se reflejen sin reinstalar.
# Correr una vez por clon del repo: bash qa/hooks/install.sh
set -e
ROOT="$(git rev-parse --show-toplevel)"
chmod +x "$ROOT/qa/hooks/pre-push"
ln -sf "../../qa/hooks/pre-push" "$ROOT/.git/hooks/pre-push"
echo "✓ Hook pre-push instalado (symlink .git/hooks/pre-push → qa/hooks/pre-push)."
echo "  Valida qa/coverage-index.json en cada push y bloquea si el ratchet regresa."
