#!/bin/bash 
set -x 
temp=$(mktemp)
cat -   > $temp

sort $temp | nl 

#cat ${1-\-} | nl

