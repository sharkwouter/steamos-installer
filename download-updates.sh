#!/bin/bash

# This script is used for downloading package updates.
# The configuration file with repos is called sources.list, which works in almost the same way as the sources.list file in debian.
# Adding main/debian-installer to a line with a repo will make it look for installer updates as well.
# Packages are downloaded to the updates directory.

# set variables
architectures="amd64 i386 all"
distsdir="package-lists"
downloaddir="updates"

# create download dir
mkdir -p ${downloaddir}
mkdir -p ${distsdir}
    
# this loop reads sources.list  
while read repo; do
        # ignore line if empty or starting with #
        if [[ "$(echo ${repo}|cut -c1)" = "#" ]] || [[ -z ${repo} ]]; then
                break
        fi
        
        # get required info from repo string
        repourl=$(echo $repo|cut -d" " -f2)
        reponame=$(echo $repo|cut -d" " -f3)
        repoareas=$(echo $repo|cut -d" " -f4-)
        
        # check each part of the repo
        for area in ${repoareas}; do
        	for arch in ${architectures}; do
        		# download repo packagelist
        		packagelist="${repourl}/dists/${reponame}/${area}/binary-${arch}/Packages.gz"
        		wget -q -x  -P ${distsdir} "${packagelist}"
        		if [[ ! $? -eq 0 ]]; then
        		        echo "Couldn't download ${packagelist}"
        		        echo " "
        		        break
        		fi
        		packagelist=$(echo ${packagelist}|cut -d"/" -f3-)
        		# copy the filename strings from the Package.gz from both the local buildroot and the repo into textfiles
        		gunzip -c buildroot/dists/alchemist/${area}/binary-${arch}/Packages.gz|grep Filename|cut -d" " -f2|sort > buildroot.txt
        		gunzip -c ${distsdir}/${packagelist}|grep Filename|cut -d" " -f2|sort > repo.txt
                        
        		# create a list of packages which have different versions in the repo than the ones in the buildroot
        		diffpkgs=$(grep -F "`cat buildroot.txt|cut -d'_' -f1|sed 's/$/_/'`" repo.txt|grep -Fvxf "buildroot.txt")
                        
        		# download all the new packages
        		for pkg in ${diffpkgs}; do
        			pkgname=$(echo "${pkg}"|cut -d"_" -f1)
        			oldpkg=$(grep "${pkgname}" buildroot.txt)
        			newestpkg=$(echo -e "${pkg}\n${oldpkg}"|sort -V|tail -1)
        			if [[ ! -z ${oldpkg} ]] && [[ "x${pkg}" == "x${newestpkg}" ]]; then
        			        if [[ -z $(echo "${downloaded}"|grep ${pkg}) ]]; then
        				        echo "buildroot: ${oldpkg}"
        				        echo "repo: ${pkg}"
        				
        				        downloaded="${downloaded} ${pkg}"
                                	        wget -nc -nv -P ${downloaddir} ${repourl}/${pkg}
                                	        echo " "
                                	fi
                                else
                                        if [[ -z $(echo "${skipped}"|grep ${pkg}) ]];then
                                	        skipped="${skipped} ${pkg}"
                                	fi
                                fi
        		done
                         
        		# clean up
        		rm buildroot.txt
        		rm repo.txt
        	done
        done
# throw sources.list into the while loop        
done < sources.list

# calculate results
downloadednr=$(echo "${downloaded}"|wc -w)
skippednr=$(echo "${skipped}"|wc -w)

# output result

echo "Downloaded packages: ${downloaded}"
echo " "
echo "Skipped packages: ${skipped}"
echo " "
echo "${downloadednr} package have been downloaded"
echo "${skippednr} packages have been skipped"
echo " "
echo "The updated packages have been moved to ${downloaddir}. To add them to the pool run: ./addtopool.sh ${downloaddir}"
echo "Skipped packages can be downloaded at ${repourl} if needed."
