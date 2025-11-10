#!/bin/bash

# Este script muestra las copias de seguridad disponibles DESDE UN BUCKET DE S3,
# permite al usuario seleccionar una, la descarga y la restaura en un
# directorio especificado.

# --- 1. Cargar Configuración ---
CONFIG_FILE="$HOME/.conf_copia_seg.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: El archivo de configuración '$CONFIG_FILE' no se ha encontrado." >&2
    exit 1
fi

source "$CONFIG_FILE"

# Para esta operación, la variable S3_BUCKET es obligatoria.
if [ -z "$S3_BUCKET" ]; then
    echo "Error: La variable S3_BUCKET no está definida en '$CONFIG_FILE'." >&2
    echo "Esta variable es necesaria para restaurar desde la nube." >&2
    exit 1
fi

# --- 2. Encontrar y Listar Copias Disponibles desde S3 ---
echo "Buscando copias de seguridad en el bucket S3: $S3_BUCKET"

# CAMBIO PRINCIPAL: Usamos 'aws s3 ls' en lugar de 'find'.
# El comando 'aws s3 ls' devuelve fecha, hora, tamaño y nombre.
# Usamos 'awk '{print $4}'' para extraer solo la cuarta columna (el nombre del archivo).
mapfile -t backup_files < <(aws s3 ls "s3://$S3_BUCKET/" | awk '{print $4}' | sort -r)

if [ ${#backup_files[@]} -eq 0 ]; then
    echo "No se han encontrado copias de seguridad en el bucket S3."
    exit 0
fi

# --- 3. Generar y Mostrar el Menú de Selección ---
# Esta sección es casi idéntica, solo trabaja con la lista de nombres de S3.
echo "Por favor, selecciona la copia de seguridad que deseas restaurar desde la nube:"

PS3="Introduce el número de la copia (o 'q' para salir): "

opciones=()
for filename in "${backup_files[@]}"; do
    # Omitimos líneas vacías que a veces 'aws s3 ls' puede generar
    if [ -n "$filename" ]; then
        fecha_hora=$(echo "$filename" | cut -d'_' -f1-2 | sed 's/_/ /')
        tipo=$(echo "$filename" | cut -d'_' -f4 | cut -d'.' -f1)
        opciones+=("Fecha: $fecha_hora  (Tipo: $tipo)")
    fi
done

select opcion_elegida in "${opciones[@]}" "Salir"; do
    if [[ "$REPLY" == "q" || "$opcion_elegida" == "Salir" ]]; then
        echo "Operación cancelada."
        exit 0
    fi

    if [[ "$REPLY" -gt 0 && "$REPLY" -le ${#opciones[@]} ]]; then
        archivo_a_restaurar="${backup_files[$((REPLY-1))]}"
        echo "Has seleccionado restaurar desde la nube: $archivo_a_restaurar"
        break
    else
        echo "Opción no válida. Inténtalo de nuevo."
    fi
done

# --- 4. Solicitar Directorio de Destino ---
# Esta sección no cambia.
echo
read -p "Introduce la ruta completa del directorio donde restaurar la copia: " ruta_destino

if [ -z "$ruta_destino" ]; then
    echo "Error: No se ha especificado una ruta de destino." >&2
    exit 1
fi

if [ ! -d "$ruta_destino" ]; then
    read -p "El directorio '$ruta_destino' no existe. ¿Deseas crearlo? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        mkdir -p "$ruta_destino"
    else
        echo "Restauración cancelada."
        exit 0
    fi
fi

# --- 5. Confirmación, Descarga y Restauración ---
echo
echo "--- RESUMEN DE LA RESTAURACIÓN DESDE S3 ---"
echo "Copia a restaurar: $archivo_a_restaurar"
echo "Restaurar en:      $ruta_destino"
echo "-------------------------------------------"
read -p "¿Estás seguro de que quieres continuar? (s/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
    # Definimos una ubicación temporal para descargar el archivo
    TEMP_DOWNLOAD_PATH="/tmp/$archivo_a_restaurar"
    
    # PASO 1: Descargar el archivo desde S3
    echo "Descargando '$archivo_a_restaurar' desde S3... por favor, espera."
    aws s3 cp "s3://$S3_BUCKET/$archivo_a_restaurar" "$TEMP_DOWNLOAD_PATH"
    
    if [ $? -ne 0 ]; then
        echo "Error: La descarga desde S3 ha fallado." >&2
        exit 1
    fi

    # PASO 2: Extraer el archivo descargado
    echo "Descarga completa. Extrayendo archivos..."
    tar -xzf "$TEMP_DOWNLOAD_PATH" -C "$ruta_destino"

    if [ $? -eq 0 ]; then
        echo "¡Éxito! La copia de seguridad se ha restaurado correctamente en '$ruta_destino'."
    else
        echo "Error: Ocurrió un problema durante la extracción." >&2
    fi

    # PASO 3: Limpiar el archivo temporal
    echo "Limpiando archivo temporal..."
    rm "$TEMP_DOWNLOAD_PATH"
else
    echo "Restauración cancelada por el usuario."
fi

exit 0