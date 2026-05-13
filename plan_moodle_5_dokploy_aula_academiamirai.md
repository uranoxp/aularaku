# Plan maestro para Codex
## Despliegue de Moodle 5.2 con Dokploy en `aula.academiamirai.mx`

**Proyecto:** Aula Academia Mirai  
**Dominio:** `https://aula.academiamirai.mx`  
**Stack implementado:** Dokploy + Docker Compose + Nginx + PHP-FPM + MariaDB + Redis + Cron  
**Version objetivo:** Moodle 5.2.x  
**Referencia Git por defecto:** `MOODLE_502_STABLE`  
**Zona horaria:** `America/Mexico_City`

---

## 1. Objetivo

Este proyecto ya no apunta a Moodle 5.0. La implementacion actual queda alineada con **Moodle 5.2**, que al **12 de mayo de 2026** es una rama estable vigente y con mejor vida util para un despliegue nuevo.

La entrega genera un stack listo para Dokploy con estas decisiones:

```text
- Moodle 5.2.x
- PHP-FPM 8.3
- MariaDB 10.11
- Redis 7
- Nginx con root en /var/www/moodle/public
- Instalacion inicial automatizada por CLI
- Config.php generado en runtime y persistido fuera de la imagen
- Cron separado
- Backups de codigo + DB + moodledata + config.php
```

---

## 2. Cambio clave respecto a Moodle 5.0

Desde Moodle 5.1, Moodle mueve el contenido web accesible a `public/`.

Por eso, para Moodle 5.2:

```text
NO usar /var/www/html
SI usar /var/www/moodle/public
```

El sitio publicado vive en:

```text
/var/www/moodle
```

La imagen conserva una copia maestra para seed inicial y upgrade manual en:

```text
/opt/moodle-dist
```

Y Nginx sirve el sitio desde:

```text
/var/www/moodle/public
```

---

## 3. Estado de soporte tomado para esta implementacion

Referencia oficial tomada al **12 de mayo de 2026**:

```text
Moodle 5.0  -> soporte general terminado el 20 de abril de 2026
Moodle 5.1  -> soporte general hasta el 5 de octubre de 2026
Moodle 5.2  -> soporte general hasta el 19 de abril de 2027
Moodle 5.3  -> siguiente LTS, aun no disponible
```

Por eso este proyecto queda en `5.2` y no espera a `5.3`.

---

## 4. Arquitectura final

```text
Internet
   ↓
DNS aula.academiamirai.mx
   ↓
VPS
   ↓
Dokploy / Traefik
   ↓
Servicio nginx:80
   ↓
PHP-FPM
   ↓
Moodle 5.2 (/var/www/moodle/public)
   ↓
MariaDB + Redis + moodle_code + moodledata + config persistido
```

---

## 5. Decisiones implementadas en el repositorio

### 5.1 Codigo persistente compartido

El core de Moodle ya no se usa como arbol efimero en runtime. Ahora el sitio usa un volumen persistente compartido en `/var/www/moodle`.

Consecuencia:

```text
- Existe volumen moodle_code
- php, nginx y cron comparten el mismo arbol de codigo
- plugins y temas instalados desde Moodle sobreviven a redeploys
- el core embebido en la imagen se usa para seed inicial y upgrades manuales
```

### 5.2 Estado persistente

El estado mutable queda separado en volumenes:

```text
- moodle_code
- moodledata
- moodle_config
- mariadb_data
- redis_data
```

`moodle_config` guarda `config.php` generado en runtime.

### 5.3 Bootstrap idempotente

En el primer arranque:

```text
1. php siembra moodle_code desde la imagen si el volumen esta vacio
2. php espera MariaDB y Redis
3. genera config.php
4. revisa si la base ya esta instalada
5. si no existe, ejecuta admin/cli/install_database.php
6. aplica timezone y corrige el caso installhijacked
7. cierra adminsetuppending para no depender del paso final web
8. arranca php-fpm
```

En redeploys posteriores:

```text
no reinstala
no sobreescribe plugins o temas del volumen
solo reusa codigo, config.php y la base ya existente
```

---

## 6. Estructura final del proyecto

```text
.
├─ docker-compose.yml
├─ .env.example
├─ README.md
├─ docker/
│  ├─ nginx/
│  │  └─ default.conf
│  └─ php/
│     ├─ Dockerfile
│     ├─ code-version.sh
│     ├─ entrypoint.sh
│     ├─ opcache.ini
│     ├─ seed-code.sh
│     └─ sync-core.sh
└─ scripts/
   ├─ backup-code.sh
   ├─ backup-config.sh
   ├─ backup-db.sh
   ├─ backup-moodledata.sh
   ├─ full-backup.sh
   ├─ restore-code.sh
   ├─ restore-config.sh
   ├─ restore-db.sh
   ├─ restore-moodledata.sh
   ├─ seed-code.sh
   ├─ show-code-version.sh
   └─ upgrade-core.sh
```

---

## 7. Notas operativas

### 7.1 Dokploy

Seguir usando:

```text
Dokploy -> Docker Compose
```

Sin labels manuales de Traefik si el dominio se configura desde la pestana **Domains**.

### 7.2 DNS

Mantener:

```text
Tipo: A
Nombre: aula
Valor: IP_DEL_VPS
```

### 7.3 Redis

La implementacion deja Redis definido desde variables y configurado en `config.php` para sesiones. El mapeo fino de caches de aplicacion puede hacerse despues desde la administracion de Moodle sin cambiar la infraestructura.

### 7.4 Proxy y SSL

Para Dokploy + Traefik con un unico dominio publico, la configuracion recomendada es:

```text
MOODLE_REVERSE_PROXY=0
MOODLE_SSL_PROXY=1
```

En este escenario, `sslproxy` debe permanecer activo por la terminacion TLS en Traefik, pero `reverseproxy` debe quedar desactivado para evitar el error `reverseproxyabused`.

### 7.5 Backups

El flujo minimo de restauracion ya contempla:

```text
- Codigo persistente
- Base de datos
- moodledata
- config.php persistido
```

Adicionalmente, `full-backup.sh` guarda una copia de `.env` local si existe.

Ruta por defecto de respaldos en el host:

```text
/srv/backups/aulamirai
```

---

## 8. Referencias oficiales usadas

- Moodle Releases: https://moodledev.io/general/releases
- Moodle 5.2 Release Notes: https://moodledev.io/general/releases/5.2
- Moodle 5.2 Code Restructure: https://moodledev.io/docs/5.2/guides/restructure
- Moodle Installing Moodle: https://docs.moodle.org/en/Installing_Moodle
- Moodle CLI scripts: https://docs.moodle.org/en/CLI_scripts
- Moodle Redis session handling: https://docs.moodle.org/en/Session_handling
- Dokploy Docker Compose: https://docs.dokploy.com/docs/core/docker-compose
- Dokploy Docker Compose Domains: https://docs.dokploy.com/docs/core/docker-compose/domains
