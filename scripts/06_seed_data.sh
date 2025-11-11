#!/bin/bash
# ========================================
# Script 06 - Creación de colecciones e inserción de datos de ejemplo
# ========================================

set -e

echo "==> Creando índices y datos iniciales..."

# Productos A
incus exec db1 -- mongosh --port 27017 --eval '
use products_a;
db.createCollection("products");
db.products.createIndex({ category: 1, sku: 1 }, { unique: true });
db.products.insertMany([
 {sku:"A100", name:"Teclado", price:18.5, category:"Accesorios", updated_at:new Date()},
 {sku:"E200", name:"TV 42",  price:899,  category:"Electrónicos", updated_at:new Date()}
]);
'

# Productos B
incus exec db2 -- mongosh --port 27017 --eval '
use products_b;
db.createCollection("products");
db.products.createIndex({ category: 1, sku: 1 }, { unique: true });
db.products.insertMany([
 {sku:"N300", name:"Novela X", price:23.9, category:"Novelas", updated_at:new Date()},
 {sku:"Z900", name:"Zapatillas", price:65, category:"Zapatos", updated_at:new Date()}
]);
'

# Usuarios
incus exec db3 -- mongosh --port 27017 --eval '
use users;
db.createCollection("accounts");
db.accounts.createIndex({ email: 1 }, { unique: true });
db.accounts.insertOne({ username:"admin", email:"admin@test.com", password:"1234" });
'
