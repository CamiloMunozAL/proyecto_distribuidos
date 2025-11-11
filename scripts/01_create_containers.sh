#!/bin/bash
# ========================================
# Script 01 - Creación de contenedores base
# ========================================
# Crea 6 contenedores:
# - db1, db2, db3: Nodos de base de datos MongoDB
# - auth: Servidor de autenticación JWT
# - web: Dashboard web y API de productos
# - incus-ui: Interfaz de gestión de contenedores
# ========================================

set -e
img="images:ubuntu/22.04"
containers=(db1 db2 db3 auth web incus-ui)

echo "==> Creando contenedores del sistema distribuido..."
echo ""

for c in "${containers[@]}"; do
  echo "==> Creando contenedor $c ..."
  if incus list | grep -q "$c"; then
    echo "    ⚠️  Contenedor $c ya existe, omitiendo..."
  else
    incus launch "$img" "$c" --profile default --profile dist-net
    echo "    ✅ Contenedor $c creado"
  fi
done

echo ""
echo "==> Esperando a que los contenedores inicien (10 segundos)..."
sleep 10

echo ""
echo "==> Contenedores creados:"
incus list

echo ""
echo "✅ Infraestructura de contenedores lista"
