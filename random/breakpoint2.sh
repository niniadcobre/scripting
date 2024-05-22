#!/bin/bash
# Con esta función depuramos, podemos modificarla... 
#
DBG=sd
function debug_message {
    echo "Debug: Línea $1 ejecutada: $2"
}

# Comienzo de punto de interrupción (breakpoint)
[[ -v DBG ]] && trap 'debug_message $LINENO "$BASH_COMMAND"' DEBUG

while : ;do 
	echo '¿Cual es la estación del año mas bella?'
	select op in verano otoño invierno primavera;do
	   echo Elegiste: $op
	   break
	done
	if [[ "$op" != "otoño" ]];then 
	   echo pensalo nuevamente...
	   sleep 2
        else 
 	     echo Estamos de acuerdo! 
	     break
	fi
done

[[ -v DBG ]] && trap - DEBUG

echo Esta IA piensa que el otoño es la mas bella por lejos. 
