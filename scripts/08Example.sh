incus exec incus-ui -- bash -lc '
apt-get update && apt-get install -y curl
rm -rf /opt/incus-ui /tmp/incus-ui.tar.gz
curl -L -o /tmp/incus-ui.tar.gz https://github.com/turtle0x1/Incus-UI/archive/refs/heads/main.tar.gz
mkdir -p /opt
tar -xzvf /tmp/incus-ui.tar.gz -C /opt
mv /opt/Incus-UI-main /opt/incus-ui
cd /opt/incus-ui && npm install && npm run build
npm install -g serve
nohup serve -s build -l 3000 >/var/log/incus-ui.log 2>&1 &
echo "UI ejecutándose en puerto 3000 dentro de incus-ui"
'