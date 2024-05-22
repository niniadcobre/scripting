#!/bin/bash 

#DEBUG=debug

#Verificaciones 
[[ $(id -u) -ne 0 ]] && echo Debe ser root para ejecutar este script && exit 1
if ! ( which lsblk >/dev/null &&  which fdisk >/dev/null && which e2label >/dev/null )
then 	
  echo Se requiere: fdisk, lsblk y e2label, instalar para continuar. 
  exit 2
fi

#Establecer cuál es el dispositivo root para evitar
#problemas y excluirlo de cualquier selección. 
ROOTMAJ=$(lsblk --filter 'MOUNTPOINT == "/"' -o MAJ --noheading)

function terminar {
   echo Saliendo... 
   exit 1
}

function origen {
declare -g ORIGENLIVE 
declare -g ORIGENPERS

cat << FIN 
   Seleccione el dispositivo ORIGEN a partir del cual 
   realizará la copia a un nuevo dispositivo. El mismo
   deberá contener una partición FAT con la imagen 
   Debian-Live y una segunda partición EXT4 donde se 
   guardan los archivos persistentes. 
FIN

select disp in $(echo $(lsblk -r --noheadings  -p -d -o NAME --exclude "$ROOTMAJ") salir);do
    [[ "$disp" == "salir" ]] && terminar
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

ORIGENLIVE=$(lsblk --noheading -r -p -o MOUNTPOINTS "${disp}1")
ORIGENPERS=$(lsblk --noheading -r -p -o MOUNTPOINTS "${disp}2")
ORIGENMAJ=$(lsblk -d -o MAJ --noheading ${disp})

[[ -v DEBUG ]] && echo El directorio de LIVE de ORIGEN es $ORIGENLIVE
[[ -v DEBUG ]] && echo El directorio de PERSISTENCIA de ORIGEN es $ORIGENPERS
[[ -v DEBUG ]] && echo Major: $ORIGENMAJ
}

function mensaje {

cat << FIN

Seleccione un dispositivo DESTINO para crear una 
imagen de Debian-Live con persistencia. 
ADVERTENCIA: el mismo perderá TODO su contenido 
actual en el proceso. 
FIN
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

origen 
mensaje 
# Se eliminan el dispositivo de ORIGEN y el ROOTFS del listado de posibles
# destinos para evitar catástrofes (--exclude). 
select disp in $(echo $(lsblk -r --noheadings -p -d -o NAME --exclude ${ROOTMAJ},${ORIGENMAJ}) salir);do
 [[ "$disp" == "salir" ]] && terminar
 echo El dispositivo seleccionado es: "$disp"
 lsblk "$disp"
 fdisk -l "$disp"
 echo ¿Es correcta la elección? ¿SI/no? 
 while read resp;do 
   if [[ $resp == SI ]];then 
     break 2
   else break 
   fi 
 done   
 mensaje 
done 

echo 
echo Se procederá a destruir la información en "$disp"
echo ¿Está de acuerdo? ¿SI/no? 
while read resp;do 
  if [[ $resp == SI ]];then 
    break 
   else 
    echo Saliendo, sin cambios sobre "$disp"
    exit 3
   fi 
done   

# Intentamos desmontar particiones del destino 
for mpt in $(lsblk --noheading -r -p -o MOUNTPOINTS  "$disp");do
  echo Desmontando $mpt 
  if ! umount $mpt;then 
    echo No fue posible desmontar $mpt, saliendo... 
    exit 1
  fi
done 

echo 
echo Escribiendo nueva tabla de particiones en "$disp" 
# Eliminar cualquier tabla de partición existente
echo -e "o\nw" | fdisk "$disp" > /dev/null

# Crear la partición FAT de 5GB
echo -e "n\np\n1\n\n+5G\nt\nb\nw" | fdisk "$disp" > /dev/null

# Crear la partición EXT4 con el resto del espacio
echo -e "n\np\n2\n\n\nw" | fdisk "$disp" > /dev/null

partprobe "$disp" > /dev/null
fdisk -l "$disp" 

echo
echo Creando sistemas de archivo en "${disp}1" para LIVE
mptlive=/tmp/FATLIVE/
mkfs.fat -F32 "${disp}1"
echo Montando "${disp}1"
[[ ! -d $mptlive ]] && mkdir $mptlive
mount "${disp}1" $mptlive
cd ${ORIGENLIVE}
echo Copiando de origen a $mptlive, puede tomar un tiempo
cp -a . $mptlive/ 2>/dev/null
cd $OLDPWD

echo
echo Creando sistemas de archivo en "${disp}2" para PERSISTENCIA, 
echo puede tomar varios minutos... 
mptpers=/tmp/EXT4PERS 
mkfs.ext4  "${disp}2"
e2label  "${disp}2" persistence
echo Montando "${disp}2" y copiando... puede tomar un tiempo
[[ ! -d $mptpers ]] && mkdir $mptpers
mount ${disp}2 $mptpers  && rsync -a ${ORIGENPERS}/ $mptpers/

echo Desmontando, espere, en unos minutos terminaremos
umount "${disp}1" 
umount "${disp}2" 

echo Adiós, feliz FLISOL! 

# TODO:  
# recibir como opciones dispositivo de origen y destino 
# Asociar mejor las verificaciones 
# Agregar comillas dobles donde corresponda 
# Mejorar en general la estética de los mensajes
# Sobre las particiones de origen, eliminar los ${disp}1 etc harcodeados
