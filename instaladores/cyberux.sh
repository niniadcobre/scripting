#!/bin/bash 
# Copyright (C) 2024, Miriam Lechner
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with 
# this program. If not, see <https://www.gnu.org/licenses/>.

#DEBUG=debug

function terminar {
# Código 1: salida a pedido del usuario
# Código 2: salida por situación anormal, sin cambios en sistema 
# Código 3: salida anormal, con cambios en sistema
   case $1 in 
     0) echo "Saliendo, todo OK :D" ;;
     1) echo "Saliendo a pedido del usuario...";;
     2) echo "Saliendo con errores pero sin cambios en sistema. :(";;
     3) echo "Saliendo con errores y cambios parciales, REVISAR SISTEMA :'(" ;;
     *) echo "Salida de error desconocida... reporte el BUG"
   esac 

   #Limpiando 
   [[ -f "$errores" ]] && rm "$errores" 
   [[ -d $mptfat ]] && rmdir $mptfat
   [[ -d $mptext4 ]] && rmdir $mptext4

   exit $1
}

#Verificaciones 
[[ $(id -u) -ne 0 ]] && echo Debe ser root para ejecutar este script && terminar 2
if ! { which tar && which lsblk &&  which fdisk && \
	which e2label ; } >/dev/null 2>&1
then 	
  echo Se requiere: tar, fdisk, lsblk y e2label, instalar para continuar. 
  terminar 2 
fi

PENSIZE=8 #GB 
#Establecer cuál es el dispositivo root para evitar
#problemas y excluirlo de cualquier selección. 
ROOTDEV="/dev/$(lsblk --filter 'MOUNTPOINT == "/"' -o PKNAME --noheading)"

function validar_tamano_pen {
    disp=$1
    minimo=$2 #GB

    # Obtener el tamaño del dispositivo en bytes
    tamano_disp=$(lsblk -bno SIZE $dispositivo)

    if [ $? -ne 0 ]; then
        echo "Error al obtener el tamaño del dispositivo."
        return 1
    fi

    # Convertir tamaño mínimo requerido a bytes
    minimo_bytes=$(($minimo * 1024 * 1024 * 1024))

    if [ $tamano_disp -ge $minimo_bytes ]; then
        echo "El dispositivo $disp tiene al menos $minimo GiB."
        return 0
    else
        echo "El dispositivo $disp no tiene al menos $minimo GiB."
        return 1
    fi
}


function destino {
declare -g DESTINODEV

cat << FIN

Seleccione un dispositivo DESTINO para crear una 
INSTALACIÓN de Cyberux. ADVERTENCIA: el mismo 
PERDERÁ TODO SU CONTENIDO ACTUAL EN EL PROCESO. 
FIN

# Se eliminan el dispositivo de ORIGEN y el ROOTFS del listado de posibles
# destinos para evitar catástrofes 
select disp in $(echo $(lsblk -r --noheadings -p -d -o NAME |egrep -v "$ROOTDEV") salir);do
 [[ "$disp" == "salir" ]] && terminar 1
 echo El dispositivo seleccionado es: "$disp"
 lsblk "$disp"
 echo ¿Es correcta la elección? ¿SI/no? 
 while read resp;do 
   if [[ $resp == SI ]];then 
     break 2
   else break 
   fi 
 done   
done 

echo 
echo Se procederá a destruir la información en "$disp"
echo ¿Está de acuerdo? ¿SI/no? 
while read resp;do 
  if [[ $resp == SI ]];then 
    break 
   else 
    echo Saliendo, sin cambios sobre "$disp"
    terminar 1
   fi 
done   

DESTINODEV="$disp"
[[ ! -b "$DESTINODEV" ]] && echo Destino inválido && terminar 2

if ! validar_tamano_pen $DESTINODEV $PENSIZE >/dev/null 2>&1 ;then
   cat <<_FIN_
   ADVERTENCIA: el dispositivo "$DESTINODEV" parece 
   tener un tamaño inferior al requerido ($PENSIZE GiB). 
   Puede que la instalación quede corrupta.    
   ¿Desea continuar de todos modos? 
_FIN_
fi 
while read resp;do 
 if [[ $resp == SI ]];then 
    break 
 else 
   echo Saliendo, tamaño insuficiente $DESTINODEV.  
   terminar 1
 fi 
done   

}

function validar_targz {
   tar tvfz "$1"  >/dev/null 2>&1 
}

function origen {

    declare -g fatarch ext4arch
    echo Indique la ruta al archivo TAR.GZ de FAT 
    read fatarch 
    if !( [[ -f "$fatarch" ]] && validar_targz "$fatarch" );then 
        echo Archivo inválido prar FAT, debe ser tar.gz 
	terminar 1
    fi 	

    echo Indique la ruta al archivo TAR.GZ de EXT4 	 
    read ext4arch 
    if !( [[ -f "$ext4arch" ]] && validar_targz "$ext4arch" );then 
        echo Archivo inválido para EXT4, debe ser tar.gz 
	terminar 1
    fi 	
}

function particionar_destino {

# Intentamos desmontar particiones del destino 
for mpt in $(lsblk --noheading -r -p -o MOUNTPOINTS "$DESTINODEV");do
  echo Desmontando $mpt 
  if ! umount $mpt;then 
    echo No fue posible desmontar $mpt
    terminar 2
  fi
done 

errores=$(mktemp || echo /tmp/logcyberux.$$)
echo 
echo Escribiendo nueva tabla de particiones en "$DESTINODEV" 
# Eliminar cualquier tabla de partición existente
echo -e "o\nw" | fdisk "$DESTINODEV" > /dev/null 2>$errores
partOK=$?

# Crear la partición FAT de 40M
echo -e "n\np\n1\n\n+40M\nt\nb\nw" | fdisk "$DESTINODEV" > /dev/null 2>>$errores
partOK=$(( $? && $partOK ))

# Crear la partición SWAP de 1G
echo -e "n\np\n1\n\n+1G\nt\nb\nw" | fdisk "$DESTINODEV" > /dev/null 2>>$errores
partOK=$(( $? && $partOK ))

# Crear la partición EXT4 con el resto del espacio
echo -e "n\np\n2\n\n\nw" | fdisk "$DESTINODEV" > /dev/null 2>$errores
partOK=$(( $? && $partOK ))

partprobe "$DESTINODEV" > /dev/null 2>$errores
partOK=$(( $? && $partOK ))

if [[ $partOK -ne 0 ]] ;then
 echo Se encontaron los siguientes errores al particionar: 
 cat $errores 
 echo ¿Desea continuar de todos modos? SI/no
 while read resp;do 
 if [[ $resp == SI ]];then 
    break 
 else 
   echo Saliendo, problemas para particionar $DESTINODEV
   terminar 3
 fi 
 done   
fi 	

echo Tabla de particiones creada... 
lsblk "$DESTINODEV"

}

cat << FIN

Este script fue creado para instalar la distribución
Cyberux (basada en Alpine para máquinas pequeñas con 
espíritu minimalista/cyberciruja). 
FIN

# Determinar dispositivos de destino. 
origen 
destino 

particionar_destino 

# Determinar las particiones para cada destino
DESTDEVFAT=$(lsblk  -r -o PATH,TYPE "${DESTINODEV}" |grep part |sed -e 's/part//' -e 's/ //'| sed '1q;d' )
DESTDEVSWAP=$(lsblk  -r -o PATH,TYPE "${DESTINODEV}" |grep part |sed -e 's/part//' -e 's/ //'| sed '2q;d')
DESTDEVEXT4=$(lsblk  -r -o PATH,TYPE "${DESTINODEV}" |grep part |sed -e 's/part//' -e 's/ //'| sed '3q;d')

echo 
echo Creando sistemas de archivo en "$DESTDEVLIVE" para FAT32
mptfat=$(mktemp -d || echo /tmp/FAT$$)
mkfs.fat -F32 "$DESTDEVFAT"
echo Montando "$DESTDEVFAT"
[[ ! -d $mptfat ]] && mkdir $mptfat
if ! mount "$DESTDEVFAT" $mptfat ;then 
	echo No fue posible montar $DESTDEVFAT en $mptfat, saliendo
	terminar 3
fi 

echo Copiando archivos a $mptfat, puede tomar un tiempo
## AGREGAR TAR EXTRACT AQUI

echo
echo Creando SWAP en "$DESTDEVSWAP" 
mkswap "$DESTDEVSWAP"


echo
echo Creando sistemas de archivo en "$DESTDEVEXT4" para Cyberux 
echo puede tomar varios minutos... 
mptext4=$(mktemp -d || echo /tmp/EXT4$$ )
mkfs.ext4  "$DESTDEVEXT4"
echo Montando "$DESTDEVEXT4" 
[[ ! -d "$mptext4" ]] && mkdir "$mptext4"
if ! mount "$DESTDEVEXT4" $mptext4 ;then 
   echo No fue posible montar $DESTDEVEXT4 en $mptext4, saliendo
   terminar 3
fi 
echo Copiando de origen a $mptpers, puede tomar un tiempo
## AGREGAR TAR EXTRACT AQUI

echo Desmontando, espere, en unos minutos terminaremos
umount "$DESTDEVFAT" &
umount "$DESTDEVEXT4" &
wait 


echo VIVA EL ESPÍRITU CYBERCIRUJA! && TERMINAR 0

# TODO:  
# 1) recibir como opciones dispositivo de origen y destino para evitar
# menu de preguntas. 
# 2) Asociar mejor las verificaciones 
# 3) Verificar que las variables DESTDEVLIVE y DESTDEVPERS estén definidas
# 4) Faltaría verificar que la capacidad del pendrive sea acorde, 8GB o mas 
# 5) Mejorar en general la estética de los mensajes, colores etc. 
# 6) Interfaz con dialog 
