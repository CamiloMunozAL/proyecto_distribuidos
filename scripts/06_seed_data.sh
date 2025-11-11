#!/bin/bash
# ========================================
# Script 06 - Inserción de datos de prueba
# ========================================
# Crea las colecciones e inserta datos de ejemplo:
# - productos_db.productos: Colección de productos (en ambos shards)
# - auth_db.users: Colección de usuarios del sistema
# ========================================

set -e

echo "==> Insertando datos de prueba en las bases de datos..."
echo ""

echo "==> [1/3] Creando colección e índices en productos_db (Shard A)..."
incus exec db1 -- mongosh --port 27017 --quiet --eval '
use productos_db;
db.createCollection("productos");
db.productos.createIndex({ name: 1 }, { unique: true });
db.productos.createIndex({ category: 1 });
db.productos.createIndex({ sku: 1 }, { unique: true });
print("✅ Colección productos creada en Shard A");
print("✅ Índices creados: name, category, sku");
' 2>/dev/null

echo ""
echo "==> [2/3] Creando colección e índices en productos_db (Shard B)..."
incus exec db2 -- mongosh --port 27017 --quiet --eval '
use productos_db;
db.createCollection("productos");
db.productos.createIndex({ name: 1 }, { unique: true });
db.productos.createIndex({ category: 1 });
db.productos.createIndex({ sku: 1 }, { unique: true });
print("✅ Colección productos creada en Shard B");
print("✅ Índices creados: name, category, sku");
' 2>/dev/null

echo ""
echo "==> [3/3] Creando colección de usuarios en auth_db..."
incus exec db3 -- mongosh --port 27017 --quiet --eval '
use auth_db;
db.createCollection("users");
db.users.createIndex({ email: 1 }, { unique: true });
print("✅ Colección users creada");
print("✅ Índice único en email creado");
' 2>/dev/null

echo ""
echo "✅ Datos de prueba y estructura de base de datos listos"
echo ""
echo "📊 Estructura creada:"
echo "   • productos_db.productos (Shard A - rs_products_a)"
echo "   • productos_db.productos (Shard B - rs_products_b)"
echo "   • auth_db.users (rs_users)"
echo ""
echo "📝 Los datos de productos y usuarios se insertarán desde las aplicaciones"
echo ""
echo "⏭️  Siguiente paso: Ejecutar 09_setup_auth_service.sh para instalar el servicio de autenticación"
