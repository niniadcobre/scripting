#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: $0 [text]"
  exit 1
fi

text=$@
text=${text,,} # Convertir todo el texto a minúsculas

# Inicializar variables
declare -A freq
for (( i=97; i<=122; i++ )); do
  freq[$(echo -e "\x$(printf %x $i)")]=0
done

# Contar las letras en el texto
for (( i=0; i<${#text}; i++ )); do
  char=${text:$i:1}
  if [[ $char =~ [a-z] ]]; then
    freq[$char]=$((${freq[$char]} + 1))
  fi
done

# Imprimir los resultados
echo "Frecuencia de aparición de letras:"
for (( i=97; i<=122; i++ )); do
  letter=$(echo -e "\x$(printf %x $i)")
  count=${freq[$letter]}
  if [ $count -gt 0 ]; then
    echo "$letter: $count"
  fi
done

