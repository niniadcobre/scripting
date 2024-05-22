#!/bin/bash 

# El siguiente script busca archivos que contengan shell scripts 
# escritos en bash dentro de un listado de 
# paquetes, ya sea provistos dentro de un 
# archivo o como lista de nombres separadas por espacio. 
# Carece de verificaciones básicas y está creado a los
# fines específicos de la materia. 

declare -u resp

function buscarscript(){
   
   if ! dpkg -l $1 &> /dev/null; then
     echo "$1 no instalado"
     return 
   fi
   echo $1 
   dpkg -L $1 | while read archivo; do
      a=`file "$archivo"|grep "Bourne-Again"|cut -f1 -d:`
      if [[ -n "$a" ]];then  echo "    $a";fi 
   done   
}


if [[ $# -eq 0 ]];then 
   echo -n "Se creará un listado para todos los paquetes instalados en el sistema, ¿esta de acuerdo? S/N "
   read resp 
   if [[ "$resp" == "N" ]];then 
	echo "Saliendo..." 
	exit 1 
   elif [[ "$resp" != "S" ]];then 
	echo "Respuesta inválida, saliendo..."
        exit 2
   fi 
   #Crear listado para todos los paquetes del sistema 
   dpkg -l |awk '$1=="ii" {print $2}'|while read pkg; do
      buscarscript $pkg 
   done 
elif [[ -f "$1" ]];then
   # Si el primer argumento es un archivo regular, se asume que contiene una
   #lista de nombres de paquetes separada por nueva linea, sin lineas vacías. 
   while read pkg;do
      buscarscript $pkg 
   done < $1 
else
   #Asume que los argumentos son un listado de nombres de paquetes
   while [[ $# -gt 0 ]];do
	buscarscript $1
	shift
   done 
fi 
