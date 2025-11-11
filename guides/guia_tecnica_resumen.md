# 🧠 Guía Técnica Resumen – Sistema Distribuido con Incus y MongoDB

> 🎯 Objetivo: Ofrecer una visión global técnica del sistema distribuido, sus componentes, configuraciones clave y funcionamiento general.

---

## 🧭 1️⃣ Descripción General del Proyecto

El sistema es una **plataforma distribuida de gestión de productos** implementada sobre **contenedores Incus**, que utiliza **MongoDB con fragmentación horizontal y replica sets** para lograr **alta disponibilidad**.

### Componentes principales:
- **web** → Aplicación principal (Node.js + Express + EJS).
- **auth** → API de autenticación (Node.js + JWT + bcrypt).
- **db1**, **db2**, **db3** → Nodos MongoDB distribuidos con sharding y replicación.
- **incus-ui** → Interfaz gráfica para gestionar los contenedores.

---

## 🧩 2️⃣ Arquitectura General

```
                      ┌────────────────────┐
                      │  Usuario Navegador │
                      └──────────┬─────────┘
                                 │ HTTP
                      ┌──────────▼──────────┐
                      │   web (Dashboard)   │
                      └──────────┬──────────┘
                                 │
          ┌──────────────────────┴─────────────────────┐
          ▼                                            ▼
 ┌──────────────────┐                      ┌──────────────────┐
 │   auth (API JWT) │                      │   Mongo Shards   │
 │   Login/Register  │                      │ rs_products_a/b  │
 └─────────┬─────────┘                      └─────────┬────────┘
           │ MongoDB queries                            │
           ▼                                            ▼
 ┌──────────────────┐                      ┌──────────────────┐
 │ db3 (rs_users)   │                      │ db1 / db2 / db3  │
 │ Usuarios/Login DB │                      │ Shards A–M / N–Z │
 └──────────────────┘                      └──────────────────┘
```

📘 **Explicación:**
> El contenedor `web` maneja toda la lógica del dashboard y conecta con `auth` para la autenticación.  
> Según la primera letra del producto, se conecta al shard A o B.  
> Las bases de datos están replicadas para asegurar disponibilidad en caso de fallo.

---

## 💾 3️⃣ Distribución de Contenedores

| Contenedor | Rol | IP | Servicios |
|-------------|-----|----|-----------|
| **web** | Dashboard principal | 10.122.112.159 | Express + CRUD + vistas EJS |
| **auth** | Autenticación JWT | 10.122.112.106 | Registro, login, verificación |
| **db1** | MongoDB nodo 1 | 10.122.112.153 | PRIMARY A–M, SECONDARY N–Z, RS Users secundario |
| **db2** | MongoDB nodo 2 | 10.122.112.233 | PRIMARY N–Z, SECONDARY A–M |
| **db3** | MongoDB nodo 3 | 10.122.112.16 | PRIMARY usuarios, árbitros A y B |
| **incus-ui** | Panel de control | 10.122.112.195 | Gestión visual de contenedores |

---

## 🔁 4️⃣ Replica Sets y Sharding

### Replica Sets:

| Replica Set | PRIMARY | SECONDARY | ARBITER | Datos |
|--------------|----------|------------|----------|--------|
| **rs_products_a** | db1:27017 | db2:27018 | db3:27018 | Productos A–M |
| **rs_products_b** | db2:27017 | db1:27018 | db3:27019 | Productos N–Z |
| **rs_users** | db1:27019 | db3:27017 | — | Usuarios y roles |

### Sharding:

**Tipo:** Horizontal (por rango de nombre)  
**Shard Key:** `name` (primera letra del producto)

Ejemplo:
```
"Manzana"  → Shard A (db1)
"Naranja"  → Shard B (db2)
```

📘 **Explicación:**
> Esto distribuye los datos de manera uniforme y mejora el rendimiento al consultar o insertar productos.

---

## 🔐 5️⃣ Seguridad y Autenticación

- **bcryptjs:** Hash de contraseñas con salt de 10 rondas.  
- **JWT:** Tokens firmados con secreto del `.env` y expiración de 8h.  
- **Middleware Express:** Verifica tokens antes de permitir acceso al dashboard.  
- **Base de datos `rs_users`:** Replica Set para evitar pérdida de datos de usuarios.

📘 **Explicación:**
> El sistema no guarda contraseñas planas ni mantiene sesiones. Todo se basa en tokens JWT, seguros y autoexpirables.

---

## ⚙️ 6️⃣ Servicios Systemd

Cada servicio está configurado para iniciarse automáticamente y reiniciarse en caso de error.

Ejemplo (`auth-service.service`):
```ini
[Service]
ExecStart=/usr/bin/node /opt/auth-service/server.js
Restart=always
User=root
WorkingDirectory=/opt/auth-service
```

📘 **Explicación:**
> Los servicios `web` y `auth` corren en segundo plano como procesos gestionados por `systemd`, garantizando alta disponibilidad incluso tras reinicios.

---

## 🧪 7️⃣ Flujo de Operación

1. Usuario accede a `http://10.122.112.159:3000` (web).  
2. Si no está autenticado → `web` llama a `auth` (`/auth/login`).  
3. `auth` valida usuario en `rs_users` (db3/db1) y devuelve JWT.  
4. Usuario crea un producto.  
5. `web` evalúa la primera letra → selecciona shard (A o B).  
6. Producto se guarda en `db1` o `db2`.  
7. MongoDB replica el dato al SECONDARY.  
8. Si cae un PRIMARY, se elige uno nuevo automáticamente.

---

## 📊 8️⃣ Comandos de Verificación Rápida

Ver todos los contenedores:
```bash
incus list
```

Ver estado de réplica:
```bash
incus exec db1 -- mongosh --port 27017 --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"
```

Ver logs del dashboard:
```bash
incus exec web -- journalctl -u web-dashboard -f
```

Ver estado del servicio de autenticación:
```bash
incus exec auth -- systemctl status auth-service
```

---

## ✅ 9️⃣ Resumen Técnico Final

| Aspecto | Implementación |
|----------|----------------|
| **Contenedores** | 6 (web, auth, db1, db2, db3, incus-ui) |
| **Bases de datos** | MongoDB 8.0 con 3 replica sets |
| **Sharding** | Horizontal por rango (A–M, N–Z) |
| **Autenticación** | JWT + bcrypt |
| **Infraestructura** | Incus + red `incusbr0` |
| **Alta disponibilidad** | Sí (failover automático) |
| **Gestión visual** | Incus UI HTTPS |
| **Lenguajes y frameworks** | Node.js 20 + Express + MongoDB + EJS |


📘 **Fin de la Guía Técnica Resumen – Proyecto Distribuido Incus**
