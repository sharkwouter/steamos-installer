#!/bin/bash

repo="deb http://repo.steampowered.com/steamos alchemist main"; #contrib non-free"
#        deb http://repo.steampowered.com/steamos alchemist_beta main contrib non-free"
architectures="amd64"
downloaddir="newpkgs"

# do the thing for each entry in sources
#for repo in ${sources};do
        # get required info from repo string
        repourl=$(echo $repo|cut -d" " -f2)
        reponame=$(echo $repo|cut -d" " -f3)
        repoareas=$(echo $repo|cut -d" " -f4-)
        
        # 
        for area in ${repoareas}; do
                for arch in ${architectures}; do
                        wget ${repourl}/dists/${reponame}/${area}/binary-${arch}/Packages.gz
                        gunzip -c buildroot/dists/${reponame}/${area}/binary-${arch}/Packages.gz|grep Filename|cut -d" " -f2 > buildroot.txt
                        gunzip -c Packages.gz|grep Filename|cut -d" " -f2 > repo.txt
                        
                        cat buildroot.txt|cut -d"_" -f1|xargs grep - repo.txt >> shared.txt 
                        
                        #gunzip -c Packages.gz|grep Filename|cut -d" " -f2|grep `cat buildroot.txt|cut -d"_" -f1` > repo.txt
                        rm Packages.gz
                done
        done
#done
