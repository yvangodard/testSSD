#!/bin/bash

# Variables initialisation
version="testSSD v0.5 - 2016, Yvan Godard [godardyvan@gmail.com]"
versionOSX=$(sw_vers -productVersion)
scriptDir=$(dirname "${0}")
scriptName=$(basename "${0}")
scriptNameWithoutExt=$(echo "${scriptName}" | cut -f1 -d '.')
actualLocalVersion=0.5
listOfDisks=$(diskutil list | grep "/dev/" | awk '{print $1}')
hasSSD=0
numberOfTrim=0
trimEnabled=0
trimNotEnabled=0
githubRoot="https://raw.githubusercontent.com/yvangodard/testSSD/master/"
githubVersion="${githubRoot%/}/version.txt"
githubScript="${githubRoot%/}/testSSD.sh"

# Exécutable seulement par root
if [ `whoami` != 'root' ]; then
	echo "Ce script doit être utilisé par le compte root. Utilisez 'sudo'."
	exit 1
fi

# Auto update du script
function checkUrl() {
  command -p curl -Lsf "$1" >/dev/null
  echo "$?"
}

# Changement du séparateur par défaut
OLDIFS=$IFS
IFS=$'\n'

if [[ $(checkUrl ${githubVersion}) -eq 0 ]] && [[ $(checkUrl ${githubScript}) -eq 0 ]]; then
	remoteVersion=$(command -p curl -Lsf ${githubVersion})
	if [[ "${remoteVersion}" > "${actualLocalVersion}" ]]; then
		[[ -e "${0}.old" ]] && rm ${0}.old
		mv ${0} ${0}.old
		command -p curl -Lsf ${githubScript} >> ${0}
		if [ $? -eq 0 ]; then
			chmod +x ${0}
			command ${0} "$@"
			exit $0
		else
			echo "Un problème a été rencontré pour mettre à jour ${0}."
		fi
		#echo "Le script ${0} a été mis à jour en version ${remoteVersion}"
	#else
		#echo "Le script ${0} n'a pas été mis à jour. Vous disposez de la dernière version (${remoteVersion})."
	fi
fi

echo "* Recherche SSD"
# On vérifie le statut SSD avec la commande system_profiler car avec diskutil, certains SSD patchés pour le support de TRIM ne sont plus reconnus comme SSD
for disque in $(system_profiler -detailLevel mini SPSerialATADataType | grep "Medium Type"); do
	echo "${disque}" | grep "Solid State" > /dev/null 2>&1
	[ $? -eq 0 ] && let hasSSD=${hasSSD}+1
done

# Check du TRIM Support
# [[ ${trimNotEnabled} -ne 0 ]] >> support Trim non activé
if [[ ${hasSSD} -ne 0 ]]; then
	echo "Cette machine possède un ou plusieurs disque(s) SSD"
	echo "* Test fonction TRIM"
	for trimSupport in $(system_profiler -detailLevel mini SPSerialATADataType | grep "TRIM Support" | awk '{print $3}') ; do
		let numberOfTrim=${numberOfTrim}+1
		[[ "${trimSupport}" == "No" ]] && let trimNotEnabled=${trimNotEnabled}+1
		[[ "${trimSupport}" == "Yes" ]] && let trimEnabled=${trimEnabled}+1
	done

	# Si trim support = Yes sur chaque occurence, alors TRIM est correctement activé
	if [[ ${trimEnabled} -eq ${numberOfTrim} ]]; then
		echo "La fonction TRIM est correctement activée sur votre/vos disque(s) SSD"
	else
		[[ ${trimNotEnabled} -eq 0 ]] && echo "La fonction TRIM n'est pas activée sur votre/vos disque(s) SSD" && echo "mais ne semble pas correctement prise en charge"
		[[ ${trimNotEnabled} -gt 0 ]] && echo "La fonction TRIM n'est pas activée sur votre/vos disque(s) SSD"
	fi
else
	echo "Cette machine ne possède pas de disque SSD"
fi

echo "* Disques"
for disk in ${listOfDisks}
do
	isInternalDisk=0
	isSSD=0
	isAPPLE=0
	message=""

	# Test interne / externe
	[[ $(diskutil info ${disk} | awk '/Device Location/ { print $NF }') == "Internal" ]] && let isInternalDisk=${isInternalDisk}+1
	[[ $(diskutil info ${disk} | awk '/Internal:/ { print $NF }') == "Yes" ]] && let isInternalDisk=${isInternalDisk}+1

	# Test nom Apple Original
	diskutil info ${disk} | grep "Media Name" | grep "APPLE" > /dev/null 2>&1
	[ $? -eq 0 ] && let isAPPLE=${isAPPLE}+1

	# Test SSD
	[[ $(diskutil info ${disk} | grep "Solid State" | awk -F " " '{print $3}') == "Yes" ]] && let isSSD=${isSSD}+1 && let hasSSD=${hasSSD}+1

	[[ ${isSSD} -ne 0 ]] && [[ ${isAPPLE} -eq 0 ]] && let hasOneNonAppleSSD=${hasOneNonAppleSSD}+1


	if [[ ${isSSD} -ne 0 ]]; then
		message="Disque SSD -"
		if [[ ${isAPPLE} -ne 0 ]]; then
			message="${message} Apple original -"
			if [[ ${isInternalDisk} -eq 0 ]]; then 
				message="${message} Externe"
			elif [[ ${isInternalDisk} -gt 0 ]]; then
				message="${message} Interne"
			fi
		elif [[ ${isAPPLE} -eq 0 ]]; then
			message="${message} non original Apple -"
			if [[ ${isInternalDisk} -eq 0 ]]; then 
				message="${message} Externe"
			elif [[ ${isInternalDisk} -gt 0 ]]; then
				message="${message} Interne"
			fi
		fi
	elif [[ ${isSSD} -eq 0 ]]; then
		message="Disque (non SSD) -"
		if [[ ${isAPPLE} -ne 0 ]]; then
			message="${message} Apple original -"
			if [[ ${isInternalDisk} -eq 0 ]]; then 
				message="${message} Externe"
			elif [[ ${isInternalDisk} -gt 0 ]]; then
				message="${message} Interne"
			fi
		elif [[ ${isAPPLE} -eq 0 ]]; then
			message="${message} non original Apple -"
			if [[ ${isInternalDisk} -eq 0 ]]; then 
				message="${message} Externe"
			elif [[ ${isInternalDisk} -gt 0 ]]; then
				message="${message} Interne"
			fi
		fi
	fi

echo "${disk} - ${message}"
done

echo "* SSD Non original Apple (susceptible de faux positifs)"
[[ ${hasOneNonAppleSSD} -ne 0 ]] && echo "Cet ordinateur sembler posséder un ou plusieurs disque(s) interne(s) SSD non originaux Apple"
[[ ${hasOneNonAppleSSD} -eq 0 ]] && echo "Cet ordinateur ne semble pas posséder de disque interne SSD non original Apple"

IFS=$OLDIFS

exit 0
