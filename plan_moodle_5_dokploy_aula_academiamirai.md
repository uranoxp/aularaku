# Plan maestro para Codex
## Despliegue de Moodle 5.2 con Dokploy en `aula.academiamirai.mx`

**Proyecto:** Aula Academia Mirai  
**Dominio:** `https://aula.academiamirai.mx`  
**Stack implementado:** Dokploy + Docker Compose + Nginx + PHP-FPM + MariaDB + Redis + Cron  
**Version objetivo:** Moodle 5.2.x  
**Referencia Git por defecto:** `MOODLE_520_STABLE`  
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
- Backups de DB + moodledata + config.php
```

---

## 2. Cambio clave respecto a Moodle 5.0

Desde Moodle 5.1, Moodle mueve el contenido web accesible a `public/`.

Por eso, para Moodle 5.2:

```text
NO usar /var/www/html
SI usar /var/www/moodle/public
```

La imagen de `php` contiene el arbol completo de Moodle en:

```text
/var/www/moodle
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
MariaDB + Redis + moodledata + config persistido
```

---

## 5. Decisiones implementadas en el repositorio

### 5.1 Codigo inmutable

El core de Moodle ya no vive en un volumen Docker. Ahora va dentro de las imagenes construidas desde Git oficial.

Consecuencia:

```text
- No existe volumen moodle_code
- php y cron comparten la misma imagen base
- nginx usa otra imagen derivada del mismo build
- plugins o temas personalizados deben entrar por build
```

### 5.2 Estado persistente

El estado mutable queda separado en volumenes:

```text
- moodledata
- moodle_config
- mariadb_data
- redis_data
```

`moodle_config` guarda `config.php` generado en runtime.

### 5.3 Bootstrap idempotente

En el primer arranque:

```text
1. php espera MariaDB y Redis
2. genera config.php
3. revisa si la base ya esta instalada
4. si no existe, ejecuta admin/cli/install_database.php
5. aplica timezone y corrige el caso installhijacked
6. arranca php-fpm
```

En redeploys posteriores:

```text
no reinstala
solo reusa config.php y la base ya existente
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
│     ├─ entrypoint.sh
│     └─ opcache.ini
└─ scripts/
   ├─ backup-config.sh
   ├─ backup-db.sh
   ├─ backup-moodledata.sh
   ├─ full-backup.sh
   ├─ restore-config.sh
   ├─ restore-db.sh
   └─ restore-moodledata.sh
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

### 7.4 Backups

El flujo minimo de restauracion ya contempla:

```text
- Base de datos
- moodledata
- config.php persistido
```

Adicionalmente, `full-backup.sh` guarda una copia de `.env` local si existe.

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
