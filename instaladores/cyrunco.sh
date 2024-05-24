#!/bin/bash 

PROGRAM=cyrunco
VERSION=0.0

# Este script fue creado por Miriam Lechner para la Facultad de Informatica
# de la Universidad Nacional del Comahue (UNCOMA) para instalar de manera
# sencilla una Distribucion GNU/Linux basada den Alpine que llamaremos
# de momento Cyrunco. La misma esta pensada para tener una distribucion
# minimalista que permita aprovechar maquinas de bajos recursos bajo
# el espiritu Cyberciruja

#DEBUG=debug

#Verificaciones 
[[ $(id -u) -ne 0 ]] && echo Debe ser root para ejecutar este script && exit 1
if ! ( which lsblk >/dev/null &&  which fdisk >/dev/null && which mkfs.ext4 >/dev/null )
then 	
  echo Se requiere: fdisk, lsblk y mkfs.ext4, instalar para continuar. 
  exit 2
fi

#Establecer cuál es el dispositivo root para evitar
#problemas y excluirlo de cualquier selección. 
ROOTMAJ=$(lsblk --filter 'MOUNTPOINT == "/"' -o MAJ --noheading)

function terminar {
   echo Saliendo... 
   exit 1
}

function mensaje_destino {

cat << FIN

Seleccione un dispositivo DESTINO para INSTALAR en él 
la distribución Cyrunco (Alpine con ICEWM).
ADVERTENCIA: el mismo perderá TODO su contenido 
actual en el proceso, verifique la correcta selección
antes de proceder. 

FIN
}

cat << FIN

  Este script fue creado para INSTALAR la distribución 
  Cyrunco (Alpine + ICEWM), para lo cual supone un disco 
  destino sobre el cual será instalado que pueda utilizarce
  en su totalidad.  
  ADVERTENCIA: Cualquier instalación prexistente será ELIMINADA
  JUNTO A CUALQUIER DATO EXISTENTE EN EL DISCO DESTINO. 

FIN

mensaje 
# Se eliminan el dispositivo el ROOTFS del listado de posibles
# destinos para evitar catástrofes (--exclude). 
select disp in $(echo $(lsblk -r --noheadings -p -d -o NAME --exclude ${ROOTMAJ}) salir);do
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

echo HASTA PRONTO!

# TODO:  
# recibir como opciones dispositivo de origen y destino 
# Asociar mejor las verificaciones 
# Agregar comillas dobles donde corresponda 
# Mejorar en general la estética de los mensajes
# Sobre las particiones de origen, eliminar los ${disp}1 etc harcodeados
