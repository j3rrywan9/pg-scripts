#!/bin/bash
#------------------------------------------------------------------------------
#	Check the status of a PostgreSQL Environment.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Validate the target PostgreSQL environment.
#------------------------------------------------------------------------------
Target=${1:?"ERROR: Please specify an Environment from the list '$(targets)'."}

valid_target ${Target}
Rc=$?

if	[ ${Rc} -ne 0 ]
then
	echo "Invalid DBMS type '${Target}'"
	echo "Please select from the list '$(targets)'."
	exit 1
fi

#------------------------------------------------------------------------------
#	Local Functions.
#------------------------------------------------------------------------------
clean_up()	{
	do_sql ${PrimaryHost} ${PrimaryPort}		\
		${PrimaryDatabase} ${PrimaryUser}	\
		"drop database if exists ${Database}"	\
		>> ${LOG_FILE} 2>&1
	Rc=$?

	do_sql ${PrimaryHost} ${PrimaryPort}		\
		${PrimaryDatabase} ${PrimaryUser}	\
		"select pg_switch_xlog()"		\
		>> ${LOG_FILE} 2>&1
	Rc=$?

	return
}

dbms_status()	{
	#----------------------------------------------------------------------
	#	Determine the status of a DBMS.
	#----------------------------------------------------------------------
	Me="dbms_status"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${Primary}', '${Secondary}' or ${Tertiary}'."}
	Prefix=""

	if	[ "${PorSorT}" = "${Primary}" ]
	then
		PgDatabase=${PrimaryDatabase}
		PgHost=${PrimaryHost}
		PgPort=${PrimaryPort}
		PgUser=${PrimaryUser}

	elif	[ "${PorSorT}" = "${Secondary}" ]
	then
		PgDatabase=${SecondaryDatabase}
		PgHost=${SecondaryHost}
		PgPort=${SecondaryPort}
		PgUser=${SecondaryUser}

	elif	[ "${PorSorT}" = "${Tertiary}" ]
	then
		PgDatabase=${TertiaryDatabase}
		PgHost=${TertiaryHost}
		PgPort=${TertiaryPort}
		PgUser=${TertiaryUser}
	else
		echo "Option '${PorSorT}' is invalid."
		exit_on_error "Please specify '${Primary}', '${Secondary}' or ${Tertiary}'."
	fi

	#----------------------------------------------------------------------
	#	Is the DBMS up ?
	#----------------------------------------------------------------------
	pg_status ${PorSorT}
	Rc=$?
	ERROR_COUNT=$(expr ${ERROR_COUNT} + ${Rc})

	if	[ ${Rc} -eq 0 ]
	then
		write_log "DBMS is up."

		#--------------------------------------------------------------
		#	Connect to DBMS.
		#--------------------------------------------------------------
		if	[ "${PorSorT}" = "${Primary}" ]	\
				|| [ "${WalLevel}" = "hot_standby" ]
		then
			pg_connect ${PgHost} ${PgPort}		\
					${PgDatabase} ${PgUser}	\
					>> ${LOG_FILE} 2>&1
			Rc=$?
			ERROR_COUNT=$(expr ${ERROR_COUNT} + ${Rc})
				
			if	[ ${Rc} -eq 0 ]
			then
				write_log "DBMS is accessible."
				WalLevel="$(wal_level)"
			else
				write_log "DBMS is not accessible."
			fi
		else
			write_log "Unable to connect to the replica DBMS, it is not in 'hot_standby' mode."
			ERROR_COUNT=2
			do_exit
		fi
	else
		write_log "DBMS is down."
	fi

	return $?
}

do_sql()	{
	#----------------------------------------------------------------------
	#	Execute SQL.
	#----------------------------------------------------------------------
	PgHost=${1:?"ERROR: Please specify a value for PGHOST."}
	PgPort=${2:?"ERROR: Please specify a value for PGPORT."}
	PgDatabase=${3:?"ERROR: Please specify a value for PGDATABASE."}
	PgUser=${4:?"ERROR: Please specify a value for PGUSER."}
	Sql=${5:?"ERROR: Please specify an SQL statement to be executed."}
	
	${PSQL}	--command="${Sql}"	\
		--dbname=${PgDatabase}	\
		--echo-all		\
		--host=${PgHost}	\
		--port=${PgPort}	\
		--username=${PgUser}
	return $?
}

pg_connect()	{
	#----------------------------------------------------------------------
	#	Can we connect to the DBMS.
	#----------------------------------------------------------------------
	PgHost=${1:?"ERROR: Please specify a value for PGHOST."}
	PgPort=${2:?"ERROR: Please specify a value for PGPORT."}
	PgDatabase=${3:?"ERROR: Please specify a value for PGDATABASE."}
	PgUser=${4:?"ERROR: Please specify a value for PGUSER."}
	ConnectSQL="select current_database()"
	
	do_sql ${PgHost} ${PgPort} ${PgDatabase} ${PgUser} "${ConnectSQL}"
	return $?
}

pg_receivexlog_status()	{
	#----------------------------------------------------------------------
	#	pg_receivexlog status.
	#----------------------------------------------------------------------
	${SSH_SECONDARY} test -f ${PgReceiveXlogPidFile}
	Rc=$?

	if	[ ${Rc} -eq 0 ]
	then
		write_log "The pg_receivexlog PID file '${SecondaryHost}:${PgReceiveXlogPidFile}' exists"

		if	[ "${SSH_SECONDARY}" ]
		then
			${SSH_SECONDARY} kill -0 \$\(cat ${PgReceiveXlogPidFile}\) >> ${LOG_FILE} 2>&1
		else
			kill -0 $(cat ${PgReceiveXlogPidFile}) >> ${LOG_FILE} 2>&1
		fi

		if	[ ${Rc} -eq 0 ]
		then
			write_log "and pg_receivexlog is running."
		else
			write_log "but pg_receivexlog is not running."
		fi
	else
		write_log "The pg_receivexlog PID file '${PgReceiveXlogPidFile}' does not exist."
	fi

	return ${Rc}
}

pg_status()	{
	#----------------------------------------------------------------------
	#	Status of PostgreSQL.
	#----------------------------------------------------------------------
	Me="pg_status"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${Primary}', '${Secondary}' or ${Tertiary}'."}
	Prefix=""

	if	[ "${PorSorT}" = "${Primary}" ]
	then
		PgData=${PrimaryData}
		Prefix="${SSH_PRIMARY}"

	elif	[ "${PorSorT}" = "${Secondary}" ]
	then
		PgData=${SecondaryData}
		Prefix="${SSH_SECONDARY}"

	elif	[ "${PorSorT}" = "${Tertiary}" ]
	then
		PgData=${TertiaryData}
		Prefix="${SSH_TERTIARY}"
	else
		echo "Option '${PorSorT}' is invalid."
		exit_on_error "Please specify '${Primary}', '${Secondary}' or ${Tertiary}'."
	fi

	if	[ "${PG_VERSION}" = "9.1" ] && [ "${Target}" = "ConfigSansData" ]
	then
		PgData="${PgData}_DATA"
	fi

	${Prefix} ${PG_CTL} -D ${PgData} status >> ${LOG_FILE} 2>&1
}

replication_status()	{
	#----------------------------------------------------------------------
	#	Determine the status of replication.
	#----------------------------------------------------------------------

	#----------------------------------------------------------------------
	#	Add data to the Primary.
	#----------------------------------------------------------------------
	do_sql ${PrimaryHost} ${PrimaryPort}		\
		${PrimaryDatabase} ${PrimaryUser}	\
		"create database ${Database}"		\
		>> ${LOG_FILE} 2>&1
	Rc=$?
	ERROR_COUNT=$(expr ${ERROR_COUNT} + ${Rc})

	#----------------------------------------------------------------------
	#	Force a WAL file switch.
	#----------------------------------------------------------------------
	do_sql ${PrimaryHost} ${PrimaryPort}		\
		${PrimaryDatabase} ${PrimaryUser}	\
		"select pg_switch_xlog()"		\
		>> ${LOG_FILE} 2>&1
	Rc=$?
	ERROR_COUNT=$(expr ${ERROR_COUNT} + ${Rc})

	if	[ ${ERROR_COUNT} -eq 0 ]
	then
		#--------------------------------------------------------------
		#	Has the data has been replicated to the Secondary.
		#--------------------------------------------------------------
		sleep 10

		pg_connect ${SecondaryHost} ${SecondaryPort}	\
				${Database} ${SecondaryUser}	\
				>> ${LOG_FILE} 2>&1
		Rc=$?

		if	[ ${Rc} -eq 0 ]
		then
			write_log "Replication from Primary to Secondary is working."

			#------------------------------------------------------
			#	Secondary to Tertiary.
			#------------------------------------------------------
			if	[ "${TertiaryData}" ]
			then
				sleep 10

				pg_connect ${TertiaryHost}	\
						${TertiaryPort}	\
						${Database}	\
						${TertiaryUser}	\
						>> ${LOG_FILE} 2>&1
				Rc=$?

				if	[ ${Rc} -eq 0 ]
				then
					write_log "Replication from Secondary to Tertiary is working."
				else
					write_log "Replication from Secondary to Tertiary is not working."
				fi
			fi
		else
			write_log "Replication from Primary to Secondary not working."
		fi
	else
		write_log "Failed to create database and/or switch WAL file on Primary."
	fi
}

wal_level()	{
	#----------------------------------------------------------------------
	#	Determine the WAL level.
	#----------------------------------------------------------------------
	Sql="select setting from pg_settings where name = 'wal_level'"

	${PSQL}	--command="${Sql}"		\
		--dbname=${PrimaryDatabase}	\
		--host=${PrimaryHost}		\
		--port=${PrimaryPort}		\
		--username=${PrimaryUser}	\
		--no-align			\
		--tuples-only
}

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
ConnectSQL="select current_database()"
Database="temp_$(date '+%s')"
ERROR_COUNT=0
PgReceiveXlogPidFile="${PG_HOME}/WALarchive/ReceiveXlog/pg_receivexlog.pid"
Primary="primary"	# ReadWrite DBMS replicating to Secondary DBMS.
Secondary="secondary"	# ReadOnly DBMS receiving updates from Primarty DBMS.
Tertiary="tertiary"	# ReadOnly DBMS receiving updates from Secondary DBMS.

	#----------------------------------------------------------------------
	#	DBMS specific PostgreSQL environment variables. 
	#----------------------------------------------------------------------
build_pg_env_arrays ${Target}

PrimaryData="${PRIMARY_DATA[$(stoi ${Target})]}"
PrimaryDatabase="${PRIMARY_DATABASE[$(stoi ${Target})]}"
PrimaryHost="${PRIMARY_HOST[$(stoi ${Target})]}"
PrimaryPort="${PRIMARY_PORT[$(stoi ${Target})]}"
PrimaryUser="${PRIMARY_USER[$(stoi ${Target})]}"
SecondaryData="${SECONDARY_DATA[$(stoi ${Target})]}"
SecondaryDatabase="${SECONDARY_DATABASE[$(stoi ${Target})]}"
SecondaryHost="${SECONDARY_HOST[$(stoi ${Target})]}"
SecondaryPort="${SECONDARY_PORT[$(stoi ${Target})]}"
SecondaryUser="${SECONDARY_USER[$(stoi ${Target})]}"
TertiaryData="${TERTIARY_DATA[$(stoi ${Target})]}"
TertiaryDatabase="${TERTIARY_DATABASE[$(stoi ${Target})]}"
TertiaryHost="${TERTIARY_HOST[$(stoi ${Target})]}"
TertiaryPort="${TERTIARY_PORT[$(stoi ${Target})]}"
TertiaryUser="${TERTIARY_USER[$(stoi ${Target})]}"

ssh_commands

DbmsOwner="${PRIMARY_OWNER[$(stoi ${Target})]}"
exit_if_not_user ${DbmsOwner}

#------------------------------------------------------------------------------
#	Main.
#------------------------------------------------------------------------------
write_log	"PostgreSQL Version: ${PG_VERSION}, Environment '${Target}'"

#------------------------------------------------------------------------------
#	Primary DBMS.
#------------------------------------------------------------------------------
write_log	"Primary DBMS status."
dbms_status ${Primary}

#------------------------------------------------------------------------------
#	Secondary DBMS.
#------------------------------------------------------------------------------
if	[ "${SecondaryData}" ]
then
	write_log	"Secondary DBMS status."
	dbms_status ${Secondary}

	#----------------------------------------------------------------------
	#	Tertiary DBMS.
	#----------------------------------------------------------------------
	if	[ "${TertiaryData}" ]
	then
		write_log	"Tertiary DBMS status."
		dbms_status ${Tertiary}
	fi
fi

#------------------------------------------------------------------------------
#	Replication.
#------------------------------------------------------------------------------
if	[ "${SecondaryData}" ] 
then
	if	[ ${Target} = "ReceiveXlog" ]
	then
		#--------------------------------------------------------------
		#	Check pg_receivexlog daemon.
		#--------------------------------------------------------------
		write_log "pg_receivexlog status."
		pg_receivexlog_status
		Rc=$?
	fi

	if	[ ${ERROR_COUNT} -eq 0 ]
	then
		#--------------------------------------------------------------
		#	Replication Status.
		#--------------------------------------------------------------
		write_log "Replication Status."
		replication_status
	else
		write_log "Unable to check replication because of prior errors."
	fi
fi
	
#------------------------------------------------------------------------------
#	Exit.	[ 0 -> O.K.; 1 -> Not O.K.; 2 -> Indeterminate ]
#------------------------------------------------------------------------------
if	[ ${ERROR_COUNT} -gt 1 ]
then
	ERROR_COUNT=1
fi

do_exit
