#!/bin/bash 

declare -i count=1
while read -r -d: usr ;do 
   read -d: -r x
   read -d: -r uid
   read -d: -r gid
   read -d: -r longname
   read -d: -r home
   read  shell 
   echo "Usuario $count : $usr $shell "
   let count++
done < "${1:-/dev/stdin}"
