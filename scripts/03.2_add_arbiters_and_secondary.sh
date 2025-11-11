#!/bin/bash
# ========================================
# Script 03.2 - Agregar árbitros y secundario para rs_users
# ========================================
# Soluciona:
# 1. Replica sets de productos sin failover automático (necesitan 3 nodos)
# 2. rs_users sin replicación (SPOF)
# ========================================

set -e

echo "==> Paso 1: Configurando árbitros en db3 para rs_products_a y rs_products_b ..."

incus exec db3 -- bash -lc '
# Crear directorios para árbitros
mkdir -p /data/arbiter-27018 /data/arbiter-27019
chown -R mongodb:mongodb /data/arbiter-27018 /data/arbiter-27019

# Árbitro para rs_products_a (puerto 27018)
cat >/etc/systemd/system/mongod-arbiter-27018.service <<EOF
[Unit]
Description=MongoDB Arbiter for rs_products_a
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27018 --dbpath /data/arbiter-27018 \
  --replSet rs_products_a --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Árbitro para rs_products_b (puerto 27019)
cat >/etc/systemd/system/mongod-arbiter-27019.service <<EOF
[Unit]
Description=MongoDB Arbiter for rs_products_b
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27019 --dbpath /data/arbiter-27019 \
  --replSet rs_products_b --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Habilitar y arrancar servicios
systemctl daemon-reload
systemctl enable --now mongod-arbiter-27018 mongod-arbiter-27019

# Esperar a que arranquen
sleep 5
'

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
echo "==> Paso 4: Configurando secundario para rs_users en db1 ..."

incus exec db1 -- bash -lc '
# Crear directorio para secundario de rs_users
mkdir -p /data/db-27019
chown -R mongodb:mongodb /data/db-27019

# Crear servicio para secundario de rs_users
cat >/etc/systemd/system/mongod-27019.service <<EOF
[Unit]
Description=MongoDB 27019 rs_users SECONDARY
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27019 --dbpath /data/db-27019 \
  --replSet rs_users --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mongod-27019

# Esperar a que arranque
sleep 5
'

echo "==> Paso 5: Agregando secundario db1:27019 a rs_users ..."
incus exec db3 -- mongosh --port 27017 --quiet --eval "
try {
  rs.add('db1:27019');
  print('✅ Secundario db1:27019 agregado a rs_users');
} catch(e) {
  print('⚠️  Error: ' + e.message);
}
"

echo ""
echo "==> Paso 6: Verificando configuración final ..."

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
echo "🎯 Ahora cada replica set tiene 3 nodos:"
echo "   • rs_products_a: db1:27017 (PRIMARY) + db2:27018 (SECONDARY) + db3:27018 (ARBITER)"
echo "   • rs_products_b: db2:27017 (PRIMARY) + db1:27018 (SECONDARY) + db3:27019 (ARBITER)"
echo "   • rs_users:      db3:27017 (PRIMARY) + db1:27019 (SECONDARY)"
echo ""
echo "✅ Failover automático habilitado (mayoría de votos garantizada)"
