#!/bin/bash 

eval var='$'$1

case $1 in
  '#')  echo El número de parámetros posicionales es $var ;;
  '@')  echo Los parámetros posicionales son: $var ;;
  '$')  echo El PID del script actual es: $var;;
  PATH) echo Los directorios de búsqueda de binarios son: $var;;
  HOME) echo El directorio de inicio es: $var;;
  PWD)  echo El directorio de trabajo actual es: $var;;
  PS1)  echo El prompt de primer nivel es: $var;;
   "-h")  echo Invocar ejemplo: $0 \"\#\" ;;
  *)    echo El valor de la variable $1 es $var;;
esac
