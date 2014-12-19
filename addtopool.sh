#!/bin/bash

# Set variables
pkgdir="vlc"
distfiles="http://repo.steampowered.com/steamos/dists/alchemist/main/binary-i386/Packages.gz \
	http://repo.steampowered.com/steamos/dists/alchemist/main/binary-amd64/Packages.gz \
	http://repo.steampowered.com/steamos/dists/alchemist/contrib/binary-i386/Packages.gz \
	http://repo.steampowered.com/steamos/dists/alchemist/contrib/binary-amd64/Packages.gz \
	http://repo.steampowered.com/steamos/dists/alchemist/non-free/binary-i386/Packages.gz \
	http://repo.steampowered.com/steamos/dists/alchemist/non-free/binary-amd64/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/main/binary-all/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/main/binary-i386/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/main/binary-amd64/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/contrib/binary-all/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/contrib/binary-i386/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/contrib/binary-amd64/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/non-free/binary-all/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/non-free/binary-i386/Packages.gz \
	http://ftp.debian.org/debian/dists/wheezy/non-free/binary-amd64/Packages.gz "
distdir="package-list"

# Download all the package list files in the list distfiles
download ( ) {
	mkdir -p ${distdir}
	distnumber=1
	for pkglist in ${distfiles};do
		wget -P ${distdir} ${pkglist}
		distfilename=$(echo $pkglist|rev|cut -d"/" -f1|rev)
		gunzip -c ${distdir}/${distfilename}|grep Filename|cut -d" " -f2 > ${distdir}/files${distnumber}.txt
		rm ${distdir}/${distfilename}
		distnumber=$(($distnumber+1))
	done
}

move ( ) {
files=$(ls ${pkgdir}|grep ".deb")

for package in ${files}; do
	location=$(cat ${distdir}/files?.txt|grep -m 1 ${package}|cut -d "/" -f1-4)
	if [[ ${location} ]]; then
		mkdir -p ${location}
		mv ${pkgdir}/${package} ${location}
	else
		echo "couldn't find ${package} in repo"
	fi
done
}

download
move
