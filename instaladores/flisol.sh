#!/bin/bash 
# Copyright (C) 2024, Miriam Lechner
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.# You should have received a copy of the GNU General Public License along with 
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
   exit $1
}

#Verificaciones 
[[ $(id -u) -ne 0 ]] && echo Debe ser root para ejecutar este script && terminar 2
if ! ( which lsblk >/dev/null &&  which fdisk >/dev/null && which e2label >/dev/null )
then 	
  echo Se requiere: fdisk, lsblk y e2label, instalar para continuar. 
  terminar 2 
fi

#Establecer cuál es el dispositivo root para evitar
#problemas y excluirlo de cualquier selección. 
ROOTDEV="/dev/$(lsblk --filter 'MOUNTPOINT == "/"' -o PKNAME --noheading)"

function origen {
declare -g ORIGENLIVE ORIGENPERS ORIGENDEV

cat << FIN 
   Seleccione el dispositivo ORIGEN a partir del cual 
   realizará la copia a un nuevo dispositivo. El mismo
   deberá contener una partición FAT con la imagen 
   Debian-Live y una segunda partición EXT4 donde se 
   guardan los archivos persistentes. 
FIN

#Eliminamos ROOTFS para evitar errores. 
select disp in $(echo $(lsblk -r --noheadings  -p -d -o NAME |grep -v $ROOTDEV) salir);do
    [[ "$disp" == "salir" ]] && terminar 1
    lsblk --noheading -r -p -o MOUNTPOINTS "$disp"
    echo "El dispositivo seleccionado es: "$disp" ¿Es correcto? (SI/no)"
    while read resp;do 
       if [[ $resp == SI ]];then 
	break 2
       else 
	break 
       fi 
    done 
cat << FIN 

Seleccione el dispositivo ORIGEN a partir del cual 
realizará la copia a un nuevo dispositivo. 
FIN
done 

# El script asume que la primer partición del disco tiene la imagen
# live y la segunda partición la información de persistencia
ORIGENLIVE=$(lsblk  -r -o MOUNTPOINT,TYPE "${disp}" |grep part |sed -e 's/part//' |head -1)
ORIGENPERS=$(lsblk  -r -o MOUNTPOINT,TYPE "${disp}" |grep part |sed -e 's/part//' |tail -1)
ORIGENDEV=${disp}

if [[ -z "$ORIGENLIVE" ]] || [[ -z "$ORIGENPERS" ]] || [[ -z "$ORIGENDEV" ]];
then 
   echo No se pudo especificar el origen, saliendo... 
   terminar 2
fi
}

function destino {
declare -g DESTINODEV

cat << FIN

Seleccione un dispositivo DESTINO para crear una 
imagen de Debian-Live con persistencia. 
ADVERTENCIA: el mismo perderá TODO su contenido 
actual en el proceso. 
FIN

# Se eliminan el dispositivo de ORIGEN y el ROOTFS del listado de posibles
# destinos para evitar catástrofes 
select disp in $(echo $(lsblk -r --noheadings -p -d -o NAME |egrep -v "$ROOTDEV|$ORIGENDEV" ) salir);do
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
[[ -z "$DESTINODEV " ]] && echo Destino inválido && terminar 2
}

cat << FIN

Este script fue creado para FLISOL 2024 UNCOMA Neuquén 
El mismo sirve para copiar un pendrive armado LIVE con 
persistencia a un nuevo pendrive con iguales características. 
Se requiere de: * un pendrive ORIGEN con los datos de la 
                distribución a copiar.
                * un pendrive DESTINO de al menos 8GB de capacidad
                QUE SERÁ BORRADO EN SU TOTALIDAD para crear una 
		replica del origen.  
FIN

# Determinar dispositivos de origen y de destino. 
origen 
destino  

# Intentamos desmontar particiones del destino 
for mpt in $(lsblk --noheading -r -p -o MOUNTPOINTS "$DESTINODEV");do
  echo Desmontando $mpt 
  if ! umount $mpt;then 
    echo No fue posible desmontar $mpt
    terminar 2
  fi
done 

echo 
echo Escribiendo nueva tabla de particiones en "$DESTINODEV" 
# Eliminar cualquier tabla de partición existente
echo -e "o\nw" | fdisk "$DESTINODEV" > /dev/null 2>&1

# Crear la partición FAT de 5GB
echo -e "n\np\n1\n\n+5G\nt\nb\nw" | fdisk "$DESTINODEV" > /dev/null 2>&1

# Crear la partición EXT4 con el resto del espacio
echo -e "n\np\n2\n\n\nw" | fdisk "$DESTINODEV" > /dev/null 2>&1

partprobe "$DESTINODEV" > /dev/null 2>&1

echo Tabla de particiones creada... 
lsblk "$DESTINODEV"

DESTDEVLIVE=$(lsblk  -r -o PATH,TYPE "${DESTINODEV}" |grep part |sed -e 's/part//' \
	-e 's/ //'|head -1)
DESTDEVPERS=$(lsblk  -r -o PATH,TYPE "${DESTINODEV}" |grep part |sed -e 's/part//' \
        -e 's/ //'|tail -1)

echo
mptlive=/tmp/FATLIVE/
echo Creando sistemas de archivo en "$DESTDEVLIVE" para LIVE
mkfs.fat -F32 "$DESTDEVLIVE"
echo Montando "$DESTDEVLIVE"
[[ ! -d $mptlive ]] && mkdir $mptlive
if ! mount "$DESTDEVLIVE" $mptlive ;then 
	echo No fue posible montar $DESTDEVLIVE en $mptlive, saliendo
	terminar 3
fi 
cd ${ORIGENLIVE}
echo Copiando de origen a $mptlive, puede tomar un tiempo
cp -a . $mptlive/ 2>/dev/null
cd $OLDPWD

echo
echo Creando sistemas de archivo en "$DESTDEVPERS" para PERSISTENCIA, 
echo puede tomar varios minutos... 
mptpers=/tmp/EXT4PERS 
mkfs.ext4  "$DESTDEVPERS"
e2label  "$DESTDEVPERS" persistence
echo Montando "$DESTDEVPERS" 
[[ ! -d $mptpers ]] && mkdir $mptpers
if ! mount "$DESTDEVPERS" $mptpers ;then 
   echo No fue posible montar $DESTDEVPERS en $mptpers, saliendo
   terminar 3
fi 
echo Copiando de origen a $mptpers, puede tomar un tiempo
rsync -a ${ORIGENPERS}/ $mptpers/

echo Desmontando, espere, en unos minutos terminaremos
umount "$DESTDEVLIVE"
umount "$DESTDEVPERS" 

#Limpiando 
rmdir $mptlive
rmdir $mptpers

echo Adiós, feliz FLISOL! && terminar 0

# TODO:  
# 1) recibir como opciones dispositivo de origen y destino para evitar
# menu de preguntas. 
# 2) Asociar mejor las verificaciones 
# 3) Verificar que las variables DESTDEVLIVE y DESTDEVPERS estén definidas
# 4) Faltaría verificar que la capacidad del pendrive sea acorde, 8GB o mas 
# 5) Mejorar en general la estética de los mensajes, colores etc. 
# 6) Interfaz con dialog 
# 7) Implementar una opción que permita crear un pendrive con 
# persistencia origen siguiendo la receta de más abajo. La opción 
# debiera estár seguida de la ruta al archivo ISO a utilizar.  
# RECETA PARA ARMAR EL PRIMER PENDRIVE 
# con PERSISTENCIA (hay herramientas como ventoy)
# En un pendrive de 8G o mas (ej /dev/sdb)
# Se crean ahí dos particiones
# 1. una de 5GB fat (seleccionar fat32), puede ser menos
# dependiendo de la distro 
# 2. una ext4

# luego de crear el filesystem ext4, se le coloca la etiqueta
# "persistente" a la particion ext4.
# Ejemplo:
# e2label /dev/sdb2 persistence

# Montamos la particion fat y colocamos ahí el live cd. Ejemplo:
# mount /dev/sdb1 /mnt
# cd /mnt
# 7z x /home/user/iso/debian-live.iso (distro favorita)

# Editamos el archivo boot/grub/grub.cfg de la particion fat, y en los
# argumentos del kernel agregamos el argumento "persistence". Ejemplo

# editar /mnt/boot/grub/grub.cfg
# agregar persistence a la linea linux:
#linux /live/vmlinuz-6.1.0-7-amd64 boot=live components persistence
#quiet splash etc

#Desmontamos.
# umount /mnt

#En la particion 2 ext4:
# mount /dev/sdb2 /mnt
# cd /mnt
# echo / union > persistence.conf
# cd /
# umount /mnt

# Listo. Reiniciar y arrancar del pendrive para probar.

# Para poner ese GNU/Linux en español una vez iniciado hay que hacer un pasito mas:

#abrir una terminal en el live
#sudo su -
#export LANG=es_ES.UTF-8

#dpkg-reconfigure locales

#(y seleccionar en el menu que construya el locale es_ES.UTF-8 y luego
#seleccionar ese como default).

#Listo, reiniciar. Una contra de esta opción es que es mas lento 
#que instalar en el disco interno. Depende del pendrive, y de que 
#tan bueno sea el puerto usb para velocidades altas.
