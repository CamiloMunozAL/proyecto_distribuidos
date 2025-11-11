# 🏗️ Guía de Infraestructura – Proyecto Distribuido Incus

> 🎯 Objetivo: Explicar cómo se construyó la infraestructura del sistema distribuido utilizando contenedores **Incus**, redes internas y servicios distribuidos.

---

## 🧭 1️⃣ Inicialización de Incus

**Script ejecutado:** `00_setup_incus.sh`

```bash
# Inicializar Incus con configuración automática
incus admin init --auto

# Crear red privada para los contenedores
incus network create incusbr0   ipv4.address=10.122.112.1/24   ipv4.nat=true   ipv6.address=none
```

📘 **Explicación:**
> Se crea una red interna llamada `incusbr0` con direccionamiento privado (10.122.112.0/24).  
> Esta red permite que los contenedores se comuniquen entre sí sin exponer puertos al exterior.

---

## 🧩 2️⃣ Creación de Contenedores

**Script ejecutado:** `01_create_containers.sh`

```bash
# Crear contenedores base
incus launch images:ubuntu/22.04 web
incus launch images:ubuntu/22.04 auth
incus launch images:ubuntu/22.04 db1
incus launch images:ubuntu/22.04 db2
incus launch images:ubuntu/22.04 db3
incus launch images:ubuntu/22.04 incus-ui

# Comprobar estado
incus list
```

📘 **Resultado esperado:**
```
| NAME      | STATE   | IPV4              | TYPE | SNAPSHOTS |
|------------|----------|-------------------|------|------------|
| web        | RUNNING | 10.122.112.159    | CONTAINER | 0 |
| auth       | RUNNING | 10.122.112.106    | CONTAINER | 0 |
| db1        | RUNNING | 10.122.112.153    | CONTAINER | 0 |
| db2        | RUNNING | 10.122.112.233    | CONTAINER | 0 |
| db3        | RUNNING | 10.122.112.16     | CONTAINER | 0 |
| incus-ui   | RUNNING | 10.122.112.195    | CONTAINER | 0 |
```

📘 **Explicación:**
> Se crearon seis contenedores que conforman la arquitectura del sistema.  
> Todos están conectados a la red interna `incusbr0` y se comunican entre sí mediante IPs estáticas.

---

## 💾 3️⃣ Instalación de MongoDB

**Script ejecutado:** `02_install_mongodb.sh`

```bash
# En cada contenedor db1, db2, db3:
apt-get update && apt-get install -y mongodb-org
mkdir -p /data/db-27017 /data/db-27018 /data/db-27019
chown -R mongodb:mongodb /data
```

📘 **Explicación:**
> Cada contenedor de base de datos ejecuta múltiples instancias de MongoDB (27017, 27018, 27019).  
> Esto permite simular varios nodos (PRIMARY, SECONDARY, ARBITER) sin necesidad de crear más contenedores.

---

## 🔁 4️⃣ Configuración de Replica Sets

**Script ejecutado:** `03_configure_replicas.sh`

### Replica sets creados:

| Replica Set | Shard | PRIMARY | SECONDARY | ARBITER |
|--------------|--------|----------|------------|----------|
| rs_products_a | Productos A–M | db1:27017 | db2:27018 | db3:27018 |
| rs_products_b | Productos N–Z | db2:27017 | db1:27018 | db3:27019 |
| rs_users      | Usuarios/Login | db3:27017 | db1:27019 | — |

📘 **Explicación:**
> Cada replica set tiene su PRIMARY y SECONDARY en distintos contenedores, y los shards de productos incluyen un ARBITER en db3.  
> Esto garantiza alta disponibilidad y failover automático.

---

## 🌐 5️⃣ Red de Conexiones

```bash
incus network list
```
Salida esperada:
```
| NAME      | TYPE | MANAGED | IPV4            | IPV6 |
|------------|------|----------|-----------------|------|
| incusbr0   | bridge | YES  | 10.122.112.1/24 | none |
```

📘 **Explicación:**
> Todos los contenedores están dentro de la misma red puente `incusbr0`, lo que permite comunicación directa sin necesidad de NAT adicional.

---

## 🖥️ 6️⃣ Habilitar Interfaz Gráfica de Incus

**Script ejecutado:** `07_install_incus_ui.sh`

```bash
# Activar la interfaz HTTPS
incus config set core.https_address :8443
```
Accede desde el navegador a:
```
https://10.0.2.15:8443
```

📘 **Explicación:**
> La interfaz nativa de Incus permite observar y administrar todos los contenedores desde un panel web seguro por HTTPS.

---

## ⚙️ 7️⃣ Servicios y Puertos Asignados

| Contenedor | Servicio | Puerto | Descripción |
|-------------|-----------|---------|--------------|
| **web** | Dashboard principal | 3000 | Frontend + lógica CRUD |
| **auth** | API de autenticación JWT | 3001 | Login / Registro |
| **db1** | MongoDB | 27017 / 27018 / 27019 | PRIMARY + SECONDARY + RS Users |
| **db2** | MongoDB | 27017 / 27018 | PRIMARY + SECONDARY |
| **db3** | MongoDB | 27017 / 27018 / 27019 | PRIMARY + 2 Árbitros |
| **incus-ui** | Interfaz de gestión | 8443 | Administración de contenedores |

---

## 🧠 8️⃣ Comprobación General

Verificar estado de servicios:

```bash
incus exec web -- systemctl status web-dashboard
incus exec auth -- systemctl status auth-service
incus exec db1 -- ps aux | grep mongod
incus exec db2 -- ps aux | grep mongod
incus exec db3 -- ps aux | grep mongod
```

Ver red y comunicación:

```bash
incus exec web -- ping -c 2 10.122.112.106
incus exec auth -- ping -c 2 10.122.112.153
```

---

## ✅ 9️⃣ Explicación para la exposición

> “Toda la infraestructura corre sobre **Incus**, que funciona como un hipervisor de contenedores Linux.  
> Cada servicio (web, auth, y los tres nodos de MongoDB) corre de forma aislada pero interconectada por una red privada.  
> Los replica sets garantizan la replicación y disponibilidad, y la interfaz Incus UI me permite monitorear todo visualmente.”

---

📘 **Fin de la Guía de Infraestructura – Proyecto Incus**
