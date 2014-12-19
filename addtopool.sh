#!/bin/bash

pkgdir="./vlc"
distfile="./Packages"

files=$(ls ${pkgdir}|grep ".deb")
distnames=$(cat Packages|grep Filename|cut -d" " -f2)

for package in ${files}; do
	location=$(echo ${distnames}|tr "\ " "\n"|grep ${package}|cut -d "/" -f1-4)
	if [ ${location} ]; then
		mkdir -p ${location}
		mv ${pkgdir}/${package} ${location}
	else
		echo "couldn't find ${package} in repo"
	fi
done
