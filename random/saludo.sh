#!/bin/bash
declare -i count=1;

function mensaje {
   declare -i par 
   ojos=$1; shift
   par=$count%2 
   clear
   if [[ $par -eq 0 ]];then 
      xcowsay  $@
   else
      xcowsay  $@
   fi
   sleep 
   count=count+1
}

cat << FIN > mensajes.txt
-o Tecnicatura Universitaria en Administración de Sistemas y Software Libre
xx ¿Qué hacemos? Mantenemos la infraestructura tecnológica funcionando
== Trabajamos en TODO tipo de instituciones, pequeñas a muy grandes
OO Redes, seguridad, almacenamiento, instalación, documentación...
\$\$ Soporte a usuarios
XX TOMAMOS DECISIONES TECNOLÓGICAS
oo Software Libre
@@ Adopción de tecnología ÉTICA
?? SOBERANÍA DIGITAL
## Dos años y medio de duración; horarios por la tarde.
oo Carrera de índole práctica
FIN

while :; do 
   while read msj;do 
      mensaje $msj  
   done < mensajes.txt
done 
