#!/bin/bash
# ========================================
# Script 01 - Creación de contenedores base
# ========================================

set -e
img="images:ubuntu/22.04"
containers=(db1 db2 db3 auth web incus-ui)

for c in "${containers[@]}"; do
  echo "==> Creando contenedor $c ..."
  incus launch "$img" "$c" --profile default --profile dist-net || true
done

echo "==> Contenedores creados:"
incus list
