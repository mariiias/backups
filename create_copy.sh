#!/bin/bash

# This script performs the automated backup and rotation.
# It is intended to be run by a cron job every minute.

# --- Configuration ---
CONFIG_FILE="$HOME/.conf_copia_seg.txt"


if [ ! -f "$CONFIG_FILE" ]; then
    # Exit silently if directory is not found.
    exit 0
fi

source "$CONFIG_FILE"

if [ ! -d "$SOURCE_DIR" ] || [ ! -d "$DESTINATION_DIR" ]; then
    # Exit silently if directories are not found.
    exit 0
fi

# 3. Determine Backup Type based on "Accelerated Time"
current_minute=$(date +%M)
# Add 1 to minute (0-59 -> 1-60) to avoid issues with mod 0.
n=$((10#$current_minute + 1)) # 10# ensures base-10 interpretation

if (( n % 12 == 0 )); then
    backup_type="mensual"
elif (( n % 4 == 0 )); then
    backup_type="semanal"
else
    backup_type="diaria"
fi

# 4. Create the Backup
timestamp=$(date +%Y-%m-%d_%H-%M-%S)
archive_name="${timestamp}_copia_${backup_type}.tar.gz"
archive_path="${DESTINATION_DIR}/${archive_name}"


echo "Creando backup: $archive_path"
tar -czf "$archive_path" -C "$SOURCE_DIR" .

if [ -n "$S3_BUCKET" ]; then
    ARCHIVO_BACKUP="$archive_path"
    BUCKET_S3="$S3_BUCKET"

    echo "Subiendo $ARCHIVO_BACKUP a S3 (Bucket: $BUCKET_S3)..."
    aws s3 cp "$ARCHIVO_BACKUP" "s3://$BUCKET_S3/"

    if [ $? -eq 0 ]; then
        echo "Backup subido a S3 correctamente."

    else
        echo "ERROR: La subida a S3 ha fallado." >&2
    fi

else
    echo "Info: La variable S3_BUCKET no está configurada. Se omite la subida a S3."
fi


echo "Realizando limpieza de copias antiguas..."

# Mantener las últimas 4 copias DIARIAS
# tail -n +5 significa "empezar a mostrar desde la 5ª línea", es decir, borrar el 5º, 6º, ... más antiguos.
find "$DESTINATION_DIR" -maxdepth 1 -name "*_copia_diaria.tar.gz" -type f | sort -r | tail -n +5 | xargs -r rm
echo "-> Limpieza de copias diarias completada."

# Mantener las últimas 3 copias SEMANALES
# tail -n +4 significa "empezar desde la 4ª línea".
find "$DESTINATION_DIR" -maxdepth 1 -name "*_copia_semanal.tar.gz" -type f | sort -r | tail -n +4 | xargs -r rm
echo "-> Limpieza de copias semanales completada."

# Mantener las últimas 12 copias MENSUALES
# tail -n +13 significa "empezar desde la 13ª línea".
find "$DESTINATION_DIR" -maxdepth 1 -name "*_copia_mensual.tar.gz" -type f | sort -r | tail -n +13 | xargs -r rm
echo "-> Limpieza de copias mensuales completada."

echo "Proceso de backup y rotación finalizado."
echo # Línea en blanco para separar las ejecuciones en el log