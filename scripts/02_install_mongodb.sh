#!/bin/bash
# ========================================
# Script 02 - Instalación de MongoDB 8.0 en db1, db2 y db3
# ========================================
# Instala MongoDB 8.0 Community Edition en los 3 nodos de base de datos
# y deshabilita el servicio por defecto (se usarán servicios systemd personalizados)
# ========================================

set -e

echo "==> Instalando MongoDB 8.0 en nodos de base de datos..."
echo ""

for c in db1 db2 db3; do
  echo "==> Instalando MongoDB en $c ..."
  incus exec "$c" -- bash -lc '
    # Actualizar sistema
    apt-get update && apt-get install -y curl gnupg lsb-release
    
    # Agregar clave GPG de MongoDB
    curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
      gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
    
    # Agregar repositorio de MongoDB 8.0
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -sc)/mongodb-org/8.0 multiverse" \
      | tee /etc/apt/sources.list.d/mongodb-org-8.0.list
    
    # Instalar MongoDB
    apt-get update && apt-get install -y mongodb-org
    
    # Deshabilitar servicio por defecto (usaremos servicios personalizados)
    systemctl disable mongod || true
    systemctl stop mongod || true
  '
  echo "    ✅ MongoDB 8.0 instalado en $c"
  echo ""
done

echo ""
echo "✅ MongoDB 8.0 instalado en todos los nodos"
echo "📝 Nota: El servicio mongod por defecto está deshabilitado."
echo "   Se configurarán servicios systemd personalizados en el siguiente script."
