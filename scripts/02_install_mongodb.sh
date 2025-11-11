#!/bin/bash
# ========================================
# Script 02 - Instalación de MongoDB en db1, db2 y db3
# ========================================

set -e
for c in db1 db2 db3; do
  echo "==> Instalando MongoDB en $c ..."
  incus exec "$c" -- bash -lc '
    apt-get update && apt-get install -y curl gnupg lsb-release
    curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -sc)/mongodb-org/6.0 multiverse" \
      | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    apt-get update && apt-get install -y mongodb-org
    systemctl disable mongod
  '
done
