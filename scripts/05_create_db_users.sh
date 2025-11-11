#!/bin/bash
# ========================================
# Script 05 - Creación de usuarios MongoDB
# ========================================
# Crea usuarios de aplicación para acceso a las bases de datos:
# - productos_db: Para almacenar productos (ambos shards)
# - auth_db: Para almacenar usuarios del sistema
# ========================================

set -e

echo "==> Creando usuarios de base de datos..."
echo ""

echo "==> [1/3] Creando usuario para productos_db en rs_products_a (db1:27017)..."
incus exec db1 -- mongosh --port 27017 --quiet --eval '
use admin;
try {
  db.createUser({
    user: "productos_user",
    pwd: "productos_pass",
    roles: [
      {role: "readWrite", db: "productos_db"},
      {role: "dbAdmin", db: "productos_db"}
    ]
  });
  print("✅ Usuario productos_user creado");
} catch(e) {
  print("⚠️  Usuario ya existe o error: " + e.message);
}
' 2>/dev/null

echo ""
echo "==> [2/3] Creando usuario para productos_db en rs_products_b (db2:27017)..."
incus exec db2 -- mongosh --port 27017 --quiet --eval '
use admin;
try {
  db.createUser({
    user: "productos_user",
    pwd: "productos_pass",
    roles: [
      {role: "readWrite", db: "productos_db"},
      {role: "dbAdmin", db: "productos_db"}
    ]
  });
  print("✅ Usuario productos_user creado");
} catch(e) {
  print("⚠️  Usuario ya existe o error: " + e.message);
}
' 2>/dev/null

echo ""
echo "==> [3/3] Creando usuario para auth_db en rs_users (db3:27017)..."
incus exec db3 -- mongosh --port 27017 --quiet --eval '
use admin;
try {
  db.createUser({
    user: "auth_user",
    pwd: "auth_pass",
    roles: [
      {role: "readWrite", db: "auth_db"},
      {role: "dbAdmin", db: "auth_db"}
    ]
  });
  print("✅ Usuario auth_user creado");
} catch(e) {
  print("⚠️  Usuario ya existe o error: " + e.message);
}
' 2>/dev/null

echo ""
echo "✅ Usuarios de base de datos creados"
echo ""
echo "📝 Credenciales creadas:"
echo "   • productos_db: productos_user / productos_pass"
echo "   • auth_db: auth_user / auth_pass"
echo ""
echo "⏭️  Siguiente paso: Ejecutar 06_seed_data.sh para insertar datos de prueba"
