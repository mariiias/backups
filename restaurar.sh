#!/bin/bash

# Este script muestra las copias de seguridad disponibles,
# permite al usuario seleccionar una y la restaura en un
# directorio especificado.

# --- 1. Cargar Configuración ---
CONFIG_FILE="$HOME/.conf_copia_seg.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: El archivo de configuración '$CONFIG_FILE' no se ha encontrado." >&2
    echo "Por favor, ejecuta primero el script 'configurar_copia_seg.sh'." >&2
    exit 1
fi

# Carga las variables DESTINATION_DIR y SOURCE_DIR del archivo
source "$CONFIG_FILE"

if [ -z "$DESTINATION_DIR" ] || [ ! -d "$DESTINATION_DIR" ]; then
    echo "Error: El directorio de backups '$DESTINATION_DIR' no es válido o no existe." >&2
    exit 1
fi

# --- 2. Encontrar y Listar Copias Disponibles ---
echo "Buscando copias de seguridad en: $DESTINATION_DIR"

# Creamos un array con las rutas de los backups, ordenados del más nuevo al más viejo.
# mapfile es una forma segura de leer líneas en un array.
mapfile -t backup_files < <(find "$DESTINATION_DIR" -maxdepth 1 -name "*_copia_*.tar.gz" | sort -r)

if [ ${#backup_files[@]} -eq 0 ]; then
    echo "No se han encontrado copias de seguridad."
    exit 0
fi

# --- 3. Generar y Mostrar el Menú de Selección ---
echo "Por favor, selecciona la copia de seguridad que deseas restaurar:"

# PS3 es el prompt que se mostrará al usuario en el menú 'select'
PS3="Introduce el número de la copia (o 'q' para salir): "

# Generamos las opciones del menú con formato amigable
opciones=()
for file in "${backup_files[@]}"; do
    # Extraemos el nombre del archivo sin la ruta
    filename=$(basename "$file")
    # Parseamos el nombre para obtener fecha, hora y tipo
    fecha_hora=$(echo "$filename" | cut -d'_' -f1-2 | sed 's/_/ /')
    tipo=$(echo "$filename" | cut -d'_' -f4 | cut -d'.' -f1)
    # Añadimos la opción formateada al array de opciones
    opciones+=("Fecha: $fecha_hora  (Tipo: $tipo)")
done

select opcion_elegida in "${opciones[@]}" "Salir"; do
    if [[ "$REPLY" == "q" || "$opcion_elegida" == "Salir" ]]; then
        echo "Operación cancelada."
        exit 0
    fi

    # Validamos que la opción sea un número y esté en el rango correcto
    if [[ "$REPLY" -gt 0 && "$REPLY" -le ${#opciones[@]} ]]; then
        # El índice del array es REPLY - 1
        archivo_a_restaurar="${backup_files[$((REPLY-1))]}"
        echo "Has seleccionado restaurar: $(basename "$archivo_a_restaurar")"
        break # Salimos del bucle 'select' una vez elegida una opción válida
    else
        echo "Opción no válida. Inténtalo de nuevo."
    fi
done

# --- 4. Solicitar Directorio de Destino ---
echo
read -p "Introduce la ruta completa del directorio donde restaurar la copia: " ruta_destino

# Comprobamos que el usuario ha introducido algo
if [ -z "$ruta_destino" ]; then
    echo "Error: No se ha especificado una ruta de destino." >&2
    exit 1
fi

# Si el directorio no existe, preguntamos si se debe crear
if [ ! -d "$ruta_destino" ]; then
    read -p "El directorio '$ruta_destino' no existe. ¿Deseas crearlo? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        mkdir -p "$ruta_destino"
        if [ $? -ne 0 ]; then
            echo "Error: No se pudo crear el directorio '$ruta_destino'." >&2
            exit 1
        fi
        echo "Directorio creado con éxito."
    else
        echo "Restauración cancelada."
        exit 0
    fi
fi

# --- 5. Confirmación Final y Restauración ---
echo
echo "--- RESUMEN DE LA RESTAURACIÓN ---"
echo "Copia a restaurar: $(basename "$archivo_a_restaurar")"
echo "Restaurar en:      $ruta_destino"
echo "------------------------------------"
read -p "¿Estás seguro de que quieres continuar? (s/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Restaurando... por favor, espera."
    
    # Comando tar para extraer (-x) desde un archivo comprimido con gzip (-z), 
    # especificando el archivo (-f) y el directorio de destino (-C).
    tar -xzf "$archivo_a_restaurar" -C "$ruta_destino"
    
    if [ $? -eq 0 ]; then
        echo "¡Éxito! La copia de seguridad se ha restaurado correctamente en '$ruta_destino'."
    else
        echo "Error: Ocurrió un problema durante la restauración." >&2
        exit 1
    fi
else
    echo "Restauración cancelada por el usuario."
fi

exit 0
