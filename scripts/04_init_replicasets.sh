#!/bin/bash
# ========================================
# Script 04 - Inicialización de Replica Sets MongoDB
# ========================================
# Inicializa los 3 replica sets con sus miembros iniciales:
# - rs_products_a: PRIMARY (db1:27017) + SECONDARY (db2:27018)
# - rs_products_b: PRIMARY (db2:27017) + SECONDARY (db1:27018)
# - rs_users: PRIMARY (db3:27017) + SECONDARY (db1:27019)
# Los árbitros se agregan en el script 03.2
# ========================================

set -e

echo "==> Inicializando Replica Sets..."
echo ""

echo "==> [1/3] Iniciando rs_products_a (Shard A-M) ..."
incus exec db1 -- mongosh --port 27017 --quiet --eval '
rs.initiate({
  _id: "rs_products_a",
  members: [
    { _id: 0, host: "db1:27017", priority: 2 },
    { _id: 1, host: "db2:27018", priority: 1 }
  ]
});
' 2>/dev/null
echo "    ✅ rs_products_a inicializado"
sleep 3

echo ""
echo "==> [2/3] Iniciando rs_products_b (Shard N-Z) ..."
incus exec db2 -- mongosh --port 27017 --quiet --eval '
rs.initiate({
  _id: "rs_products_b",
  members: [
    { _id: 0, host: "db2:27017", priority: 2 },
    { _id: 1, host: "db1:27018", priority: 1 }
  ]
});
' 2>/dev/null
echo "    ✅ rs_products_b inicializado"
sleep 3

echo ""
echo "==> [3/3] Iniciando rs_users (Autenticación) ..."
incus exec db3 -- mongosh --port 27017 --quiet --eval '
rs.initiate({
  _id: "rs_users",
  members: [
    { _id: 0, host: "db3:27017", priority: 2 },
    { _id: 1, host: "db1:27019", priority: 1 }
  ]
});
' 2>/dev/null
echo "    ✅ rs_users inicializado"

echo ""
echo "==> Esperando estabilización de replica sets (15 segundos)..."
sleep 15

echo ""
echo "==> Verificando estado de replica sets..."
echo ""
echo "📊 Estado de rs_products_a:"
incus exec db1 -- mongosh --port 27017 --quiet --eval "
  rs.status().members.forEach(m => {
    print('   ' + m.name + ' -> ' + m.stateStr);
  });
" 2>/dev/null

echo ""
echo "📊 Estado de rs_products_b:"
incus exec db2 -- mongosh --port 27017 --quiet --eval "
  rs.status().members.forEach(m => {
    print('   ' + m.name + ' -> ' + m.stateStr);
  });
" 2>/dev/null

echo ""
echo "📊 Estado de rs_users:"
incus exec db3 -- mongosh --port 27017 --quiet --eval "
  rs.status().members.forEach(m => {
    print('   ' + m.name + ' -> ' + m.stateStr);
  });
" 2>/dev/null

echo ""
echo "✅ Replica Sets inicializados correctamente"
echo ""
echo "⏭️  Siguiente paso: Ejecutar 03.2_add_arbiters_and_secondary.sh para agregar árbitros"
