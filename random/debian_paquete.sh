#!/bin/bash

# Obtener una lista de todos los paquetes instalados en el sistema
packages=$(dpkg-query -W -f='${Package}\n')

# Recorrer cada paquete y obtener su tamaño en disco
for package in $packages; do
  size=$(dpkg-query -s $package 2>/dev/null | grep Installed-Size | awk '{print $2}')
  echo "$package: $size KB"
done
