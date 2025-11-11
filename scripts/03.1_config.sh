#!/bin/bash
# ========================================
# Script 03.1 - Corrección de permisos y reinicio de servicios
# ========================================
# Este script corrige permisos en los directorios de datos de MongoDB
# y reinicia los servicios si es necesario.
# Útil si los servicios no iniciaron correctamente en el script 03.
# ========================================

set -e

echo "==> Corrigiendo permisos y reiniciando servicios MongoDB..."
echo ""

for c in db1 db2 db3; do
  echo "==> Procesando contenedor $c..."
  incus exec $c -- bash -lc '
    # Crear directorios si no existen
    mkdir -p /data/db-27017 /data/db-27018 /data/db-27019
    
    # Corregir propietario y permisos
    chown -R mongodb:mongodb /data
    chmod -R 755 /data
    
    # Recargar configuración de systemd
    systemctl daemon-reload
    
    # Reiniciar servicios
    systemctl restart mongod-27017 || true
    systemctl restart mongod-27018 || true
    systemctl restart mongod-27019 || true
    
    # Mostrar estado
    echo "    Servicios en '$c':"
    systemctl is-active mongod-27017 && echo "      ✅ mongod-27017 activo" || echo "      ❌ mongod-27017 inactivo"
    systemctl is-active mongod-27018 && echo "      ✅ mongod-27018 activo" || echo "      ❌ mongod-27018 inactivo"
    systemctl is-active mongod-27019 && echo "      ✅ mongod-27019 activo" || echo "      ❌ mongod-27019 inactivo"
  ' 2>/dev/null
  echo ""
done

echo "✅ Permisos corregidos y servicios reiniciados"
