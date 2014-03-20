#!/bin/bash
#------------------------------------------------------------------------------
#	This script is intended to be called via PostgreSQL's
#	archive_cleanup_command in '$PGDATA/recovery.conf'.
#------------------------------------------------------------------------------
Restart=${1:?"ERROR: The last valid restart point is mandatory."}
WalArchive=${2:?"ERROR: The name of the directory containing the WAL archive is mandatory."}

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

ArchiveCleanupDebug="${RootFile}.ARCHIVE_CLEANUP.DEBUG"
ArchiveCleanupDisabled="${RootFile}.ARCHIVE_CLEANUP.DISABLED"
LogFile="${RootFile}.ARCHIVE_CLEANUP.log"
PgArchiveCleanup="${WAL_BIN_DIR}/pg_archivecleanup"

if	[ -f "${ArchiveCleanupDebug}" ]
then
	Debug="True"
fi

#------------------------------------------------------------------------------
#	Copy the WAL file.
#------------------------------------------------------------------------------
if	[ ! -f "${ArchiveCleanupDisabled}" ]
then
	write_debug "Cleaning '${ArchiveDir}', Restart point is '${Restart}'."
	${PgArchiveCleanup} ${ArchiveDir} ${Restart}
	write_debug "Done"
else
	write_debug "Cleaning of '${ArchiveDir}' is disabled."
fi

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
