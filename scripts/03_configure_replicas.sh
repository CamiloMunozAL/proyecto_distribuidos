#!/bin/bash
# ========================================
# Script 03 - Configuración de réplicas (servicios systemd)
# ========================================

set -e

echo "==> Configurando servicios en db1 ..."
incus exec db1 -- bash -lc '
mkdir -p /data/db-27017 /data/db-27018
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

cat >/etc/systemd/system/mongod-27018.service <<EOF
[Unit]
Description=MongoDB 27018 rs_products_b
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

systemctl daemon-reload
systemctl enable --now mongod-27017 mongod-27018
'

echo "==> Configurando servicios en db2 ..."
incus exec db2 -- bash -lc '
mkdir -p /data/db-27017 /data/db-27018
cat >/etc/systemd/system/mongod-27017.service <<EOF
[Unit]
Description=MongoDB 27017 rs_products_b
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

cat >/etc/systemd/system/mongod-27018.service <<EOF
[Unit]
Description=MongoDB 27018 rs_products_a
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

systemctl daemon-reload
systemctl enable --now mongod-27017 mongod-27018
'

echo "==> Configurando servicio en db3 ..."
incus exec db3 -- bash -lc '
mkdir -p /data/db-27017
cat >/etc/systemd/system/mongod-27017.service <<EOF
[Unit]
Description=MongoDB 27017 rs_users
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
systemctl daemon-reload
systemctl enable --now mongod-27017
'
