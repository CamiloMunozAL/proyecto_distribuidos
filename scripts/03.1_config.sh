for c in db1 db2 db3; do
  echo "==> Corrigiendo permisos y reiniciando servicios en $c..."
  incus exec $c -- bash -lc '
    mkdir -p /data/db-27017 /data/db-27018
    chown -R mongodb:mongodb /data
    chmod -R 755 /data
    systemctl daemon-reload
    systemctl restart mongod-27017 || true
    systemctl restart mongod-27018 || true
  '
done

for c in db2 db3; do
  incus exec $c -- bash -lc '
  mkdir -p /data/db-27017 /data/db-27018
  chown -R mongodb:mongodb /data
  chmod -R 755 /data
  systemctl restart mongod-27017 || true
  systemctl restart mongod-27018 || true
  '
done
