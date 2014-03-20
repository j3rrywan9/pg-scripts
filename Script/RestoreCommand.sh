#!/bin/bash
#------------------------------------------------------------------------------
#	This script is intended to be called via PostgreSQL's
#	restore_command in '$PGDATA/recovery.conf'.
#------------------------------------------------------------------------------
Fqfn=${1:?"ERROR: Fully qualified name of the WAL file to archive is mandatory."}
Fn=${2:?"ERROR: The name of the WAL file to archive is mandatory."}
WalArchive=${3:?"ERROR: The name of the directory containing the WAL archive is mandatory."}

set -e

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

ArchiveDir="${WAL_ROOT_DIR}/WALarchive/${WalArchive}"
RootFile="${WAL_ROOT_DIR}/DxDebug/${WalArchive}"

LogFile="${RootFile}.LOG_RESTORE.log"
LogRestoreDebug="${RootFile}.LOG_RESTORE.DEBUG"
LogRestoreDisabled="${RootFile}.LOG_RESTORE.DISABLED"

if	[ -f "${LogRestoreDebug}" ]
then
	Debug="True"
fi

#------------------------------------------------------------------------------
#	Copy the WAL file.
#------------------------------------------------------------------------------
if	[ ! -f "${LogRestoreDisabled}" ]
then
	write_debug "Restoring '${ArchiveDir}/${Fn}' to '${Fqfn}'."
	cp ${ArchiveDir}/${Fn} ${Fqfn}
	write_debug "Done"
else
	write_debug "WAL restore is disabled for '${WalArchive}'."
fi

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
