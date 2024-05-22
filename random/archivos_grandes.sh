#!/bin/bash

# Verificar si se han pasado suficientes argumentos
if [ $# -lt 2 ]; then
    echo "Uso: $0 <directorio> <tamaño_minimo>"
    exit 1
fi

# Obtener el directorio de búsqueda y verificar si existe
directorio=$1
if [ ! -d "$directorio" ]; then
    echo "El directorio $directorio no existe."
    exit 1
fi

# Obtener el tamaño mínimo pasado como argumento y convertirlo a bytes
tam_minimo_gib=$2
tam_minimo=$((tam_minimo_gib * 1024 * 1024 * 1024))

# Obtener la fecha actual menos 1 hora en formato Unix timestamp
fecha_limite=$(date -d '1 hour ago' +%s)

# Utilizar el comando `find` para buscar los archivos en el directorio
# que cumplan las condiciones especificadas
archivos_encontrados=$(find "$directorio" -type f -size +"$tam_minimo"c -newermt @"$fecha_limite" 2>/dev/null)

# Mostrar los archivos encontrados
echo "Archivos mayores a $tam_minimo_gib GiB y creados en la última hora en el directorio $directorio:"
echo "$archivos_encontrados"

