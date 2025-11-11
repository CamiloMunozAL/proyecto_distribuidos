# Arquitectura de Base de Datos - Sistema Distribuido MongoDB

> 📚 **Guía de referencia completa**: Cómo están estructuradas las bases de datos en los 3 contenedores

---

## 🏗️ ARQUITECTURA COMPLETA DE BASE DE DATOS

### 📦 CONTENEDORES (6 en total)

```
┌─────────────────────────────────────────────────────────────────┐
│                    INFRAESTRUCTURA INCUS                         │
├─────────────┬─────────────┬─────────────┬──────────┬──────────┤
│   db1       │   db2       │   db3       │   auth   │   web    │
│ 10.122...153│ 10.122...233│ 10.122...16 │   ...106 │   ...159 │
└─────────────┴─────────────┴─────────────┴──────────┴──────────┘
```

---

## 💾 INSTANCIAS DE MONGODB (8 en total)

**Importante**: No todos los contenedores tienen 3 instancias. Solo se usan los puertos necesarios.

### 🟦 **Contenedor db1** (IP: 10.122.112.153) - 3 instancias
```
┌────────────────────────────────────────────┐
│              db1                           │
├────────────────────────────────────────────┤
│ ✅ MongoDB puerto 27017 (mongod-27017)     │
│    → rs_products_a (PRIMARY)              │
│                                            │
│ ✅ MongoDB puerto 27018 (mongod-27018)     │
│    → rs_products_b (SECONDARY)            │
│                                            │
│ ✅ MongoDB puerto 27019 (mongod-27019)     │
│    → rs_users (SECONDARY)                 │
└────────────────────────────────────────────┘
```

### 🟩 **Contenedor db2** (IP: 10.122.112.233) - 2 instancias
```
┌────────────────────────────────────────────┐
│              db2                           │
├────────────────────────────────────────────┤
│ ✅ MongoDB puerto 27017 (mongod-27017)     │
│    → rs_products_b (PRIMARY)              │
│                                            │
│ ✅ MongoDB puerto 27018 (mongod-27018)     │
│    → rs_products_a (SECONDARY)            │
│                                            │
│ ⚪ Puerto 27019 - NO SE USA               │
└────────────────────────────────────────────┘
```

### 🟨 **Contenedor db3** (IP: 10.122.112.16) - 3 instancias
```
┌────────────────────────────────────────────┐
│              db3                           │
├────────────────────────────────────────────┤
│ ✅ MongoDB puerto 27017 (mongod-27017)     │
│    → rs_users (PRIMARY)                   │
│                                            │
│ ✅ MongoDB puerto 27018 (mongod-27018)     │
│    → rs_products_a (ARBITER)              │
│                                            │
│ ✅ MongoDB puerto 27019 (mongod-27019)     │
│    → rs_products_b (ARBITER)              │
└────────────────────────────────────────────┘
```

---

## 🔗 REPLICA SETS (3 grupos independientes)

Ahora, estas 9 instancias se agrupan en **3 replica sets**:

### 🔵 **REPLICA SET 1: rs_products_a** (Shard A-M)
```
┌─────────────────────────────────────────────────────────┐
│              rs_products_a (Productos A-M)              │
├─────────────────────────────────────────────────────────┤
│ 📍 PRIMARY:   db1:27017  (Líder - Escrituras aquí)     │
│ 📋 SECONDARY: db2:27018  (Copia - Solo lectura)        │
│ ⚖️  ARBITER:   db3:27018  (Votante - No tiene datos)   │
└─────────────────────────────────────────────────────────┘

Base de datos: productos_db
Colección: productos
Datos: Productos cuyo nombre empieza con A-M
```

### 🟢 **REPLICA SET 2: rs_products_b** (Shard N-Z)
```
┌─────────────────────────────────────────────────────────┐
│              rs_products_b (Productos N-Z)              │
├─────────────────────────────────────────────────────────┤
│ 📍 PRIMARY:   db2:27017  (Líder - Escrituras aquí)     │
│ 📋 SECONDARY: db1:27018  (Copia - Solo lectura)        │
│ ⚖️  ARBITER:   db3:27019  (Votante - No tiene datos)   │
└─────────────────────────────────────────────────────────┘

Base de datos: productos_db
Colección: productos
Datos: Productos cuyo nombre empieza con N-Z
```

### 🟡 **REPLICA SET 3: rs_users** (Autenticación)
```
┌─────────────────────────────────────────────────────────┐
│                   rs_users (Usuarios)                   │
├─────────────────────────────────────────────────────────┤
│ 📍 PRIMARY:   db3:27017  (Líder - Escrituras aquí)     │
│ 📋 SECONDARY: db1:27019  (Copia - Solo lectura)        │
└─────────────────────────────────────────────────────────┘

Base de datos: users_db (o auth_db)
Colección: users
Datos: Usuarios del sistema (login, JWT)
```

---

## 📊 VISTA VISUAL COMPLETA

```
═════════════════════════════════════════════════════════════════
                        MAPA COMPLETO
═════════════════════════════════════════════════════════════════

db1 (10.122.112.153)           db2 (10.122.112.233)
├─ :27017 → PRIMARY            ├─ :27017 → PRIMARY
│   de rs_products_a            │   de rs_products_b
│   (Productos A-M)             │   (Productos N-Z)
│                               │
├─ :27018 → SECONDARY          ├─ :27018 → SECONDARY
│   de rs_products_b            │   de rs_products_a
│   (Productos N-Z)             │   (Productos A-M)
│                               │
└─ :27019 → SECONDARY          └─ :27019 → ARBITER
    de rs_users                     de rs_products_b
    (Usuarios)                      (Productos N-Z)

           db3 (10.122.112.16)
           ├─ :27017 → PRIMARY
           │   de rs_users
           │   (Usuarios)
           │
           ├─ :27018 → ARBITER
           │   de rs_products_a
           │   (Productos A-M)
           │
           └─ :27019 → ARBITER
               de rs_products_b
               (Productos N-Z)
```

---

## 🗄️ BASES DE DATOS Y COLECCIONES

### Base de datos: **productos_db**
- **Shard A** (rs_products_a): Productos con nombre A-M
- **Shard B** (rs_products_b): Productos con nombre N-Z
- **Colección**: `productos`
- **Ejemplo**: "Manzana" → Shard A, "Zanahoria" → Shard B

### Base de datos: **users_db** (o auth_db)
- **Replica Set**: rs_users
- **Colección**: `users`
- **Contiene**: Usuarios para autenticación (email, password hash, JWT)

---

## 🔄 ¿CÓMO FUNCIONA?

### 1. **Escritura en productos A-M:**
```
Cliente → db1:27017 (PRIMARY) → Replica a db2:27018 (SECONDARY)
                                 → db3:27018 (ARBITER solo vota)
```

### 2. **Escritura en productos N-Z:**
```
Cliente → db2:27017 (PRIMARY) → Replica a db1:27018 (SECONDARY)
                                 → db3:27019 (ARBITER solo vota)
```

### 3. **Login de usuario:**
```
Cliente → auth service → db3:27017 (PRIMARY) → Replica a db1:27019 (SECONDARY)
```

---

## ⚡ ESCENARIO: CUANDO db1 ESTÁ CAÍDO

```
❌ db1 APAGADO
├─ db1:27017 → ❌ (era PRIMARY de rs_products_a)
├─ db1:27018 → ❌ (era SECONDARY de rs_products_b)
└─ db1:27019 → ❌ (era SECONDARY de rs_users)

✅ IMPACTO Y RECUPERACIÓN AUTOMÁTICA:
├─ rs_products_a: db2:27018 se promueve a PRIMARY ✅ (failover ~15s)
├─ rs_products_b: Sigue funcionando (PRIMARY en db2) ✅
└─ rs_users: db3 sigue como PRIMARY ✅
             pero auth puede fallar si intenta conectarse a db1:27019 ❌
```

**¿Por qué falla el servicio auth?**
- El servicio auth tiene configurado: `mongodb://db3:27017,db1:27019/users_db?replicaSet=rs_users`
- Cuando db1:27019 está caído, el driver de MongoDB intenta conectarse y obtiene timeout (EHOSTUNREACH)
- Aunque db3:27017 (PRIMARY) está disponible, la conexión falla por el timeout esperando a db1

**Solución:**
1. Levantar db1 → `incus start db1`
2. O reconfigurar auth para usar solo db3 temporalmente

---

## 🎯 TABLA RESUMEN

| Contenedor | Puerto | Replica Set | Rol | Datos |
|------------|--------|-------------|-----|-------|
| **db1** | 27017 | rs_products_a | PRIMARY | Productos A-M |
| **db1** | 27018 | rs_products_b | SECONDARY | Productos N-Z (copia) |
| **db1** | 27019 | rs_users | SECONDARY | Usuarios (copia) |
| **db2** | 27017 | rs_products_b | PRIMARY | Productos N-Z |
| **db2** | 27018 | rs_products_a | SECONDARY | Productos A-M (copia) |
| **db2** | 27019 | - | - | ⚪ No configurado |
| **db3** | 27017 | rs_users | PRIMARY | Usuarios |
| **db3** | 27018 | rs_products_a | ARBITER | Solo vota, no guarda datos |
| **db3** | 27019 | rs_products_b | ARBITER | Solo vota, no guarda datos |

---

## 📈 MÉTRICAS DEL SISTEMA

- **Total de nodos MongoDB**: 8 instancias distribuidas (3 en db1, 2 en db2, 3 en db3)
- **Replica Sets**: 3 (2 para productos, 1 para usuarios)
- **Tiempo de failover**: ~15 segundos
- **Replication lag**: < 1 segundo
- **Alta disponibilidad**: 2 copias de cada dato (PRIMARY + SECONDARY)
- **Arbiters**: Garantizan mayoría en votaciones sin almacenar datos
- **Puertos no usados**: db2:27019 (reservado pero no configurado)

---

## 🔍 COMANDOS ÚTILES PARA VERIFICAR

```bash
# Ver todos los contenedores
incus list

# Ver estado de rs_products_a (Shard A)
incus exec db1 -- mongosh --port 27017 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'

# Ver estado de rs_products_b (Shard B)
incus exec db2 -- mongosh --port 27017 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'

# Ver estado de rs_users (Autenticación)
incus exec db3 -- mongosh --port 27017 --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'

# Ver servicios MongoDB en un contenedor
incus exec db1 -- systemctl status mongod-27017 mongod-27018 mongod-27019
```

---

## 💡 CONCEPTOS CLAVE

### ¿Qué es un PRIMARY?
- Nodo líder que recibe todas las escrituras
- Solo puede haber 1 PRIMARY por replica set
- Si cae, se elige nuevo PRIMARY automáticamente

### ¿Qué es un SECONDARY?
- Copia de respaldo del PRIMARY
- Se mantiene sincronizado en tiempo real
- Puede ser promovido a PRIMARY si este cae
- Puede servir lecturas (con configuración especial)

### ¿Qué es un ARBITER?
- Participa en elecciones pero no almacena datos
- Útil para tener número impar de nodos (mayoría)
- No consume espacio en disco
- Solo vota en failover

### ¿Qué es Sharding?
- Distribución de datos entre múltiples replica sets
- En este proyecto: manual por primera letra del nombre
- Shard A: productos A-M
- Shard B: productos N-Z

---

## 🎓 PARA TU PRESENTACIÓN

**Puntos clave a destacar:**
1. ✅ **Escalabilidad**: 9 instancias MongoDB distribuidas en 3 contenedores
2. ✅ **Alta Disponibilidad**: Cada dato tiene 2 copias (PRIMARY + SECONDARY)
3. ✅ **Failover Automático**: Sistema se recupera solo en ~15 segundos
4. ✅ **Sharding**: Datos distribuidos para balanceo de carga
5. ✅ **Sin pérdida de datos**: Replicación sincrónica garantiza consistencia
6. ✅ **Tolerancia a fallos**: Sistema funciona aunque 1 contenedor caiga
