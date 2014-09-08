#!/bin/bash
#------------------------------------------------------------------------------
#	Destroy a PostgreSQL instance.
#------------------------------------------------------------------------------

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
#	Validate the DBMS type.
#------------------------------------------------------------------------------
TARGET=${1:?"ERROR: Please specify a DBMS type from the list '$(targets)'."}

valid_target ${TARGET}
Rc=$?

if	[ ${Rc} -ne 0 ]
then
	echo "Invalid DBMS type '${TARGET}'"
	echo "Please select from the list '$(targets)'."
	exit 1
fi

#------------------------------------------------------------------------------
#	Local Functions.
#------------------------------------------------------------------------------
exit_on_error()	{
	#----------------------------------------------------------------------
	#	Exit on error.
	#----------------------------------------------------------------------
	ErrorText="${1}"
	echo "${ErrorText}"
	echo "Exiting ..."
	exit 1
}

remove_PGDATA()	{
	#----------------------------------------------------------------------
	#	Remove the PostgreSQL data files.
	#----------------------------------------------------------------------
	Me="remove_PGDATA"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}
	Prefix=""

	if	[ "${PorSorT}" = "${PRIMARY}" ]
	then
		PgData=${PRIMARY_DATA}
		Prefix="${SSH_PRIMARY}"

	elif	[ "${PorSorT}" = "${SECONDARY}" ]
	then
		PgData=${SECONDARY_DATA}
		Prefix="${SSH_SECONDARY}"

	elif	[ "${PorSorT}" = "${TERTIARY}" ]
	then
		PgData=${TERTIARY_DATA}
		Prefix="${SSH_TERTIARY}"
	else
		echo "Option '${PorSorT}' is invalid."
		exit_on_error "Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."
	fi

	${Prefix} rm -rf ${PgData} ${TABLESPACES}

	if	[ "${TARGET}" = "ConfigSansData" ]
	then
		${Prefix} rm -rf ${PRIMARY_DATA_SANS_CONFIG}
	fi
}

remove_WAL_archive()	{
	#----------------------------------------------------------------------
	#	Remove the WAL file archive directory.
	#----------------------------------------------------------------------
	${SSH_SECONDARY} rm -rf ${WAL_FILES}
}

stop_pg()	{
	#----------------------------------------------------------------------
	#	Stop PostgreSQL.
	#----------------------------------------------------------------------
	Me="stop_pg"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}
	Prefix=""

	if	[ "${PorSorT}" = "${PRIMARY}" ]
	then
		PgData=${PRIMARY_DATA}
		Prefix="${SSH_PRIMARY}"

	elif	[ "${PorSorT}" = "${SECONDARY}" ]
	then
		PgData=${SECONDARY_DATA}
		Prefix="${SSH_SECONDARY}"

	elif	[ "${PorSorT}" = "${TERTIARY}" ]
	then
		PgData=${TERTIARY_DATA}
		Prefix="${SSH_TERTIARY}"
	else
		echo "Option '${PorSorT}' is invalid."
		exit_on_error "Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."
	fi

	if	[ "${PG_VERSION}" = "9.1" ] && [ "${TARGET}" = "ConfigSansData" ]
	then
		PgData="${PgData}_DATA"
	fi

	${Prefix} ${PG_CTL} -D ${PgData} stop --mode=immediate
}

stop_pg_receivexlog()	{
	#----------------------------------------------------------------------
	#	Stop pg_receivexlog.
	#----------------------------------------------------------------------
	PIDfile="${WAL_FILES}/pg_receivexlog.pid"

	if	[ "${SSH_SECONDARY}" ]
	then
		${SSH_SECONDARY} kill \$\(cat ${PIDfile}\)
	else
		kill $(cat ${PIDfile})
	fi
}

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
PRIMARY="primary"	# ReadWrite DBMS replicating to Secondary DBMS.
SECONDARY="secondary"	# ReadOnly DBMS receiving updates from Primarty DBMS.
TABLESPACES="${PG_HOME}/UserTablespace/${TARGET}"
TERTIARY="tertiary"     # ReadOnly DBMS receiving updates from Secondary DBMS.
WAL_FILES="${PG_HOME}/WALarchive/${TARGET}"

#------------------------------------------------------------------------------
#	DBMS specific PostgreSQL environment variables. 
#------------------------------------------------------------------------------
build_pg_env_arrays ${TARGET}

REPLICATING_ENVIRONMENT="${REPLICATING[$(stoi ${TARGET})]}"

PRIMARY_DATA="${PRIMARY_DATA[$(stoi ${TARGET})]}"
PRIMARY_HOST="${PRIMARY_HOST[$(stoi ${TARGET})]}"
PRIMARY_OWNER="${PRIMARY_OWNER[$(stoi ${TARGET})]}"
SECONDARY_DATA="${SECONDARY_DATA[$(stoi ${TARGET})]}"
SECONDARY_HOST="${SECONDARY_HOST[$(stoi ${TARGET})]}"
TERTIARY_DATA="${TERTIARY_DATA[$(stoi ${TARGET})]}"
TERTIARY_HOST="${TERTIARY_HOST[$(stoi ${TARGET})]}"

PRIMARY_DATA_SANS_CONFIG="${PRIMARY_DATA}_DATA"

ssh_commands

exit_if_not_user ${PRIMARY_OWNER}

#------------------------------------------------------------------------------
#	Destroy the instance(s).
#------------------------------------------------------------------------------
echo "Destroying '${TARGET}' PostgreSQL DBMS."

#------------------------------------------------------------------------------
#	Stop the Primary DBMS.
#------------------------------------------------------------------------------
echo "Stopping the PostgreSQL instance at '${PRIMARY_HOST}:${PRIMARY_DATA}'."
stop_pg ${PRIMARY}

#------------------------------------------------------------------------------
#	Remove the Primary data files.
#------------------------------------------------------------------------------
echo "Removing the data files from '${PRIMARY_HOST}:${PRIMARY_DATA}'."
remove_PGDATA ${PRIMARY}

if	[ "${REPLICATING_ENVIRONMENT}" ]

then
	#----------------------------------------------------------------------
	#	Stop the Secondary DBMS.
	#----------------------------------------------------------------------
	echo "Stopping the Secondary DBMS at '${SECONDARY_HOST}:${SECONDARY_DATA}'."
	stop_pg ${SECONDARY}

	if	[ "${TARGET}" = "ReceiveXlog" ]
	then
		echo "Stopping 'pg_receivexlog' on ${SECONDARY_HOST}'."
		stop_pg_receivexlog
	fi

	#----------------------------------------------------------------------
	#	Remove the Secondary data files.
	#----------------------------------------------------------------------
	echo "Removing the data files from '${SECONDARY_HOST}:${SECONDARY_DATA}'."
	remove_PGDATA ${SECONDARY}

	if	[ "${TARGET}" = "Cascading" ]
	then
		#--------------------------------------------------------------
		#	Stop the Tertiary DBMS.
		#--------------------------------------------------------------
		echo "Stopping the Tertiary DBMS at '${TERTIARY_HOST}:${TERTIARY_DATA}'."
		stop_pg ${TERTIARY}
	
		#--------------------------------------------------------------
		#	Remove the Tertiary data files.
		#--------------------------------------------------------------
		echo "Removing the data files from '${TERTIARY_HOST}:${TERTIARY_DATA}'."
		remove_PGDATA ${TERTIARY}
	fi

	#----------------------------------------------------------------------
	#	Remove the WAL file archive directory.
	#----------------------------------------------------------------------
	echo "Removing the WAL archive from '${SECONDARY_HOST}:${WAL_FILES}'."
	remove_WAL_archive
fi

echo "Done."

#------------------------------------------------------------------------------
#	End
#------------------------------------------------------------------------------
