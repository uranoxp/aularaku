# Moodle 5.2 en Dokploy para `aula.academiamirai.mx`

Este repo prepara un despliegue reproducible de **Moodle 5.2.x** sobre **Dokploy** usando **Docker Compose**, con `PHP-FPM 8.3`, `MariaDB 10.11`, `Redis 7`, `Nginx` y un contenedor separado para `cron`.

La arquitectura esta adaptada al cambio introducido desde Moodle 5.1:

```text
document root => /var/www/moodle/public
```

## Que incluye

- Imagen PHP construida desde el Git oficial de Moodle (`MOODLE_502_STABLE` por defecto).
- Volumen persistente compartido para `/var/www/moodle`, visible para `php`, `nginx` y `cron`.
- `config.php` generado automaticamente en el arranque y persistido fuera de la imagen.
- Instalacion inicial por CLI con comportamiento idempotente.
- Redis configurado desde `config.php` para sesiones.
- Scripts de backup y restauracion para codigo, DB, `moodledata` y `config.php`.

## Estructura

```text
.
├─ docker-compose.yml
├─ .env.example
├─ docker/
│  ├─ nginx/default.conf
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

## Variables principales

1. Copia `.env.example` a `.env`.
2. Cambia al menos estas variables:

```text
MOODLE_URL
MOODLE_ADMIN_PASSWORD
MOODLE_ADMIN_EMAIL
MOODLE_DB_PASSWORD
MOODLE_DB_ROOT_PASSWORD
```

Tambien conviene revisar:

```text
MOODLE_SITE_FULLNAME
MOODLE_SITE_SHORTNAME
MOODLE_SUPPORT_EMAIL
REDIS_SESSION_PREFIX
```

## Flujo de arranque

En el primer deploy:

1. `php` espera a MariaDB y Redis.
2. Si el volumen `moodle_code` esta vacio, lo siembra desde la copia oficial incluida en la imagen.
3. Genera `config.php` en `/var/www/moodle-state/config.php`.
4. Crea o actualiza el enlace simbolico hacia `/var/www/moodle/config.php`.
5. Verifica si la tabla `${MOODLE_DB_PREFIX}config` ya existe.
6. Si no existe y `MOODLE_AUTO_INSTALL=1`, ejecuta `admin/cli/install_database.php`.
7. Ajusta timezone via `admin/cli/cfg.php`.
8. Limpia el `lastip` del admin para evitar el error `installhijacked`.
9. Arranca `php-fpm`.

En redeploys posteriores:

```text
no reinstala
reusa codigo, base de datos, moodledata y config.php
```

## Despliegue en Dokploy

### 1. Crear el servicio

En Dokploy:

```text
1. Create Project -> academiamirai
2. Add Service -> Docker Compose
3. Conectar este repositorio
4. Cargar variables desde .env
5. Deploy
```

### 2. Configurar dominio

En la pestana **Domains** del servicio:

```text
Domain: aula.academiamirai.mx
Service: nginx
Port: 80
HTTPS: enabled
```

No agregues labels manuales de Traefik si usas esta seccion de Dokploy.

### 3. Configurar DNS

En tu proveedor DNS:

```text
Type: A
Host: aula
Value: IP_DEL_VPS
TTL: 300
```

## Verificaciones recomendadas

- `https://aula.academiamirai.mx` responde sin 404.
- El root publicado corresponde a `/var/www/moodle/public`.
- La instalacion por CLI no se repite en un redeploy.
- Plugins y temas instalados desde la UI sobreviven a reinicios y redeploys.
- `cron` ejecuta `admin/cli/cron.php` cada minuto.
- Redis responde y se usa como backend de sesiones.
- La subida de archivos respeta los limites definidos en `.env`.

## Operacion diaria

### Ver contenedores

```bash
docker compose ps
```

### Ver logs

```bash
docker compose logs -f nginx
docker compose logs -f php
docker compose logs -f mariadb
docker compose logs -f cron
```

### Ejecutar cron manual

```bash
docker compose exec php php /var/www/moodle/admin/cli/cron.php
```

### Revisar configuracion actual

```bash
docker compose exec php php /var/www/moodle/admin/cli/cfg.php --list
```

### Ver version del core persistido

```bash
./scripts/show-code-version.sh
```

## Backups

### Archivos incluidos

Los scripts de este repo cubren:

```text
- Codigo persistente de Moodle
- Base de datos
- moodledata
- config.php persistido
- copia local de .env si existe
```

Por defecto, los respaldos se guardan en:

```text
/srv/backups/aulamirai
```

### Ejecutar backup completo

```bash
./scripts/full-backup.sh
```

### Respaldar solo el codigo persistente

```bash
./scripts/backup-code.sh
```

### Restaurar base de datos

```bash
./scripts/restore-db.sh /srv/backups/aulamirai/moodle-db-AAAA-MM-DD_hh-mm-ss.sql.gz
```

### Restaurar moodledata

```bash
./scripts/restore-moodledata.sh /srv/backups/aulamirai/moodledata-AAAA-MM-DD_hh-mm-ss.tar.gz
```

### Restaurar config.php

```bash
./scripts/restore-config.sh /srv/backups/aulamirai/moodle-config-AAAA-MM-DD_hh-mm-ss.tar.gz
```

### Restaurar codigo persistente

```bash
./scripts/restore-code.sh /srv/backups/aulamirai/moodle-code-AAAA-MM-DD_hh-mm-ss.tar.gz
```

## Actualizacion de Moodle

Los redeploys normales no actualizan el core persistido automaticamente.

Flujo recomendado:

1. Cambia `MOODLE_GIT_REF` en `.env`.
2. Redeploy en Dokploy para construir la nueva imagen.
3. Verifica la version embebida disponible:

```bash
./scripts/show-code-version.sh
```

4. Sincroniza manualmente el core nuevo al volumen persistido y ejecuta `upgrade.php`:

```bash
./scripts/upgrade-core.sh
```

5. Verifica el sitio y ejecuta cron.

### Re-sembrar codigo si el volumen esta vacio

```bash
./scripts/seed-code.sh
```

## Restricciones importantes

- El codigo de Moodle ahora es persistente y forma parte del estado operativo del sitio.
- Plugins y temas instalados desde Moodle sobreviven a reinicios y redeploys.
- Los redeploys normales no actualizan el core del volumen; el upgrade se hace manualmente con `./scripts/upgrade-core.sh`.
- `config.php` no se crea desde el navegador; lo genera el entrypoint.
- El mapping de caches de aplicacion de Moodle puede hacerse despues desde la UI. La infraestructura ya deja Redis operativo para sesiones desde el inicio.
