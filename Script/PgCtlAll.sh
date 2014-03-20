#!/bin/bash
#------------------------------------------------------------------------------
#	Run pg_ctl for all DBMS in all environments.
#	Also start|stop|status pg_receivexlog if necessary.
#------------------------------------------------------------------------------
Action=${1:?"ERROR: Please specify a pg_ctl option, e.g. status."}

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

exit_if_not_user root

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
Environments="$(targets)"
PgVers="${PG_VERSIONS}"
PST="Primary Secondary Tertiary"
ReceiveXlogPrefix="pg_receivexlog-"
ScriptDir="/etc/init.d"
ScriptPrefix="postgresql-"

ssh_commands

for PgVer in ${PgVers}
do
	for Environment in ${Environments}
	do
		build_pg_env_arrays ${Environment}

		PrimaryData="${PRIMARY_DATA[$(stoi ${Environment})]}"
		SecondaryData="${SECONDARY_DATA[$(stoi ${Environment})]}"
		TertiaryData="${TERTIARY_DATA[$(stoi ${Environment})]}"

		for Ordinal in ${PST}
		do
			Dbms="${ScriptDir}/${ScriptPrefix}${PgVer}-${Environment}${Ordinal}"
			ReceiveXlog="${ScriptDir}/${ReceiveXlogPrefix}${PgVer}.sh"

			if	[ "${Ordinal}" = "Primary" ]
			then
				if	[ "${SSH_PRIMARY}" ]
				then
					${SSH_PRIMARY}			\
						"test -x ${Dbms}	\
							&& ${Dbms} ${Action}"
				else
					test -x ${Dbms}	\
						&& ${Dbms} ${Action}
				fi
	
			elif	[ "${Ordinal}" = "Secondary" ] && [ "${SecondaryData}" ]
			then
				if	[ "${SSH_SECONDARY}" ]
				then
					${SSH_SECONDARY}					\
						"test -x ${Dbms}				\
							&& ${Dbms} ${Action}			\
							&& [ "${Environment}" = "ReceiveXlog" ]	\
							&& ${ReceiveXlog} ${Action}"
				else
					test -x ${Dbms}					\
						&& ${Dbms} ${Action}			\
						&& [ "${Environment}" = "ReceiveXlog" ]	\
						&& ${ReceiveXlog} ${Action}
				fi
	
			elif	[ "${Ordinal}" = "Tertiary" ] && [ "${TertiaryData}" ]
			then
				if	[ "${SSH_TERTIARY}" ]
				then
					${SSH_TERTIARY}			\
						"test -x ${Dbms}	\
							&& ${Dbms} ${Action}"
				else
					test -x ${Dbms}	\
						&& ${Dbms} ${Action}
				fi
			fi

		done
	done
done

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
exit
