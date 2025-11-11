#!/bin/bash
# ========================================
# Script 03 - Configuración de servicios MongoDB (systemd)
# ========================================
# Configura múltiples instancias de MongoDB en cada contenedor:
# - db1: 3 instancias (27017, 27018, 27019)
# - db2: 2 instancias (27017, 27018)
# - db3: 3 instancias (27017, 27018, 27019)
# ========================================

set -e

echo "==> Configurando servicios MongoDB en db1 ..."
incus exec db1 -- bash -lc '
# Crear directorios para las bases de datos
mkdir -p /data/db-27017 /data/db-27018 /data/db-27019
chown -R mongodb:mongodb /data

# Servicio 1: rs_products_a PRIMARY (puerto 27017)
cat >/etc/systemd/system/mongod-27017.service <<EOF
[Unit]
Description=MongoDB 27017 rs_products_a
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27017 --dbpath /data/db-27017 \
  --replSet rs_products_a --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Servicio 2: rs_products_b SECONDARY (puerto 27018)
cat >/etc/systemd/system/mongod-27018.service <<EOF
[Unit]
Description=MongoDB 27018 rs_products_b SECONDARY
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27018 --dbpath /data/db-27018 \
  --replSet rs_products_b --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Servicio 3: rs_users SECONDARY (puerto 27019)
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
systemctl enable --now mongod-27017 mongod-27018 mongod-27019
'
echo "    ✅ db1 configurado (3 servicios: 27017, 27018, 27019)"

echo "==> Configurando servicios MongoDB en db2 ..."
incus exec db2 -- bash -lc '
# Crear directorios para las bases de datos
mkdir -p /data/db-27017 /data/db-27018 /data/db-27019
chown -R mongodb:mongodb /data

# Servicio 1: rs_products_b PRIMARY (puerto 27017)
cat >/etc/systemd/system/mongod-27017.service <<EOF
[Unit]
Description=MongoDB 27017 rs_products_b PRIMARY
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27017 --dbpath /data/db-27017 \
  --replSet rs_products_b --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Servicio 2: rs_products_a SECONDARY (puerto 27018)
cat >/etc/systemd/system/mongod-27018.service <<EOF
[Unit]
Description=MongoDB 27018 rs_products_a SECONDARY
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27018 --dbpath /data/db-27018 \
  --replSet rs_products_a --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Servicio 3: rs_users SECONDARY (puerto 27019)
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
systemctl enable --now mongod-27017 mongod-27018 mongod-27019
'
echo "    ✅ db2 configurado (3 servicios: 27017, 27018, 27019)"

echo "==> Configurando servicios MongoDB en db3 ..."
incus exec db3 -- bash -lc '
# Crear directorios para las bases de datos
mkdir -p /data/db-27017 /data/db-27018 /data/db-27019
chown -R mongodb:mongodb /data

# Servicio 1: rs_users PRIMARY (puerto 27017)
cat >/etc/systemd/system/mongod-27017.service <<EOF
[Unit]
Description=MongoDB 27017 rs_users PRIMARY
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27017 --dbpath /data/db-27017 \
  --replSet rs_users --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Servicio 2: rs_products_a ARBITER (puerto 27018)
cat >/etc/systemd/system/mongod-27018.service <<EOF
[Unit]
Description=MongoDB 27018 rs_products_a ARBITER
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27018 --dbpath /data/db-27018 \
  --replSet rs_products_a --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# Servicio 3: rs_products_b ARBITER (puerto 27019)
cat >/etc/systemd/system/mongod-27019.service <<EOF
[Unit]
Description=MongoDB 27019 rs_products_b ARBITER
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --port 27019 --dbpath /data/db-27019 \
  --replSet rs_products_b --bind_ip 0.0.0.0
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mongod-27017 mongod-27018 mongod-27019
'
echo "    ✅ db3 configurado (3 servicios: 27017, 27018, 27019)"

echo ""
echo "✅ Configuración de servicios MongoDB completada"
echo ""
echo "📊 Resumen de servicios:"
echo "   db1: 27017 (rs_products_a PRIMARY), 27018 (rs_products_b SECONDARY), 27019 (rs_users SECONDARY)"
echo "   db2: 27017 (rs_products_b PRIMARY), 27018 (rs_products_a SECONDARY), 27019 (rs_users SECONDARY)"
echo "   db3: 27017 (rs_users PRIMARY), 27018 (rs_products_a ARBITER), 27019 (rs_products_b ARBITER)"
echo ""
echo "⏭️  Siguiente paso: Ejecutar 04_init_replicasets.sh para inicializar los replica sets"
