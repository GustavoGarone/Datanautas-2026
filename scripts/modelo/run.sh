#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
action=${1:-verificar}
case "$action" in
  verificar)
    Rscript scripts/modelo/verificar.R "${@:2}"
    Rscript scripts/modelo/relatar.R
    ;;
  testar)
    Rscript scripts/modelo/testar_implementacao.R
    ;;
  worm)
    Rscript scripts/modelo/worm.R
    Rscript scripts/modelo/verificar.R
    Rscript scripts/modelo/relatar.R
    ;;
  reproduzir|reajustar|graficos)
    if [[ "$action" != graficos ]]; then
      Rscript scripts/modelo/preparar.R
      fit_options=()
      if [[ "$action" == reajustar ]]; then fit_options=(--do-zero); fi
      Rscript scripts/modelo/ajustar.R completo "${fit_options[@]}"
      Rscript scripts/modelo/ajustar.R treino "${fit_options[@]}"
    fi
    Rscript scripts/modelo/diagnosticar.R
    Rscript scripts/modelo/validar.R
    Rscript scripts/modelo/complementar.R
    Rscript scripts/modelo/worm.R
    Rscript scripts/modelo/verificar.R
    Rscript scripts/modelo/relatar.R
    ;;
  *)
    echo "Uso: $0 [verificar [--likelihood]|testar|worm|graficos|reproduzir|reajustar]" >&2
    exit 2
    ;;
esac
