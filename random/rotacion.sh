#!/bin/bash

# Función para rotar las imágenes JPG en un directorio
rotate_images() {
    # Se mueve al directorio especificado
    cd "$1"
    # Se recorren todos los archivos JPG en el directorio
    for file in *.jpg; do
        # Se rota la imagen 90 grados en sentido horario
        convert "$file" -rotate -90 "$file"
        echo "Rotating $file ..."
    done
    # Se regresa al directorio anterior
    cd -
}

# Se recorren todos los argumentos pasados al script (los directorios)
for dir in "$@"; do
    # Se llama a la función rotate_images para rotar las imágenes en cada directorio
    rotate_images "$dir"
done

