#!/bin/bash

frecuencia_letras() {
    archivo=$1
    declare -A letras

    while IFS= read -r -n1 letra; do
        if [[ $letra =~ [[:alpha:]] ]]; then
            letras[$letra]=$((letras[$letra]+1))
        fi
    done < "$archivo"

    echo "Frecuencia de letras en el archivo $archivo:"
    for letra in "${!letras[@]}"; do
        echo "$letra: ${letras[$letra]}"
    done |sort -n -k2
}

mostrar_ayuda() {
    # Muestra la función de ayuda
    echo "Uso: script.sh [opciones]"
    echo "-g        Habilita el modo debug."
    echo "-h        Muestra la ayuda."
    echo "-a <archivo>    Invoca la función frecuencia_letras con el archivo especificado."
    echo "-d <directorio> Invoca la función frecuencia_letras con todos los archivos dentro del directorio especificado."
    exit 0
}

# Verificar si no se proporcionaron argumentos
if [ $# -eq 0 ]; then
    mostrar_ayuda
fi

modo_debug=false

# Interpretar los argumentos de entrada
while getopts "gha:d:" opcion; do
    case "${opcion}" in
        g)
            modo_debug=true
            ;;
        h)
            mostrar_ayuda
            ;;
        a)
            archivo=${OPTARG}
            frecuencia_letras "${archivo}"
            exit 0
            ;;
        d)
            directorio=${OPTARG}
            archivos="${directorio}/*"
            for archivo in ${archivos}; do
                if [ -f "${archivo}" ]; then
                    frecuencia_letras "${archivo}"
                fi
            done
            exit 0
            ;;
        *)
            mostrar_ayuda
            ;;
    esac
done

