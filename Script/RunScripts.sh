#!/bin/bash
#------------------------------------------------------------------------------
#	Install the PostgreSQL features/objects in the appropriate DBMS.
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
test -n "${Environments}" || Environments="$(targets)"
GlobalScripts="
		CreatePartitionedTables.sh
		CreateTablePerType.sh 
		CreateUnloggedIndex.sh
		CreateUnloggedTables.sh
	"
NonReplicatingDbmsScripts="CreateTablespaces.sh"
test -n "${PgVersions}" || PgVersions="${EDB_NO_DOT_VERSIONS} ${PG_NO_DOT_VERSIONS}"
Replicating=""

for PgVersion in ${PgVersions}
do
	write_log "PostgreSQL Version: ${PgVersion}"
	PgIntegerVersion=$(echo ${PgVersion} | sed 's/[A-Za-z]//g')

	#----------------------------------------------------------------------
	#	Set PostgreSQL Version links.
	#----------------------------------------------------------------------
	rm ${SCRIPT_DIR}/PG_ROOT.sh
	ln -s ${SCRIPT_DIR}/PG_ROOT${PgVersion}.sh ${SCRIPT_DIR}/PG_ROOT.sh

	for Environment in ${Environments}
	do
		if	[ "${Environment}" = "OffTheShelf" ]	\
				&& [ ${PgIntegerVersion} -ne 92 ]
		then
			#------------------------------------------------------
			#	There can only be a single 'OffTheShelf'
			#	environment running at one time.
			#------------------------------------------------------
			continue
		fi

		#--------------------------------------------------------------
		#	Set DBMS Environment links.
		#--------------------------------------------------------------
		rm ${SCRIPT_DIR}/PgEnv.sh
		ln -s ${SCRIPT_DIR}/PgEnv.${Environment}.sh ${SCRIPT_DIR}/PgEnv.sh

		Replicating="$(replicating ${Environment})"
		write_log "Environment: ${Environment} ${Replicating}"

		for Script in ${GlobalScripts}
		do
			write_log "Executing ${Script}"
			${SCRIPT_DIR}/${Script}
		done

		if	[ ! "${Replicating}" ]
		then
			for Script in ${NonReplicatingDbmsScripts}
			do
				write_log "Executing ${Script}"
				${SCRIPT_DIR}/${Script}
			done
		fi

	Replicating=""

	done
done

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
do_exit
