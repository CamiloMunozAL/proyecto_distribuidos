# 🧪 Guía de Demostración – Replica Sets MongoDB (db1, db2, db3)

> 🎯 Objetivo: Mostrar alque la base de datos distribuida funciona con **replicación**, **sharding** y **failover automático** entre contenedores Incus.

---

## 🔍 1️⃣ Ver contenedores activos e IPs

```bash
incus list
```

✅ Espera ver algo como:
```
| NAME   | STATE   | IPV4             |
|--------|----------|-----------------|
| db1    | RUNNING | 10.122.112.153  |
| db2    | RUNNING | 10.122.112.233  |
| db3    | RUNNING | 10.122.112.16   |
```

---

## 💾 2️⃣ Ver estado de los Replica Sets

### 🔹 Shard A (rs_products_a)
```bash
incus exec db1 -- mongosh --port 27017 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
```

✅ Resultado esperado:
```
db1:27017 PRIMARY
db2:27018 SECONDARY
db3:27018 ARBITER
```

---

### 🔹 Shard B (rs_products_b)
```bash
incus exec db2 -- mongosh --port 27017 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
```

✅ Resultado esperado:
```
db2:27017 PRIMARY
db1:27018 SECONDARY
db3:27019 ARBITER
```

---

### 🔹 Replica Set de Usuarios (rs_users)
```bash
incus exec db3 -- mongosh --port 27017 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
```

✅ Resultado esperado:
```
db1:27019 PRIMARY
db3:27017 SECONDARY
```

🗣️ **Explicación:**  
Cada réplica tiene un **PRIMARY** (líder), un **SECONDARY** (copia) y un **ARBITER** (votante).  
Los cambios se replican automáticamente y el sistema puede recuperarse solo si un nodo cae.

---

## 📤 3️⃣ Probar replicación en Shard A

### ➕ Insertar un documento en el PRIMARY
```bash
incus exec db1 -- mongosh --port 27017 --eval 'use products_db; db.products.insertOne({nombre:"Manzana", precio:100, shard:"A"})'
```

### 🔍 Verificar que se replicó en el SECONDARY
```bash
incus exec db2 -- mongosh --port 27018 --eval 'rs.secondaryOk(); use products_db; db.products.find({nombre:"Manzana"}).pretty()'
```

✅ Si aparece el documento, la replicación funciona correctamente.

---

## 🔄 4️⃣ Probar failover automático

### 📴 Simular caída del PRIMARY (db1)
```bash
incus stop db1
```

### 🔁 Ver nuevo PRIMARY (esperar ~10 segundos)
```bash
incus exec db2 -- mongosh --port 27018 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
```

✅ Deberías ver:
```
db2:27018 PRIMARY
db3:27018 ARBITER
```

🗣️ **Explica:**  
“MongoDB eligió automáticamente un nuevo PRIMARY con ayuda del árbitro en `db3`.”

---

### ⚙️ Recuperar el nodo caído
```bash
incus start db1
sleep 10
incus exec db1 -- mongosh --port 27017 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
```

✅ `db1` vuelve como **SECONDARY** y se sincroniza.

---

## 📦 5️⃣ Probar replicación en Shard B

### ➕ Insertar un producto (Shard N–Z)
```bash
incus exec db2 -- mongosh --port 27017 --eval 'use products_db; db.products.insertOne({nombre:"Zanahoria", precio:80, shard:"B"})'
```

### 🔍 Verificar en el SECONDARY
```bash
incus exec db1 -- mongosh --port 27018 --eval 'rs.secondaryOk(); use products_db; db.products.find({nombre:"Zanahoria"}).pretty()'
```

✅ Si ves el documento, la replicación del Shard B también está activa.

---

## 👥 6️⃣ Verificar el Replica Set de Usuarios

```bash
incus exec db3 -- mongosh --port 27017 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
```

🗣️ “Aquí se guardan los usuarios del sistema (auth).  
Si uno de los nodos cae, el otro toma el rol de PRIMARY automáticamente.”

---

## 🧹 7️⃣ Limpiar (Eliminar productos de prueba)

Para dejar la base lista y repetir la demostración:

### Eliminar documentos en Shard A
```bash
incus exec db1 -- mongosh --port 27017 --eval 'use products_db; db.products.deleteMany({nombre:{$in:["Manzana"]}})'
```

### Eliminar documentos en Shard B
```bash
incus exec db2 -- mongosh --port 27017 --eval 'use products_db; db.products.deleteMany({nombre:{$in:["Zanahoria"]}})'
```

✅ Ahora puedes volver a insertar productos y repetir la demo sin duplicados.

---

## ✅ 8️⃣ Conclusión para la presentación

> “Aquí demuestro que mis tres contenedores de base de datos (`db1`, `db2`, `db3`) funcionan de forma coordinada:  
> - Cada shard tiene su propio PRIMARY, SECONDARY y ARBITER.  
> - Los datos se replican automáticamente entre nodos.  
> - Si un nodo se apaga, otro toma el liderazgo sin perder datos.  
> - Puedo limpiar los registros y repetir la prueba en cualquier momento.”

---

📘 **Fin de la demostración**
