#!/bin/bash
#------------------------------------------------------------------------------
#	Create or Destroy all PostgreSQL instances.
#------------------------------------------------------------------------------
Task=${1:?"ERROR: Please specify either 'Create' or 'Destroy'."}

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Validate the input.
#------------------------------------------------------------------------------
if	[ "${Task}" = "Create" ] || [ "${Task}" = "Destroy" ]
then
	Script="${SCRIPT_DIR}/${Task}PgInstance.sh"
else
	write_log "Invalid option."
	write_log "Exiting ..."
	exit 1
fi

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
Environments="$(targets)"

for myPgVersion in ${PG_NO_DOT_VERSIONS}
do
	write_log "PostgreSQL Version: ${myPgVersion}"

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

		write_log "${Task}: ${Environment}"

		if	[ "${Environment}" = "OffTheShelf" ]	\
				&& [ ${myPgVersion} != "92" ]
		then
			#------------------------------------------------------
			#	There can only be a single 'OffTheShelf'
			#	environment running at one time.
			#------------------------------------------------------
			write_log "Will not ${Task} '${Environment}'"
			continue
		fi

		${Sudo} ${Script} ${Environment} >> ${LOG_FILE} 2>&1
	done
done

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
do_exit
