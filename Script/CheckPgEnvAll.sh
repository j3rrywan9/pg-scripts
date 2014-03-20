#!/bin/bash
#------------------------------------------------------------------------------
#	Check the status of every DBMS in every environment.
#------------------------------------------------------------------------------
PgVersions=${1}
Environments=${2}

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
test -n "${Environments}"	|| Environments="$(targets)"
test -n "${PgVersions}"		|| PgVersions="${EDB_NO_DOT_VERSIONS} ${PG_NO_DOT_VERSIONS}"

for myPgVersion in ${PgVersions}
do
	#----------------------------------------------------------------------
	#	Set PostgreSQL Version links.
	#----------------------------------------------------------------------
	rm ${SCRIPT_DIR}/PG_ROOT.sh
	ln -s ${SCRIPT_DIR}/PG_ROOT${myPgVersion}.sh ${SCRIPT_DIR}/PG_ROOT.sh

	for Environment in ${Environments}
	do
		build_pg_env_arrays ${Environment}
		DbmsOwner="${PRIMARY_OWNER[$(stoi ${Environment})]}"
		Sudo="$(do_sudo ${DbmsOwner})"

		#--------------------------------------------------------------
		#	Check the DBMS that comprise the environment.
		#--------------------------------------------------------------
		${Sudo} ${SCRIPT_DIR}/CheckPgEnv.sh ${Environment}
		Rc=$?

		if	[ ${Rc} -eq 0 ]
		then
			write_log "PostgreSQL: ${myPgVersion}: ${Environment}: O.K."

		elif	[ ${Rc} -eq 1 ]
		then
			write_log "PostgreSQL: ${myPgVersion}: ${Environment}: Not O.K."

		elif	[ ${Rc} -eq 2 ]
		then
			write_log "PostgreSQL: ${myPgVersion}: ${Environment}: Indeterminate"

		else
			write_log "Unexpected Exit Code received from 'CheckPgEnv.sh'"
		fi

		sleep 1	# Ensure unique Log File names.
	done
done

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
do_exit
