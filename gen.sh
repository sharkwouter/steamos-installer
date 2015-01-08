#!/bin/sh
#Basic variables
BUILD="./buildroot"
APTCONF="./ftparchive/apt-ftparchive.conf"
APTUDEBCONF="./ftparchive/apt-ftparchive-udeb.conf"
DISTNAME="alchemist"
CACHEDIR="./cache"
ISOPATH="."
ISONAME="vaporos1.2.iso"
ISOVNAME="VaporOS1.2"
UPSTREAMURL="http://repo.steampowered.com"
STEAMINSTALLFILE="SteamOSDVD.iso"
MD5SUMFILE="MD5SUMS"
KNOWNINSTALLER="e0583f17ea8f6d5307b74a0d28a99a5e"
REPODIR="./archive-mirror/mirror/repo.steampowered.com/steamos"

#Show how to use gen.sh
usage ( )
{
	cat <<EOF
	$0 [OPTION]
	-h                Print this message
	-d		  Re-Download ${STEAMINSTALLFILE}
EOF
}

#Check some basic dependencies this script needs to run
deps ( ) {
	#Check dependencies
	deps="apt-utils xorriso syslinux rsync wget p7zip-full realpath"
	for dep in ${deps}; do
		if dpkg-query -s ${dep} >/dev/null 2>&1; then
			:
		else
			echo "Missing dependency: ${dep}"
			echo "Install with: sudo apt-get install ${dep}"
			exit 1
		fi
	done
	if test "`expr length \"$ISOVNAME\"`" -gt "32"; then
		echo "Volume ID is more than 32 characters: ${ISOVNAME}"
		exit 1
	fi

	#Check xorriso version is compatible, must be 1.2.4 or higher
	xorrisover=`xorriso --version 2>&1 | egrep -e "^xorriso version" | awk '{print $4}'`
	reqxorrisover=1.2.4
	if dpkg --compare-versions ${xorrisover} ge ${reqxorrisover} >/dev/null 2>&1; then
		echo "PASS: xorriso version ${xorrisover} supports required functions."
	else
		echo "ERROR: xorriso version ${xorrisover} is too to old. Please upgrade to xorriso version ${reqxorrisover} or higher."
		exit 1
	fi
}

#Remove the ${BUILD} directory to start from scratch
rebuild ( ) {
	if [ -d "${BUILD}" ]; then
		echo "Building ${BUILD} from scratch"
		rm -fr "${BUILD}"
	fi
}

#Report on obsolete packages
obsoletereport ( ) {
	if [ ! -d ${REPODIR} ]; then
		echo "No ${REPODIR} directory exists, run archive-mirror.sh if you want this script to report obsolete packages"
	else
		echo "Reporting on packages which are older in ${BUILD} than ${REPODIR}"
		echo "\nPackagename\t\ttype\tarch\told version\tnew version\n"
		REPODIR="`realpath ${REPODIR}`"
		NEWPKGSDIR="updates"
		mkdir -p ${NEWPKGSDIR}
		NEWPKGSDIR="`realpath ${NEWPKGSDIR}`"
		cd ${BUILD}/pool/
		for i in */*/*/*.*deb
			do PKGNAME=`basename $i | cut -f1 -d'_'`
			ARCHNAME=`basename $i | cut -f3 -d'_' | cut -f1 -d'.'`
			PKGPATH=`dirname $i`;PKGVER=`basename $i | cut -f2 -d'_'`
			DEBTYPE=`basename $i | sed 's/.*\.//g'`
			if [ `ls -1 ${REPODIR}/pool/${PKGPATH}/${PKGNAME}_*_${ARCHNAME}.${DEBTYPE} 2> /dev/null | wc -l` -gt 0 ]
				then NEWPKGVER=$(basename `ls -1 ${REPODIR}/pool/${PKGPATH}/${PKGNAME}_*_${ARCHNAME}.${DEBTYPE} | sort -V | tail -1` | cut -f2 -d'_')
				NEWESTPKG=$(bash -c "echo -e '${PKGVER}\n${NEWPKGVER}'"|sort -V|tail -1)
				if [ "x${NEWPKGVER}" = "x${NEWESTPKG}" ] && [ "x${PKGVER}" != "x${NEWESTPKG}" ]
					then echo "${PKGNAME}\t\t${DEBTYPE}\t${ARCHNAME}\t${PKGVER}\t${NEWPKGVER}"
					cp ${REPODIR}/pool/${PKGPATH}/${PKGNAME}_${NEWPKGVER}_${ARCHNAME}.${DEBTYPE} ${NEWPKGSDIR}/
				fi
			fi
		done
		cd -
		echo "Newer packages have been copied to ${NEWPKGSDIR}"
		echo "To add the packages to the pool run: ./addtopool.sh ${NEWPKGSDIR}"
	fi
}
#Extract the upstream SteamOSDVD.iso from repo.steampowered.com
extract ( ) {
	#Download SteamOSDVD.iso
	steaminstallerurl="${UPSTREAMURL}/download/${STEAMINSTALLFILE}"
	#Download if the iso doesn't exist or the -d flag was passed
	if [ ! -f ${STEAMINSTALLFILE} ] || [ -n "${redownload}" ]; then
		echo "Downloading ${steaminstallerurl} ..."
		if wget -O ${STEAMINSTALLFILE} ${steaminstallerurl}; then
			:
		else
			echo "Error downloading ${steaminstallerurl}!"
			exit 1
		fi
	else
		echo "Using existing ${STEAMINSTALLFILE}"
	fi

	#Extract SteamOSDVD.iso into BUILD
	if 7z x ${STEAMINSTALLFILE} -o${BUILD}; then
		:
	else
		echo "Error extracting ${STEAMINSTALLFILE} into ${BUILD}!"
		exit 1
	fi
	rm -fr ${BUILD}/\[BOOT\]
}

verify ( ) {
	#Does this installer look familiar?
	upstreaminstallermd5sum=` wget --quiet -O- ${UPSTREAMURL}/download/${MD5SUMFILE} | grep SteamOSDVD.iso$ | cut -f1 -d' '`
	localinstallermd5sum=`md5sum ${STEAMINSTALLFILE} | cut -f1 -d' '`
	if test "${localinstallermd5sum}" = "${KNOWNINSTALLER}"; then
		echo "Downloaded installer matches this version of gen.sh"
	elif test "${upstreaminstallermd5sum}" = "${KNOWNINSTALLER}"; then
		echo "Local installer is missing or obsolete"
		echo "Upstream version matches expectations, forcing update"
		redownload="1"
	else
		echo "ERROR! Local installer and remote installer both unknown" >&2
		echo "ERROR! Please update gen.sh to support unknown ${STEAMINSTALLFILE}" >&2
		exit 1
	fi
}

#Configure Rocket installer by:
#	Removing uneeded debs
#	Copy over modified/updated debs
#	Copy over Rocket files
#	Re-generate pressed files
#	Re-build the cdrom installer package repositories
#	Generate md5sums
#	Build ISO
createbuildroot ( ) {

	#Delete 32-bit udebs and d-i, as SteamOS is 64-bit only
	echo "Deleting 32-bit garbage from ${BUILD}..."
	find ${BUILD} -name "*_i386.udeb" -type f -exec rm -rf {} \;
	find ${BUILD} -name "*_i386.deb" | egrep -v "(\/eglibc\/|\/elfutils\/|\/expat\/|\/fglrx-driver\/|\/gcc-4.7\/|\/libdrm\/|\/libffi\/|\/libpciaccess\/|\/libvdpau\/|\/libx11\/|\/libxau\/|\/libxcb\/|\/libxdamage\/|\/libxdmcp\/|\/libxext\/|\/libxfixes\/|\/libxxf86vm\/|\/llvm-toolchain-3.3\/|\/mesa\/|\/nvidia-graphics-drivers\/|\/s2tc\/|\/zlib\/|\/udev\/|\/libxshmfence\/|\/steam\/|\/intel-vaapi-driver\/)" | xargs rm -f
	rm -fr "${BUILD}/install.386"
	rm -fr "${BUILD}/dists/*/main/debian-installer/binary-i386/"

	#Copy over updated and added debs
	#First remove uneeded debs
	debstoremove="pool/main/l/lvm2/dmsetup_1.02.74-8+bsos7_amd64.deb pool/main/l/lvm2/libdevmapper1.02.1-udeb_1.02.74-8+bsos7_amd64.udeb pool/main/l/lvm2/dmsetup-udeb_1.02.74-8+bsos7_amd64.udeb pool/main/l/lvm2/libdevmapper-event1.02.1_1.02.74-8+bsos7_amd64.deb pool/main/l/lvm2/lvm2-udeb_2.02.95-8+bsos7_amd64.udeb pool/main/l/lvm2/libdevmapper1.02.1_1.02.74-8+bsos7_amd64.deb pool/main/l/lvm2/liblvm2app2.2_2.02.95-8+bsos7_amd64.deb pool/main/d/debian-archive-keyring/debian-archive-keyring-udeb_2012.4+bsos6_all.udeb pool/main/e/eglibc/libc6-udeb_2.17-97+steamos1+bsos1_amd64.udeb pool/main/libg/libgcrypt11/libgcrypt11-udeb_1.5.0-5+deb7u1+bsos6_amd64.udeb pool/main/l/linux/linux-headers-3.10-4-amd64_3.10.11-1+steamos29+bsos1_amd64.deb pool/main/l/linux/linux-headers-3.10-4-common_3.10.11-1+steamos29+bsos1_amd64.deb pool/main/l/linux/linux-image-3.10-4-amd64_3.10.11-1+steamos29+bsos1_amd64.deb"
	for debremove in ${debstoremove}; do
		if [ -f ${BUILD}/${debremove} ]; then
			echo "Removing ${BUILD}/${debremove}..."
			rm -fr "${BUILD}/${debremove}"
		fi
	done

	#Delete all firmware from /firmware/
	echo "Removing bundled firmware"
        rm -f ${BUILD}/firmware/*

	#Rsync over our local pool dir
	pooldir="./pool"
	echo "Copying ${pooldir} into ${BUILD}..."
	if rsync -av ${pooldir} ${BUILD}; then
		:
	else
		echo "Error copying ${pooldir} to ${BUILD}"
		exit 1
	fi

	#Symlink all firmware
        for firmware in `cat firmware.txt`; do
                echo "Symlinking ${firmware} into /firmware/ folder"
                ln -s ../${firmware} ${BUILD}/firmware/`basename ${firmware}`
        done

	#Copy over the rest of our modified files
	rocketfiles="default.preseed post_install.sh boot isolinux"
	for file in ${rocketfiles}; do
		echo "Copying ${file} into ${BUILD}"
		cp -pfr ${file} ${BUILD}
	done
}

checkduplicates ( ) {
	echo ""
	echo "Removing duplicate packages:"
	echo ""
	
	# create a list with all packages
	files=$(ls buildroot/pool/*/*/*/*|grep -v ":"|grep ".deb")
	
	# find package names which are listed twice
	duplicates=$(echo $files|tr "\ " "\n"|cut -d"_" -f1|uniq -d)

	for curdupname in ${duplicates}; do
		curdupfiles=$(ls `echo "$files"|tr "\ " "\n"|grep "${curdupname}\_"|tr "\n" "\ "`)
		
		# seperate packages with different architectures
		curdupamd64=$(echo $curdupfiles|tr "\ " "\n"|grep amd64)
		curdupi386=$(echo $curdupfiles|tr "\ " "\n"|grep i386)
		curdupall=$(echo $curdupfiles|tr "\ " "\n"|grep all)
		
		# check the amount of packages per architecture
		nramd64=$(echo $curdupamd64|wc -w)
		nri386=$(echo $curdupi386|wc -w)
		nrall=$(echo $curdupall|wc -w)
		
		# remove the everything but the latest package, good thing ls sorts alphabethically
		if [ ${nramd64} -gt 1 ]; then
			toremove=$(echo $curdupamd64|cut -f1-$((nramd64-1)) -d" ")
			echo "Removing: $toremove"
			rm ${toremove}
			tokeep=$(echo $curdupamd64|cut -f$((nramd64)) -d" ")
			echo "Keeping: $tokeep"
		fi
		if [ ${nri386} -gt 1 ]; then
			toremove=$(echo $curdupi386|cut -f1-$((nri386-1)) -d" ")
			echo "Removing: $toremove"
			rm ${toremove}
			tokeep=$(echo $curdupi386|cut -f$((nri386)) -d" ")
			echo "Keeping: $tokeep"
		fi
		if [ ${nrall} -gt 1 ]; then
			toremove=$(echo $curdupall|cut -f1-$((nrall-1)) -d" ")
			echo "Removing: $toremove"
			rm ${toremove}
			tokeep=$(echo $curdupall|cut -f$((nrall)) -d" ")
			echo "Keeping: $tokeep"
		fi

	done
}

createiso ( ) {
	#Make sure ${CACHEDIR} exists
	if [ ! -d ${CACHEDIR} ]; then
		mkdir -p ${CACHEDIR}
	fi

	#Generate our new repos
	echo ""
	echo "Generating Packages.."
	apt-ftparchive generate ${APTCONF}
	apt-ftparchive generate ${APTUDEBCONF}
	echo "Generating Release for ${DISTNAME}"
	apt-ftparchive -c ${APTCONF} release ${BUILD}/dists/${DISTNAME} > ${BUILD}/dists/${DISTNAME}/Release

	#gpg --default-key "0E1FAD0C" --output $BUILD/dists/$DISTNAME/Release.gpg -ba $BUILD/dists/$DISTNAME/Release
	cd ${BUILD}
	find . -type f -print0 | xargs -0 md5sum > md5sum.txt
	cd -

	#Remove old ISO
	if [ -f ${ISOPATH}/${ISONAME} ]; then
		echo "Removing old ISO ${ISOPATH}/${ISONAME}"
		rm -f "${ISOPATH}/${ISONAME}"
	fi
	
	#Find isohdpfx.bin
	if [ -f "/usr/lib/syslinux/mbr/isohdpfx.bin" ]; then
		SYSLINUX="/usr/lib/syslinux/mbr/isohdpfx.bin"
	fi
	if [ -f "/usr/lib/syslinux/isohdpfx.bin" ]; then
		SYSLINUX="/usr/lib/syslinux/isohdpfx.bin"
	fi
	if [ -z $SYSLINUX ]; then
		echo "Error: isohdpfx not found! If you're a debian user, install the syslinux and syslinux-common packages from Ubuntu."
		exit 1	
	fi
	
	#Build the ISO
	echo "Building ${ISOPATH}/${ISONAME} ..."
	xorriso -as mkisofs -r -checksum_algorithm_iso md5,sha1,sha256,sha512 \
		-V "${ISOVNAME}" -o ${ISOPATH}/${ISONAME} \
		-J -isohybrid-mbr ${SYSLINUX} \
		-joliet-long -b isolinux/isolinux.bin \
		-c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
		-boot-info-table -eltorito-alt-boot -e boot/grub/efi.img \
		-no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus ${BUILD}
}

#Generate a file with the md5 checksum in it
mkchecksum ( ) {
	echo "Generating checksum..."
	md5sum ${ISONAME} > "${ISONAME}.md5"
	if [ -f ${ISONAME}.md5 ]; then
		echo "Checksum saved in ${ISONAME}.md5"
	else
		echo "Failed to save checksum"
	fi
}


#Setup command line arguments
while getopts "hd" OPTION; do
        case ${OPTION} in
        h)
                usage
                exit 1
        ;;
        d)
                redownload="1"
        ;;
        *)
                echo "${OPTION} - Unrecongnized option"
                usage
                exit 1
        ;;
        esac
done

#Check dependencies
deps

#Rebuild ${BUILD}
rebuild

#Make sure ${BUILD} exists
if [ ! -d ${BUILD} ]; then
	mkdir -p ${BUILD}
fi

#Verify we have an expected installer
verify

#Download and extract the SteamOSInstaller.zip
extract

#Build the buildroot for Rocket installer
createbuildroot

#Remove all but the latest if multiple versions of a package are present
checkduplicates

#Build the iso for Rocket installer
createiso

#Generate rocket.iso.md5 file
mkchecksum

#Report on packages where newer is in the archive
obsoletereport
