# Tips para consultar usuarios en MongoDB

## Cómo ver los usuarios registrados en la base de datos

1. Accede al contenedor donde está tu instancia MongoDB (por ejemplo, db3):
   ```bash
   incus exec db3 -- bash
   ```
2. Conéctate al puerto correspondiente con mongosh:
   ```bash
   mongosh --port 27017
   ```
3. Cambia a la base de datos de usuarios:
   ```js
   use users_db
   ```
4. Consulta los usuarios registrados:
   ```js
   db.users.find()
   ```

## Ejemplo de salida

```
rs_users [direct: primary] users_db> db.users.find()
[
  {
    _id: ObjectId('6912c2ea17b5b43b6d222dac'),
    username: 'admin',
    email: 'admin@example.com',
    passwordHash: '$2a$10$mEy5A5qsOlxXw60fFRjPKuO0TgGilBbDIQFFzpQPrzw1sJ8TWmUkO',
    role: 'admin',
    createdAt: ISODate('2025-11-11T05:00:26.758Z'),
    lastLogin: ISODate('2025-11-11T16:44:21.011Z')
  },
  {
    _id: ObjectId('6912d1e517b5b43b6d222dad'),
    username: 'Usuario Test',
    email: 'test@example.com',
    passwordHash: '$2a$10$0qSbNAKMcaQBGdiSVYyrROS0luOSU7fxe6T9xMYglkdv.Jj4sdtn.',
    role: 'vendedor',
    createdAt: ISODate('2025-11-11T06:04:21.564Z'),
    lastLogin: null
  }
]
rs_users [direct: primary] users_db>
```

Así puedes ver los usuarios registrados y sus datos principales.
