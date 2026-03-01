# Creating DB using pgAdmin

Perfecto — y no, **no necesitas desinstalar nada** 👍
Lo que estás viendo es totalmente normal con el instalador de **EDB + pgAdmin 4**.

Vamos por partes.

---

## 1) Respuesta directa

### ✅ No hay ningún problema en usar

* PostgreSQL 18 (EDB installer)
* pgAdmin 4 como GUI

Eso es **100% válido** para desarrollo.

La única diferencia con Homebrew es:

👉 el binario `psql` **no quedó en tu PATH**.

Postgres sí está instalado.
Solo tu terminal no sabe dónde está.

Y pgAdmin funciona perfectamente como reemplazo de la línea de comandos.

---

## 2) ¿Debes desinstalar y usar Homebrew?

### ❌ No es necesario

Ambos funcionan igual:

| EDB + pgAdmin                     | Homebrew                |
| --------------------------------- | ----------------------- |
| GUI incluida                      | CLI first               |
| Muy común en Windows/macOS        | Muy común en macOS      |
| Ideal si vienes de tools gráficas | Ideal si eres CLI-heavy |
| Usa rutas propias                 | Usa `/opt/homebrew`     |

Tu elección actual es perfectamente válida.

Mi consejo:

👉 **Quédate con EDB + pgAdmin.**

Solo ajustamos el flujo.

---

## 3) Por qué `psql` no aparece

EDB instala Postgres normalmente en algo como:

``` bash
/Library/PostgreSQL/18/bin/psql
```

pero NO agrega eso al PATH del sistema.

Por eso:

``` bash
psql --version
```

falla.

No pasa nada.

Puedes:

### Opción A (rápida)

Usar ruta completa:

``` bash
/Library/PostgreSQL/18/bin/psql --version
```

---

### Opción B (mejor)

Agregarlo al PATH:

Edita:

``` bash
nano ~/.zshrc
```

Agrega:

``` bash
export PATH="/Library/PostgreSQL/18/bin:$PATH"
```

Guarda y luego:

``` bash
source ~/.zshrc
```

Ahora:

``` bash
psql --version
```

debe funcionar.

---

## 4) Usando pgAdmin 4 (ajustando mis instrucciones)

Vamos a replicar exactamente lo que íbamos a hacer con CLI, pero en pgAdmin.

---

### Paso 1 — Conectarte al servidor

Abre pgAdmin.

En el panel izquierdo:

``` diagram
Servers
 └ PostgreSQL 18
```

Si no está registrado:

* Click derecho → Register → Server

Usa:

* Host: `localhost`
* Port: `5432`
* Maintenance DB: `postgres`
* Username: `postgres`
* Password: el que pusiste al instalar

---

### Paso 2 — Crear usuario del proyecto

Click derecho sobre:

``` code
Login/Group Roles
```

→ Create → Login/Group Role

#### General

Name:

``` code
myaccounting_user
```

---

#### Definition

Password:

``` code
dev_password
```

---

#### Privileges

Marca:

✅ Can login
✅ Create databases

Save.

---

### Paso 3 — Crear base de datos

Click derecho:

``` code
Databases → Create → Database
```

Name:

``` code
myaccounting_dev
```

Owner:

``` code
myaccounting_user
```

Save.

---

### Paso 4 — Habilitar extensión UUID

Expande:

``` diagram
myaccounting_dev
 → Schemas
 → public
```

Click derecho:

``` code
Query Tool
```

Ejecuta:

``` sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

Lightning icon ⚡

---

### Paso 5 — Pegar el schema completo

En ese mismo Query Tool:

1. Pega TODO el DDL que te entregué.
2. Ejecuta.

Luego refresca:

``` diagram
Schemas → public → Tables
```

Deberías ver:

* ledger_owner
* auth_identity
* ledger
* account
* transaction
* split
* etc.

---

## 5) Diferencias reales entre pgAdmin y psql

### pgAdmin

✅ Visual
✅ Fácil inspeccionar datos
✅ Muy bueno para empezar
❌ Más lento para tareas repetitivas

### psql

✅ Scripting
✅ Automatización
✅ Migraciones CI/CD
❌ Menos amigable

En producción usarás ambos.

Para ahora:

👉 pgAdmin está perfecto.

---

## 6) Recomendación profesional

Quédate con:

* PostgreSQL 18 (EDB)
* pgAdmin 4

Solo agrega `psql` al PATH para cuando lo necesites.

No desinstales.

---

## Próximo paso lógico

Ahora que tienes DB:

👉 crear **primer LedgerOwner + Ledger**
👉 probar inserts básicos
👉 luego backend Java

Si quieres, en el siguiente mensaje te doy:

* script SQL de seed inicial (usuario demo + ledger + cuentas base)

solo dime 👍
