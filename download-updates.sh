#!/bin/bash

# This script is used for downloading package updates.
# By default, it will check the alchemist_beta repo from Valve, but it can be used for different repos.
# Example: ./download-updates.sh deb http://repo.steampowered.com/steamos alchemist_beta main contrib non-free
# Packages will be downloaded to the newpkgs directory.

if [[ -z $@ ]]; then
	repo="deb http://repo.steampowered.com/steamos alchemist_beta main contrib non-free"
else
	repo="$@"
fi

architectures="amd64 i386"
downloaddir="newpkgs"

# delete old Packages.gz file
if [[ -f Packages.gz ]]; then
	rm Packages.gz
fi

# do the thing for each entry in sources
#for repo in ${sources};do
        # get required info from repo string
        repourl=$(echo $repo|cut -d" " -f2)
        reponame=$(echo $repo|cut -d" " -f3)
        repoareas=$(echo $repo|cut -d" " -f4-)
        
        # check each part of the rpeo
        for area in ${repoareas}; do
                for arch in ${architectures}; do
                        wget ${repourl}/dists/${reponame}/${area}/binary-${arch}/Packages.gz
                        gunzip -c buildroot/dists/alchemist/${area}/binary-${arch}/Packages.gz|grep Filename|cut -d" " -f2|sort > buildroot.txt
                        gunzip -c Packages.gz|grep Filename|cut -d" " -f2|sort > repo.txt
                        
                        # create a list of packages which have different versions in the repo than the ones in buildroot
                        diffpkgs=$(grep -F "`cat buildroot.txt|cut -d'_' -f1|sed 's/$/_/'`" repo.txt|grep -Fvxf "buildroot.txt")
                        echo $diffpkgs
                        echo "$(echo $diffpkgs|wc -w)"
                        
                        # download all the new packages
                        for pkg in ${diffpkgs}; do
                        	mkdir -p ${downloaddir}
                        	wget -nc -P ${downloaddir} ${repourl}/${pkg}
                        done
                        
                        # clean up
                        rm buildroot.txt
                        rm repo.txt
                        rm Packages.gz
                done
        done
#done
