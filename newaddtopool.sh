#!/bin/bash

# This script is used for downloading package updates.
# By default, it will check the alchemist_beta repo from Valve, but it can be used for different repos.
# Example: ./download-updates.sh deb http://repo.steampowered.com/steamos alchemist_beta main contrib non-free
# Packages will be moved to the updates directory.

# delete old Packages.gz file
if [[ -f Packages.gz ]]; then
	rm Packages.gz
fi

# set variables
architectures="amd64 i386 all"
distsdir="package-lists"

# show how to user ./addtopool.sh
usage ( ) {
	echo "Usage: $0 [ -r ] [ -i ] [ -n ] packageslocation"
	echo "-u 		Update the package lists"
	echo "-i		Ignore versions of packages"
	echo "-n		Create new directories, when the package isn't found in any of the repos"
	exit 1
}

# Setup command line arguments
if [[ $# -eq 0 ]]; then
	usage
fi

while getopts uin opt
do
	case $opt in
		u) update=1;;
		i) ignoreversions=1;;
		n) newpkgs=1;;
		*)usage;;
	esac
done

shift $(($OPTIND -1 ))

# Make sure only one directory is entered
if [ ! -z $2 ]; then
	echo "To many arguments"
	usage
fi

# Set the packageslocation to what the user entered or updates
if [ ! -z $1 ]; then
        pkgdir=$1
else
        pkgdir="updates"
fi

# create download location for Package.gz files
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
        		if [[ $update -eq 1 ]] || [ ! -d ${distsdir} ]; then
        		        wget -q -x  -P ${distsdir} "${packagelist}"
        		        if [[ ! $? -eq 0 ]]; then
        		                echo " "
        		                echo "Couldn't download ${packagelist}"
        		                echo " "
        		                break
        		        fi
        		fi
        		packagelist=$(echo ${packagelist}|cut -d"/" -f3-)
        		# copy the filename strings from the Package.gz from both the local buildroot and the repo into textfiles
        		gunzip -c buildroot/${packagelist}|grep Filename|cut -d" " -f2|sort > buildroot.txt
        		gunzip -c ${distsdir}/${packagelist}|grep Filename|cut -d" " -f2|sort > repo.txt
                        
        		# create a list of packages which have different versions in the repo than the ones in the buildroot
        		diffpkgs=$(grep -F "`cat buildroot.txt|cut -d'_' -f1|sed 's/$/_/'`" repo.txt|grep -Fvxf "buildroot.txt")
                        
        		# download all the new packages
        		for pkg in ${diffpkgs}; do
        			pkgname=$(echo "${pkg}"|cut -d"_" -f1)
        			oldpkg=$(grep "${pkgname}" buildroot.txt)
        			newestpkg=$(echo -e "${pkg}\n${oldpkg}"|sort -V|tail -1)
        			if [[ "x${pkg}" == "x${newestpkg}" ]]; then
        				echo "buildroot: ${oldpkg}"
        				echo "repo: ${pkg}"
        				
        				moved="${moved} ${pkg}"
                                	wget -nc -nv -P ${pkgdir} ${repourl}/${pkg}
                                	echo " "
                                else
                                	skipped="${skipped} ${pkg}"
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
movednr=$(echo "${moved}"|wc -w)
skippednr=$(echo "${skipped}"|wc -w)

# output result

echo "moved packages: ${moved}"
echo " "
echo "Skipped packages: ${skipped}"
echo " "
echo "${movednr} package have been moved"
echo "${skippednr} packages have been skipped"
echo " "
echo "The packages have been moved to the pool."
echo "Skipped packages can be found in the ${pkgdir} directory."
