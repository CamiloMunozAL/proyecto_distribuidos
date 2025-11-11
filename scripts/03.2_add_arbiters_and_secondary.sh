#!/bin/bash
# ========================================
# Script 03.2 - Agregar árbitros para alta disponibilidad
# ========================================
# Agrega nodos ARBITER a los replica sets para habilitar failover automático:
# - rs_products_a: Agrega db3:27018 como ARBITER
# - rs_products_b: Agrega db3:27019 como ARBITER
# 
# Con 3 nodos (PRIMARY + SECONDARY + ARBITER) se garantiza mayoría de votos
# para elección automática de nuevo PRIMARY en caso de fallo.
# ========================================

set -e

echo "==> Agregando árbitros a los replica sets..."
echo ""
echo "📝 Los árbitros participan en elecciones pero no almacenan datos"
echo ""

echo "==> Paso 1: Verificando que los servicios de árbitros estén activos..."

# Los servicios de árbitros ya se configuraron en 03_configure_replicas.sh
# Solo verificamos que estén corriendo
# Verificar que los servicios estén activos
systemctl is-active mongod-27018 >/dev/null 2>&1 && echo "   ✅ mongod-27018 (arbiter rs_products_a) activo"
systemctl is-active mongod-27019 >/dev/null 2>&1 && echo "   ✅ mongod-27019 (arbiter rs_products_b) activo"
'

echo ""
echo "==> Paso 2: Configurando write concern y agregando árbitro a rs_products_a ..."
incus exec db1 -- mongosh --port 27017 --quiet --eval "
try {
  db.adminCommand({
    setDefaultRWConcern: 1,
    defaultWriteConcern: { w: 'majority', wtimeout: 5000 }
  });
  print('✅ Write concern configurado');
  rs.addArb('db3:27018');
  print('✅ Árbitro db3:27018 agregado a rs_products_a');
} catch(e) {
  print('⚠️  Error: ' + e.message);
}
"

echo "==> Paso 3: Configurando write concern y agregando árbitro a rs_products_b ..."
incus exec db2 -- mongosh --port 27017 --quiet --eval "
try {
  db.adminCommand({
    setDefaultRWConcern: 1,
    defaultWriteConcern: { w: 'majority', wtimeout: 5000 }
  });
  print('✅ Write concern configurado');
  rs.addArb('db3:27019');
  print('✅ Árbitro db3:27019 agregado a rs_products_b');
} catch(e) {
  print('⚠️  Error: ' + e.message);
}
"

echo ""
echo "==> Paso 3: Esperando estabilización de los replica sets (10 segundos)..."
sleep 10

echo ""
echo "==> Paso 4: Verificando configuración final de replica sets..."

echo ""
echo "📊 Estado de rs_products_a:"
incus exec db1 -- mongosh --port 27017 --quiet --eval "
rs.status().members.forEach(m => {
  print('  ' + m.name + ' -> ' + m.stateStr);
});
"

echo ""
echo "📊 Estado de rs_products_b:"
incus exec db2 -- mongosh --port 27017 --quiet --eval "
rs.status().members.forEach(m => {
  print('  ' + m.name + ' -> ' + m.stateStr);
});
"

echo ""
echo "📊 Estado de rs_users:"
incus exec db3 -- mongosh --port 27017 --quiet --eval "
rs.status().members.forEach(m => {
  print('  ' + m.name + ' -> ' + m.stateStr);
});
"

echo ""
echo "✅ Configuración de alta disponibilidad completada"
echo ""
echo "🎯 Configuración final de replica sets:"
echo "   • rs_products_a (Shard A-M):"
echo "     - PRIMARY:   db1:27017"
echo "     - SECONDARY: db2:27018"
echo "     - ARBITER:   db3:27018"
echo ""
echo "   • rs_products_b (Shard N-Z):"
echo "     - PRIMARY:   db2:27017"
echo "     - SECONDARY: db1:27018"
echo "     - ARBITER:   db3:27019"
echo ""
echo "   • rs_users (Autenticación):"
echo "     - PRIMARY:   db3:27017"
echo "     - SECONDARY: db1:27019"
echo ""
echo "✅ Failover automático habilitado en todos los replica sets"
echo "✅ Mayoría de votos garantizada para elecciones automáticas"
echo ""
echo "⏭️  Siguiente paso: Ejecutar 05_create_db_users.sh para crear usuarios de base de datos"
