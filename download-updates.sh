#!/bin/bash

# This script is used for downloading package updates.
# By default, it will check the alchemist_beta repo from Valve, but it can be used for different repos.
# Example: ./download-updates.sh deb http://repo.steampowered.com/steamos alchemist_beta main contrib non-free
# Packages will be downloaded to the updates directory.

# DISCLAIMER: RIGHT NOW THIS SCRIPT ASSUMES THAT THE PACKAGES IN THE REPO ARE ALWAYS NEWER!!

# read cmdline input
if [[ -z $@ ]]; then
	repo="deb http://repo.steampowered.com/steamos alchemist_beta main contrib non-free"
else
	repo="$@"
fi

# delete old Packages.gz file
if [[ -f Packages.gz ]]; then
	rm Packages.gz
fi

# set variables
architectures="amd64 i386"
downloaddir="updates"

# get required info from repo string
repourl=$(echo $repo|cut -d" " -f2)
reponame=$(echo $repo|cut -d" " -f3)
repoareas=$(echo $repo|cut -d" " -f4-)

# create download dir
mkdir -p ${downloaddir}
        
# check each part of the repo
for area in ${repoareas}; do
	for arch in ${architectures}; do
		# download repo packagelist
		wget ${repourl}/dists/${reponame}/${area}/binary-${arch}/Packages.gz
		
		# copy the filename strings from the Package.gz from both the local buildroot and the repo into textfiles
		gunzip -c buildroot/dists/alchemist/${area}/binary-${arch}/Packages.gz|grep Filename|cut -d" " -f2|sort > buildroot.txt
		gunzip -c Packages.gz|grep Filename|cut -d" " -f2|sort > repo.txt
                
		# create a list of packages which have different versions in the repo than the ones in the buildroot
		diffpkgs=$(grep -F "`cat buildroot.txt|cut -d'_' -f1|sed 's/$/_/'`" repo.txt|grep -Fvxf "buildroot.txt")
                
		# download all the new packages
		for pkg in ${diffpkgs}; do
			pkgname=$(echo "${pkg}"|cut -d"_" -f1)
			oldpkg=$(grep "${pkgname}" buildroot.txt)
			newestpkg=$(echo -e "${pkg}\n${oldpkg}"|sort -V|tail -1)
			if [[ "x${pkg}" == "x${newest}" ]]; then
				downloaded="${downloaded} ${pkg}"
                        	wget -nc -nv -P ${downloaddir} ${repourl}/${pkg}
                        else
                        	skipped="${skipped} ${pkg}"
                        fi
		done
                 
		# clean up
		rm buildroot.txt
		rm repo.txt
		rm Packages.gz
	done
done

# calculate results
downloadednr=$(echo "${downloaded}"|wc -w)
skippednr=$(echo "${skipped}"|wc -w)

# output result
echo "${downloadednr} package have been downloaded"
echo "${skippednr} packages have been skipped"
if [[ ${downloadnr} -eq 0 ]] && [[ ${skippednr} -eq 0 ]]; then
	echo "Your buildroot is up-to-date"
else
	echo "The updated packages have been moved to ${downloaddir}"
	echo "To add them to the pool run: ./addtopool.sh ${downloaddir}"
fi
