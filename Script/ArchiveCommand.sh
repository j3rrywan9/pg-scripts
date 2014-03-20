#!/bin/bash
#------------------------------------------------------------------------------
#	This script is intended to be called via PostgreSQL's archive_command.
#------------------------------------------------------------------------------
Fqfn=${1:?"ERROR: Fully qualified name of the WAL file to archive is mandatory."}
Fn=${2:?"ERROR: The name of the WAL file to archive is mandatory."}
WalArchive=${3:?"ERROR: The name of the directory containing the WAL archive is mandatory."}

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
SCRIPT_DIR="${MY_FULL_DIR}"
FUNCTION_DIR="${SCRIPT_DIR}/Function"

#------------------------------------------------------------------------------
#	Common Functions.
#------------------------------------------------------------------------------
source ${SCRIPT_DIR}/PG_ROOT.sh

for function in $(ls ${FUNCTION_DIR}/*.sh)
do
	source ${function}
done

#------------------------------------------------------------------------------
#	Local functions.
#------------------------------------------------------------------------------
write_debug()	{
	if	[ -n "${Debug}" ]
	then
		echo "$(date): ${1}" >> ${LogFile}
	fi
}

#------------------------------------------------------------------------------
#	Local variables.
#------------------------------------------------------------------------------
WAL_environment ${PGDATA}

ArchiveHost=""
ArchiveDir="${WAL_ROOT_DIR}/WALarchive/${WalArchive}"
RootFile="${WAL_ROOT_DIR}/DxDebug/${WalArchive}"

LogFile="${RootFile}.LOG_SHIPPING.log"
LogShippingDebug="${RootFile}.LOG_SHIPPING.DEBUG"
LogShippingDisabled="${RootFile}.LOG_SHIPPING.DISABLED"

#------------------------------------------------------------------------------
#	Validate the Archive name.
#------------------------------------------------------------------------------
valid_target ${WalArchive}
Rc=$?

if	[ ${Rc} -ne 0 ]
then
	echo "ERROR: Invalid archive '${WalArchive}'"
	exit 1
fi

#------------------------------------------------------------------------------
#	Determine if the Primary and Secondary hosts are the same.
#------------------------------------------------------------------------------
build_pg_env_arrays ${WalArchive}

PRIMARY_HOST="${PRIMARY_HOST[$(stoi ${WalArchive})]}"
SECONDARY_HOST="${SECONDARY_HOST[$(stoi ${WalArchive})]}"

if	[ "${SECONDARY_HOST}" ] && [ "${PRIMARY_HOST}" != "${SECONDARY_HOST}" ]
then
	#------------------------------------------------------
	#	Secondary is remote.
	#------------------------------------------------------
	ArchiveHost="${SECONDARY_HOST}:"
fi

if	[ -f "${LogShippingDebug}" ]
then
	Debug="True"
fi

#------------------------------------------------------------------------------
#	Copy the WAL file.
#------------------------------------------------------------------------------
if	[ ! -f "${LogShippingDisabled}" ]
then
	write_debug "Copying '${Fn}' to '${ArchiveDir}/${Fn}'."
	rsync -a ${Fqfn} ${ArchiveHost}${ArchiveDir}/${Fn}
	write_debug "Done"
else
	write_debug "WAL shipping is disabled for '${WalArchive}'."
fi

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
