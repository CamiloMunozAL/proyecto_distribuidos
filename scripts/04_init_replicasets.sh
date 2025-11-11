#!/bin/bash
# ========================================
# Script 04 - Inicialización de Replica Sets MongoDB
# ========================================

set -e

echo "==> Iniciando rs_products_a..."
incus exec db1 -- mongosh --port 27017 --eval '
rs.initiate({
  _id: "rs_products_a",
  members: [
    { _id: 0, host: "db1:27017", priority: 2 },
    { _id: 1, host: "db2:27018", priority: 1 }
  ]
});
'

echo "==> Iniciando rs_products_b..."
incus exec db2 -- mongosh --port 27017 --eval '
rs.initiate({
  _id: "rs_products_b",
  members: [
    { _id: 0, host: "db2:27017", priority: 2 },
    { _id: 1, host: "db1:27018", priority: 1 }
  ]
});
'

echo "==> Iniciando rs_users..."
incus exec db3 -- mongosh --port 27017 --eval '
rs.initiate({
  _id: "rs_users",
  members: [{ _id: 0, host: "db3:27017", priority: 1 }]
});
'
