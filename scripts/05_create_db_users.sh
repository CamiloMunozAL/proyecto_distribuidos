#!/bin/bash
# ========================================
# Script 05 - Creación de usuarios MongoDB
# ========================================

set -e

incus exec db1 -- mongosh --port 27017 --eval '
use admin;
db.createUser({user:"app_prod_a", pwd:"app_prod_a_pwd", roles:[{role:"readWrite", db:"products_a"}]});
'

incus exec db2 -- mongosh --port 27017 --eval '
use admin;
db.createUser({user:"app_prod_b", pwd:"app_prod_b_pwd", roles:[{role:"readWrite", db:"products_b"}]});
'

incus exec db3 -- mongosh --port 27017 --eval '
use admin;
db.createUser({user:"app_users", pwd:"app_users_pwd", roles:[{role:"readWrite", db:"users"}]});
'
