#!/bin/bash 

preguntar () {
  local ok=1 ; 
  local respuesta  

  until [[ $ok -eq 0 ]];do 
     echo $@ 
     read respuesta 
     case $respuesta in 
       s*|S*) ok=0; respuesta=0 ;;
       n*|N*) ok=0;  respuesta=1 ;;
       *) echo Respuesta inválida, responda si o no por favor.  
     esac
  done 
  return $respuesta 
}

ayuda () {
cat << EOF
General: 
Este script permite eliminar el ruido de un video. Necesita definir 
un intervalo del video, en el que se produzca el mayor silencio 
posible para crear el perfil de ruido y luego poder reducirlo. 

Invocacion: $0 [-s] [-i 00:00:00.0] [-d 00:00:00.0] archivo.mp4
Opciones: -i 00:00:00.0 hh:mm:ss.ms Inicio del intervalo de silencio
          -d 00:00:00.0 hh:mm:ss.ms Duración del intervalo.
          -s responder sí a todas las preguntas
          -h muestra esta ayuda 
EOF
exit 1
}


es_mp4 () { 
   file $1 |grep -qi mp4 &> /dev/null 
   return $?
}

limpiar () {
  echo rm -rf $dirtemp 
}

si=1
while getopts hsi:d: opt;do 
   case $opt in
    i) ss=$OPTARG ;; 
    d) dur=$OPTARG;;
    h) ayuda $0 ;; 
    s) si=0 ;;
    *) echo "Opción inválida: -$opt" ; ayuda 
   esac 
done 

#Verificando software
which sox &> /dev/null || { echo Este script necesita sox && exit 2 ; }
which ffmpeg &> /dev/null || { echo Este script necesita ffmpeg && exit 2 ;}

#Si no hay definición de las opciones ss y dur asigno valores predeterminados.
if [[ ! -v ss ]] && [[ $si -ne 0 ]] ;then 
   if preguntar "No se ha definido el punto de inicio, -s, ¿desea continuar? si/no";then 
     echo "Estableciendo inicio de intervalo al comienzo" 
     ss="00:00:00.0"
   else exit 1 
   fi 
elif [[ ! -v ss ]] && [[ $si -eq 0 ]] ;then  
   echo "Estableciendo inicio de intervalo al comienzo" 
   ss="00:00:00.0"
fi
if [[ ! -v dur ]] && [[ $si -ne 0 ]] ;then 
   if preguntar "No se ha definido la duración del intervalo, -d, ¿desea continuar? si/no";then 
     echo "Estableciendo duración en 2 segundos"
     dur="00:00:02.0"
   else exit 1 
   fi 
elif [[ ! -v dur ]] && [[ $si -eq 0 ]] ;then  
   echo "Estableciendo duración en 2 segundos"
   dur="00:00:02.0"
fi

video=${!#}
# Verificar que el archivo de video exista 
[[ -v video ]] && [[ -f "$video" ]] || { echo Archivo $video inválido && exit 2 ;}
videob=$(basename $video)

if ! es_mp4 $video ;then 
   echo Formato de $video inválido! ; exit 4
fi

  ## Creando directorio de trabajo temporal 
  dirtemp=$(mktemp -d)
  ## Removiendo audio del video 
  ffmpeg -i $video -map 0:0 -c:v copy $dirtemp/${videob%%.mp4}_SA.mp4 
  [[ $? -ne 0 ]] && limpiar &&  exit 3
  ## Extrayendo el audio en un archivo separado
  ffmpeg -i $video -acodec pcm_s16le -ar 128k -vn $dirtemp/${videob%%.mp4}.wav 
  [[ $? -ne 0 ]] && limpiar &&  exit 3
  ## Creando intervalo de ruido
  ffmpeg -i $video -acodec pcm_s16le -ar 128k -vn -ss $ss -t $dur $dirtemp/ruido.wav 
  [[ $? -ne 0 ]] && limpiar &&  exit 3
  ## Generando perfil de ruido 
  sox $dirtemp/ruido.wav -n noiseprof $dirtemp/ruido.prof
  [[ $? -ne 0 ]] && limpiar &&  exit 3
  ## Limpiar ruido del audio original
  sox $dirtemp/${videob%%.mp4}.wav $dirtemp/${videob%%.mp4}_limpio.wav noisered $dirtemp/ruido.prof 0.21 
  [[ $? -ne 0 ]] && limpiar &&  exit 3
  ## Convertir a mp3 
  ffmpeg -i $dirtemp/${videob%%.mp4}_limpio.wav -codec:a libmp3lame -qscale:a 2 $dirtemp/${videob%%.mp4}_limpio.mp3 
  [[ $? -ne 0 ]] && limpiar &&  exit 3
  ## Combinar video sin audio y audio sin ruido 
  ffmpeg -i $dirtemp/${videob%%.mp4}_SA.mp4 -i $dirtemp/${videob%%.mp4}_limpio.mp3  -acodec copy -vcodec copy -f mp4  ${video%%.mp4}_FINAL.mp4
  ## remover temporales
  limpiar 

exit 0

