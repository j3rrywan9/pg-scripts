#!/bin/bash
#------------------------------------------------------------------------------
#	Create a PostgreSQL instance.
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
add_postgresql_conf_customization()	{
	#----------------------------------------------------------------------
	#	Customize postgresql.conf
	#----------------------------------------------------------------------
	Me="add_postgresql_conf_customization"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}
	ConfigFile=${2:?"ERROR:(${Me}): Please specify a file of configuration changes"}

	RemoteConfigFile="/tmp/RemoteConfigFile.$$"

	if	[ "${PorSorT}" = "${PRIMARY}" ]
	then
		PgData=${PRIMARY_DATA}
		Prefix="${SSH_PRIMARY}"
		RemoteHost="${PRIMARY_HOST}:"

	elif	[ "${PorSorT}" = "${SECONDARY}" ]
	then
		PgData=${SECONDARY_DATA}
		Prefix="${SSH_SECONDARY}"
		RemoteHost="${SECONDARY_HOST}:"

	elif	[ "${PorSorT}" = "${TERTIARY}" ]
	then
		PgData=${TERTIARY_DATA}
		Prefix="${SSH_TERTIARY}"
		RemoteHost="${TERTIARY_HOST}:"

	else
		echo "Option '${PorSorT}' is invalid."
		exit_on_error "Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."
	fi

	if	[ "${Prefix}" ]
	then
		scp ${ConfigFile} ${RemoteHost}${RemoteConfigFile}
		${Prefix} "cat ${RemoteConfigFile} >> ${PgData}/postgresql.conf"
	else
		cat ${ConfigFile} >> ${PgData}/postgresql.conf
	fi

	${Prefix} rm -f ${RemoteConfigFile}

	#----------------------------------------------------------------------
	#	Return
	#----------------------------------------------------------------------
	return
}

baseline_backup()	{
	#----------------------------------------------------------------------
	#	Copy PGDATA from the Source to the Target.
	#----------------------------------------------------------------------
	Me="baseline_backup"
	Source=${1:?"ERROR:(${Me}): Please specify the source, either '${PRIMARY}' or '${SECONDARY}'."}

	if	[ "${Source}" = "${PRIMARY}" ]
	then
		#--------------------------------------------------------------
		#	Copying from Primary to Secondary.
		#--------------------------------------------------------------
		SourceHost=${PRIMARY_HOST}
		SourcePort=${PRIMARY_PORT}
		TargetDir=${SECONDARY_DATA}
		TargetHost=${SECONDARY_HOST}
		Prefix="${SSH_SECONDARY}"

	elif	[ "${Source}" = "${SECONDARY}" ]
	then
		#--------------------------------------------------------------
		#	Copying from Secondary to Tertiary.
		#--------------------------------------------------------------
		SourceHost=${SECONDARY_HOST}
		SourcePort=${SECONDARY_PORT}
		TargetDir=${TERTIARY_DATA}
		TargetHost=${TERTIARY_HOST}
		Prefix="${SSH_TERTIARY}"

	else
		exit_on_error "Source '${Source}' is unknown."
	fi

	#----------------------------------------------------------------------
	#	Copy the data.
	#----------------------------------------------------------------------
	${Prefix} ${PG_BASEBACKUP}	--host=${SourceHost}	\
					--pgdata=${TargetDir}	\
					--port=${SourcePort}	\
					--username=${REPLICATION_ROLE}

	#----------------------------------------------------------------------
	#	Remove unnecessary files from the target.
	#----------------------------------------------------------------------
	${Prefix} rm -f	${TargetDir}/pg_log/*		\
			${TargetDir}/postmaster.opts	\
			${TargetDir}/postmaster.pid
}

configure_primary()	{
	#----------------------------------------------------------------------
	#	Configure the Primary Host.
	#----------------------------------------------------------------------
	TempPgConfig="/tmp/TempPgConfig.$$"

	#----------------------------------------------------------------------
	#	Common "postgresql.conf" configuration.
	#----------------------------------------------------------------------
	cat > ${TempPgConfig} <<-EndOfFile
		archive_timeout = 60		${TAG}
		checkpoint_timeout = 1h		${TAG}
		listen_addresses = '*'		${TAG}
		log_line_prefix = '%t '		${TAG}
		logging_collector = on		${TAG}
		max_connections = 25		${TAG}
		max_wal_senders = 3		${TAG}
		port = ${PRIMARY_PORT}		${TAG}
		wal_level = 'archive'		${TAG}
	EndOfFile

	enterprisedb_configuration ${TempPgConfig}

	#----------------------------------------------------------------------
	#	Environment specific PostgreSQL configuration.
	#	(Usually nothing required for non-replicating installations)
	#----------------------------------------------------------------------
	if	[ "${TARGET}" = "WALshipping" ]
	then
		#--------------------------------------------------------------
		#	Configure 'postgresql.conf'.
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			archive_command = '${SCRIPT_DIR}/ArchiveCommand.sh %p %f ${TARGET}'	 ${TAG}
			archive_mode = on	 ${TAG}
			max_wal_senders = 3	 ${TAG}
			wal_level = 'archive'	 ${TAG}
		EndOfFile

	elif	[ "${TARGET}" = "WALshippingHot" ]
	then
		#--------------------------------------------------------------
		#	Configure 'postgresql.conf'.
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			archive_command = '${SCRIPT_DIR}/ArchiveCommand.sh %p %f ${TARGET}'	 ${TAG}
			archive_mode = on	 ${TAG}
			max_wal_senders = 3	 ${TAG}
			wal_level = 'hot_standby'	 ${TAG}
		EndOfFile

	elif	[ "${TARGET}" = "WALshippingHotStreaming" ]
	then
		#--------------------------------------------------------------
		#	Configure 'postgresql.conf'.
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			archive_command = '${SCRIPT_DIR}/ArchiveCommand.sh %p %f ${TARGET}'	 ${TAG}
			archive_mode = on	 ${TAG}
			max_wal_senders = 3	 ${TAG}
			wal_level = 'hot_standby'	 ${TAG}
		EndOfFile

	elif	[ "${TARGET}" = "Cascading" ]
	then
		#--------------------------------------------------------------
		#	Configure 'postgresql.conf'.
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			archive_command = '${SCRIPT_DIR}/ArchiveCommand.sh %p %f ${TARGET}'	 ${TAG}
			archive_mode = on	 ${TAG}
			max_wal_senders = 3	 ${TAG}
			wal_level = 'hot_standby'	 ${TAG}
		EndOfFile

	elif	[ "${TARGET}" = "ConfigSansData" ]
	then
		#--------------------------------------------------------------
		#	Configure 'postgresql.conf'.
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			data_directory = '${PRIMARY_DATA_SANS_CONFIG}'	${TAG}
		EndOfFile

	elif	[ "${TARGET}" = "ReceiveXlog" ]
	then
		#--------------------------------------------------------------
		#	Configure 'postgresql.conf'.
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			max_wal_senders = 3	 ${TAG}
			wal_level = 'hot_standby'	 ${TAG}
		EndOfFile

	fi

	#----------------------------------------------------------------------
	#	Append to the existing 'postgresql.conf'.
	#----------------------------------------------------------------------
	add_postgresql_conf_customization ${PRIMARY} ${TempPgConfig}

	#--------------------------------------------------------------
	#	Enable 'replication' role in pg_hba.conf.
	#--------------------------------------------------------------
	enable_replication_role ${PRIMARY}

	#----------------------------------------------------------------------
	#	Enable superuser access in pg_hba.conf.
	#----------------------------------------------------------------------
	enable_superuser_role ${PRIMARY}

	#----------------------------------------------------------------------
	#	Enable non-superuser access in pg_hba.conf.
	#----------------------------------------------------------------------
	enable_nonsuperuser_role ${PRIMARY}

	#----------------------------------------------------------------------
	#	Clean-up.
	#----------------------------------------------------------------------
	rm -f ${TempPgConfig}

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return
}

configure_secondary()	{
	#----------------------------------------------------------------------
	#	Configure the Secondary Host.
	#----------------------------------------------------------------------
	TempPgConfig="/tmp/TempPgConfig.$$"
	TempRecovery="/tmp/TempRecovery.$$"

	#----------------------------------------------------------------------
	#	Common "postgresql.conf" configuration.
	#----------------------------------------------------------------------
	cat > ${TempPgConfig} <<-EndOfFile
		listen_addresses = '*'		${TAG}
		log_line_prefix = '%t '		${TAG}
		logging_collector = on		${TAG}
		max_connections = 25		${TAG}
		port = ${SECONDARY_PORT}	${TAG}
	EndOfFile

	enterprisedb_configuration ${TempPgConfig}

	#----------------------------------------------------------------------
	#	Common "recovery.conf" configuration.
	#----------------------------------------------------------------------
	cat > ${TempRecovery} <<-EndOfFile
		archive_cleanup_command = '${SCRIPT_DIR}/ArchiveCleanupCommand.sh %r ${TARGET}'
		restore_command = '${SCRIPT_DIR}/RestoreCommand.sh %p %f ${TARGET}'
		standby_mode = on
	EndOfFile

	#----------------------------------------------------------------------
	#	Environment specific "postgresql.conf", "pg_hba.conf"
	# 	and "recovery.conf" configuration.
	#----------------------------------------------------------------------
	if	[ "${TARGET}" = "WALshippingHot" ]
	then
		#--------------------------------------------------------------
		#	postgresql.conf
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			hot_standby = on	${TAG}
			hot_standby_feedback = on	${TAG}
		EndOfFile

	elif	[ "${TARGET}" = "WALshippingHotStreaming" ]
	then
		#--------------------------------------------------------------
		#	postgresql.conf
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			hot_standby = on	${TAG}
			hot_standby_feedback = on	${TAG}
		EndOfFile

		#--------------------------------------------------------------
		#	recovery.conf
		#--------------------------------------------------------------
		cat >> ${TempRecovery} <<-EndOfFile
			primary_conninfo = 'host=${PRIMARY_HOST} port=${PRIMARY_PORT} user=${REPLICATION_ROLE} application_name=${SECONDARY_HOST}_port_${SECONDARY_PORT}'
		EndOfFile

	elif	[ "${TARGET}" = "Cascading" ]
	then
		#--------------------------------------------------------------
		#	postgresql.conf
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			hot_standby = on	${TAG}
			hot_standby_feedback = on	${TAG}
			max_wal_senders = 3	${TAG}
			wal_level = 'hot_standby'	${TAG}
		EndOfFile

		#--------------------------------------------------------------
		#	recovery.conf
		#--------------------------------------------------------------
		cat >> ${TempRecovery} <<-EndOfFile
			primary_conninfo = 'host=${PRIMARY_HOST} port=${PRIMARY_PORT} user=${REPLICATION_ROLE} application_name=${SECONDARY_HOST}_port_${SECONDARY_PORT}'
		EndOfFile

	elif	[ "${TARGET}" = "ReceiveXlog" ]
	then
		#--------------------------------------------------------------
		#	postgresql.conf
		#--------------------------------------------------------------
		cat >> ${TempPgConfig} <<-EndOfFile
			hot_standby = on	${TAG}
			hot_standby_feedback = on	${TAG}
		EndOfFile

	fi

	#----------------------------------------------------------------------
	#	Modify the configuration files.
	#----------------------------------------------------------------------
	remove_postgresql_conf_customization ${SECONDARY}
	add_postgresql_conf_customization ${SECONDARY} ${TempPgConfig}
	write_recovery_conf ${SECONDARY} ${TempRecovery}

	#----------------------------------------------------------------------
	#	Clean-up.
	#----------------------------------------------------------------------
	rm -f ${TempPgConfig} ${TempRecovery}

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return
}

configure_tertiary()	{
	#----------------------------------------------------------------------
	#	Configure the Tertiary Host.
	#----------------------------------------------------------------------
	TempPgConfig="/tmp/TempPgConfig.$$"
	TempRecovery="/tmp/TempRecovery.$$"

	if	[ "${TARGET}" = "Cascading" ]
	then
		#--------------------------------------------------------------
		#	postgresql.conf
		#--------------------------------------------------------------
		cat > ${TempPgConfig} <<-EndOfFile
			hot_standby = on	${TAG}
			hot_standby_feedback = on	${TAG}
			listen_addresses = '*'	${TAG}
			log_line_prefix = '%t '	${TAG}
			logging_collector = on	${TAG}
			max_connections = 25	${TAG}
			port = ${TERTIARY_PORT}	${TAG}
		EndOfFile

		enterprisedb_configuration ${TempPgConfig}

		#--------------------------------------------------------------
		#	recovery.conf
		#--------------------------------------------------------------
		cat > ${TempRecovery} <<-EndOfFile
			primary_conninfo = 'host=${SECONDARY_HOST} port=${SECONDARY_PORT} user=${REPLICATION_ROLE} application_name=${TERTIARY_HOST}_port_${TERTIARY_PORT}'
			standby_mode = on
		EndOfFile

		#--------------------------------------------------------------
		#	Modify the configuration files.
		#--------------------------------------------------------------
		remove_postgresql_conf_customization ${TERTIARY}
		add_postgresql_conf_customization ${TERTIARY} ${TempPgConfig}
		write_recovery_conf ${TERTIARY} ${TempRecovery}

		#--------------------------------------------------------------
		#	Clean-up.
		#--------------------------------------------------------------
		rm -f ${TempPgConfig} ${TempRecovery}
	fi

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return
}

create_role()	{
	#----------------------------------------------------------------------
	#	Create a PostgreSQL role.
	#----------------------------------------------------------------------
	Me="create_role"
	Name=${1:?"ERROR:(${Me}): You must specify a role name."}
	Options=${2:?"ERROR:(${Me}): You must specify a set of options."}
	Password=${3}

	Sql="CREATE ROLE ${Name} WITH LOGIN ${Options}"

	if	[ "${Password}" ]
	then
		Sql="${Sql} PASSWORD '${Password}'"
	fi

	if	[ "${SSH_PRIMARY}" ]
	then
		${SSH_PRIMARY} ${PSQL} -U ${SUPERUSER_ROLE} -d ${PRIMARY_DATABASE} -p ${PRIMARY_PORT} -c \"${Sql}\"
	else
		${PSQL} -U ${SUPERUSER_ROLE} -d ${PRIMARY_DATABASE} -p ${PRIMARY_PORT} -c "${Sql}"
	fi
}

disable_replication_role()	{
	#----------------------------------------------------------------------
	#	Disable the 'replication' role.
	#----------------------------------------------------------------------
	Me="disable_replication_role"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}

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

	if	[ "${Prefix}" ]
	then
		${Prefix} "sed /replication/d ${PgData}/pg_hba.conf > /tmp/pg_hba.conf"
	else
		sed /replication/d ${PgData}/pg_hba.conf > /tmp/pg_hba.conf
	fi

	${Prefix} mv /tmp/pg_hba.conf ${PgData}/pg_hba.conf
	${Prefix} rm -f /tmp/pg_hba.conf
}

drop_default_databases()	{
	#----------------------------------------------------------------------
	#	Drop the default databases postgres, template0 and template1.
	#----------------------------------------------------------------------
	Me="drop_default_databases"
	SqlFile="/tmp/drop_default_databases.sql.$$"

	cat > ${SqlFile} <<-EndOfFile
		create database my_template;
		update pg_database set datistemplate = true where datname = 'my_template';
		update pg_database set datistemplate = false where datname = 'template0';
		update pg_database set datistemplate = false where datname = 'template1';
		\connect my_template
		drop database postgres;
		drop database template0;
		drop database template1;
		create database my_postgres template my_template;
	EndOfFile

	if	[ "${SSH_PRIMARY}" ]
	then
		scp ${SqlFile} ${PRIMARY_HOST}:${SqlFile}
	fi

	${SSH_PRIMARY} ${PSQL} -U ${SUPERUSER_ROLE} -d ${PRIMARY_DATABASE} -p ${PRIMARY_PORT} -f ${SqlFile}
	rm -f ${SqlFile}
}

enable_nonsuperuser_role()	{
	#----------------------------------------------------------------------
	#	Grant 'postgres' remote TCP/IP access.
	#----------------------------------------------------------------------
	Me="enable_nonsuperuser_role"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}

	LocalHbaFile="/tmp/LocalHbaFile.$$"
	RemoteHbaFile="/tmp/RemoteHbaFile.$$"

	if	[ "${PorSorT}" = "${PRIMARY}" ]
	then
		PgData=${PRIMARY_DATA}
		Prefix="${SSH_PRIMARY}"
		RemoteHost="${PRIMARY_HOST}:"

	elif	[ "${PorSorT}" = "${SECONDARY}" ]
	then
		PgData=${SECONDARY_DATA}
		Prefix="${SSH_SECONDARY}"
		RemoteHost="${SECONDARY_HOST}:"

	elif	[ "${PorSorT}" = "${TERTIARY}" ]
	then
		PgData=${TERTIARY_DATA}
		Prefix="${SSH_TERTIARY}"
		RemoteHost="${TERTIARY_HOST}:"

	else
		echo "Option '${PorSorT}' is invalid."
		exit_on_error "Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."
	fi

	cat > ${LocalHbaFile} <<-EndOfFile
	#	Enable access for non-superuser [Start]
	local	all	${NON_SUPERUSER_ROLE}			trust
	host	all	${NON_SUPERUSER_ROLE}	127.0.0.1/32	trust
	host	all	${NON_SUPERUSER_ROLE}	::1/128		trust
	host	all	${NON_SUPERUSER_ROLE}	0.0.0.0/0	trust

	local	all	${NON_SUPERUSER_ROLE_UNTRUSTED}			md5
	host	all	${NON_SUPERUSER_ROLE_UNTRUSTED}	127.0.0.1/32	md5
	host	all	${NON_SUPERUSER_ROLE_UNTRUSTED}	::1/128		md5
	host	all	${NON_SUPERUSER_ROLE_UNTRUSTED}	0.0.0.0/0	md5

	#	Enable access for non-superuser [End]
	EndOfFile

	if	[ "${Prefix}" ]
	then
		scp ${LocalHbaFile} ${RemoteHost}${RemoteHbaFile}
		${Prefix} "cat ${RemoteHbaFile} >> ${PgData}/pg_hba.conf"

	else
		cat ${LocalHbaFile} >> ${PgData}/pg_hba.conf
	fi

	${Prefix} rm -f ${RemoteHbaFile}
	rm -f ${LocalHbaFile}
}

enable_replication_role()	{
	#----------------------------------------------------------------------
	#	Grant 'DELPHIX_REPLICATOR' the 'replication' role.
	#----------------------------------------------------------------------
	Me="enable_replication_role"
	PorS=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}' or '${SECONDARY}'."}

	LocalHbaFile="/tmp/LocalHbaFile.$$"
	RemoteHbaFile="/tmp/RemoteHbaFile.$$"

	if	[ "${PorS}" = "${PRIMARY}" ]
	then
		PgData=${PRIMARY_DATA}
		Prefix="${SSH_PRIMARY}"
		RemoteHost="${PRIMARY_HOST}:"

	elif	[ "${PorS}" = "${SECONDARY}" ]
	then
		PgData=${SECONDARY_DATA}
		Prefix="${SSH_SECONDARY}"
		RemoteHost="${SECONDARY_HOST}:"
	else
		echo "Option '${PorS}' is invalid."
		exit_on_error "Please specify '${PRIMARY}' or '${SECONDARY}'."
	fi

	cat > ${LocalHbaFile} <<-EndOfFile
	#	Enable access for the replicator role [Start]
	local	replication	${REPLICATION_ROLE}			trust
	host	replication	${REPLICATION_ROLE}	127.0.0.1/32	trust
	host	replication	${REPLICATION_ROLE}	::1/128		trust
	host	replication	${REPLICATION_ROLE}	0.0.0.0/0	trust

	local	replication	${REPLICATION_ROLE_UNTRUSTED}			md5
	host	replication	${REPLICATION_ROLE_UNTRUSTED}	127.0.0.1/32	md5
	host	replication	${REPLICATION_ROLE_UNTRUSTED}	::1/128		md5
	host	replication	${REPLICATION_ROLE_UNTRUSTED}	0.0.0.0/0	md5
	#	Enable access for the replicator role [End]
	EndOfFile

	if	[ "${Prefix}" ]
	then
		scp ${LocalHbaFile} ${RemoteHost}${RemoteHbaFile}
		${Prefix} "cat ${RemoteHbaFile} >> ${PgData}/pg_hba.conf"
	else
		cat ${LocalHbaFile} >> ${PgData}/pg_hba.conf
	fi

	${Prefix} rm -f ${RemoteHbaFile}
	rm -f ${LocalHbaFile}
}

enable_superuser_role()	{
	#----------------------------------------------------------------------
	#	Grant 'postgres' remote TCP/IP access.
	#----------------------------------------------------------------------
	Me="enable_superuser_role"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}

	LocalHbaFile="/tmp/LocalHbaFile.$$"
	RemoteHbaFile="/tmp/RemoteHbaFile.$$"

	if	[ "${PorSorT}" = "${PRIMARY}" ]
	then
		PgData=${PRIMARY_DATA}
		Prefix="${SSH_PRIMARY}"
		RemoteHost="${PRIMARY_HOST}:"

	elif	[ "${PorSorT}" = "${SECONDARY}" ]
	then
		PgData=${SECONDARY_DATA}
		Prefix="${SSH_SECONDARY}"
		RemoteHost="${SECONDARY_HOST}:"

	elif	[ "${PorSorT}" = "${TERTIARY}" ]
	then
		PgData=${TERTIARY_DATA}
		Prefix="${SSH_TERTIARY}"
		RemoteHost="${TERTIARY_HOST}:"

	else
		echo "Option '${PorSorT}' is invalid."
		exit_on_error "Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."
	fi

	cat > ${LocalHbaFile} <<-EndOfFile
	#	Enable access for superuser [Start]
	local	all	${SUPERUSER_ROLE}			trust
	host	all	${SUPERUSER_ROLE}	127.0.0.1/32	trust
	host	all	${SUPERUSER_ROLE}	::1/128		trust
	host	all	${SUPERUSER_ROLE}	0.0.0.0/0	trust

	local	replication	${SUPERUSER_ROLE}			trust
	host	replication	${SUPERUSER_ROLE}	127.0.0.1/32	trust
	host	replication	${SUPERUSER_ROLE}	::1/128		trust
	host	replication	${SUPERUSER_ROLE}	0.0.0.0/0	trust 

	local	all	${SUPERUSER_ROLE_UNTRUSTED}			md5
	host	all	${SUPERUSER_ROLE_UNTRUSTED}	127.0.0.1/32	md5
	host	all	${SUPERUSER_ROLE_UNTRUSTED}	::1/128		md5
	host	all	${SUPERUSER_ROLE_UNTRUSTED}	0.0.0.0/0	md5

	local	replication	${SUPERUSER_ROLE_UNTRUSTED}			md5
	host	replication	${SUPERUSER_ROLE_UNTRUSTED}	127.0.0.1/32	md5
	host	replication	${SUPERUSER_ROLE_UNTRUSTED}	::1/128		md5
	host	replication	${SUPERUSER_ROLE_UNTRUSTED}	0.0.0.0/0	md5
	#	Enable access for superuser [End]
	EndOfFile

	if	[ "${Prefix}" ]
	then
		scp ${LocalHbaFile} ${RemoteHost}${RemoteHbaFile}
		${Prefix} "cat ${RemoteHbaFile} >> ${PgData}/pg_hba.conf"

	else
		cat ${LocalHbaFile} >> ${PgData}/pg_hba.conf
	fi

	${Prefix} rm -f ${RemoteHbaFile}
	rm -f ${LocalHbaFile}
}

enterprisedb_configuration()	{
	Me="enterprisedb_configuration"
	MyFile=${1:?"ERROR:(${Me}): Please specify a configuration file to update'."}

	if	[ "${EnterpriseDB}" ]
	then
		echo "edb_dynatune = 0		${TAG}" >> ${MyFile}
		echo "shared_buffers = 32MB	${TAG}" >> ${MyFile}
	fi
}

exit_on_error()	{
	#----------------------------------------------------------------------
	#	Exit on error.
	#----------------------------------------------------------------------
	ErrorText="${1}"
	echo "${ErrorText}"
	echo "Exiting ..."
	exit 1
}

initialize_pg_data()	{
	#----------------------------------------------------------------------
	#	Run initdb.
	#----------------------------------------------------------------------
	Me="initialize_pg_data"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}

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

	${Prefix} ${INITDB} -E UTF8 -U ${SUPERUSER_ROLE} ${PgData} || exit_on_error
}

make_WAL_archive_directory()	{
	#----------------------------------------------------------------------
	#	Create WAL file archive directory.
	#----------------------------------------------------------------------
	${SSH_SECONDARY} rm -rf ${WAL_FILES}
	${SSH_SECONDARY} mkdir -p ${WAL_FILES_ROOT}
	${SSH_SECONDARY} chmod -f 777 ${WAL_FILES_ROOT}
	${SSH_SECONDARY} mkdir -p ${WAL_FILES}
}

push_password_file()	{
	#----------------------------------------------------------------------
	#	Push the password file to all hosts.
	#----------------------------------------------------------------------
	File="${HOME}/.pgpass"
	TempFile="/tmp/pgpass.$$"

	cat <<-EndOfFile > ${TempFile}
	*:*:*:${REPLICATION_ROLE_UNTRUSTED}:${REPLICATION_ROLE_UNTRUSTED_PASSWORD}
	*:*:*:${SUPERUSER_ROLE_UNTRUSTED}:${SUPERUSER_ROLE_UNTRUSTED_PASSWORD}
	*:*:*:${NON_SUPERUSER_ROLE_UNTRUSTED}:${NON_SUPERUSER_ROLE_UNTRUSTED_PASSWORD}
	EndOfFile

	#----------------------------------------------------------------------
	#	Primary.
	#----------------------------------------------------------------------
	if	[ "${SSH_PRIMARY}" ]
	then
		scp ${TempFile} ${PRIMARY_HOST}:${File}
	else
		cp ${TempFile} ${File}
	fi

	${SSH_PRIMARY} chmod 0600 ${File}

	#----------------------------------------------------------------------
	#	Secondary.
	#----------------------------------------------------------------------
	if	[ "${SECONDARY_HOST}" ]
	then
		if	[ "${SSH_SECONDARY}" ]
		then
			scp ${TempFile} ${SECONDARY_HOST}:${File}
		else
			test -f ${TempFile} && cp ${TempFile} ${File}
		fi
	
		${SSH_SECONDARY} chmod 0600 ${File}
	fi

	#----------------------------------------------------------------------
	#	Tertiary.
	#----------------------------------------------------------------------
	if	[ "${TERTIARY_HOST}" ]
	then
		if	[ "${SSH_TERTIARY}" ]
		then
			scp ${TempFile} ${TERTIARY_HOST}:${File}
		else
			test -f ${TempFile} && cp ${TempFile} ${File}
		fi
	
		${SSH_TERTIARY} chmod 0600 ${File}
	fi

	#----------------------------------------------------------------------
	#	Clean-up.
	#----------------------------------------------------------------------
	rm -f ${TempFile}
}

remove_postgresql_conf_customization()	{
	#----------------------------------------------------------------------
	#	Disable the 'replication' role.
	#----------------------------------------------------------------------
	Me="remove_postgresql_conf_customization"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}

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

	if	[ "${Prefix}" ]
	then
		${Prefix} "sed \"/${TAG}/d\" ${PgData}/postgresql.conf > /tmp/postgresql.conf"
	else
		sed "/${TAG}/d" ${PgData}/postgresql.conf > /tmp/postgresql.conf
	fi

	${Prefix} mv /tmp/postgresql.conf ${PgData}/postgresql.conf
	${Prefix} rm -f /tmp/postgresql.conf

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return
}

start_pg()	{
	#----------------------------------------------------------------------
	#	Start PostgreSQL.
	#----------------------------------------------------------------------
	Me="start_pg"
	PorSorT=${1:?"ERROR:(${Me}): Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."}
	Prefix=""

	if	[ "${PorSorT}" = "${PRIMARY}" ]
	then
		PgData=${PRIMARY_DATA}
		Prefix="${SSH_F_PRIMARY}"

	elif	[ "${PorSorT}" = "${SECONDARY}" ]
	then
		PgData=${SECONDARY_DATA}
		Prefix="${SSH_F_SECONDARY}"

	elif	[ "${PorSorT}" = "${TERTIARY}" ]
	then
		PgData=${TERTIARY_DATA}
		Prefix="${SSH_F_TERTIARY}"
	else
		echo "Option '${PorSorT}' is invalid."
		exit_on_error "Please specify '${PRIMARY}', '${SECONDARY}' or ${TERTIARY}'."
	fi

	${Prefix} ${PG_CTL} -D ${PgData} start 1> /tmp/start_pg 2>&1
	echo "Waiting 10 seconds for the DBMS to start."
	sleep 10

	cat /tmp/start_pg
	rm -f /tmp/start_pg
}

start_pg_receivexlog()	{
	#----------------------------------------------------------------------
	#	Start pg_receivexlog.
	#----------------------------------------------------------------------
	if	[ "${SSH_F_SECONDARY}" ]
	then
		${SSH_F_SECONDARY} "${PG_RECEIVEXLOG}		\
			--directory=${WAL_FILES}		\
			--host=${PRIMARY_HOST}			\
			--port=${PRIMARY_PORT}			\
			--username=${REPLICATION_ROLE}		\
			> ${WAL_FILES}/pg_receivexlog.log	\
			2>&1 &					\
			echo \$! > ${WAL_FILES}/pg_receivexlog.pid"

	else
		${PG_RECEIVEXLOG}				\
			--directory=${WAL_FILES}		\
			--host=${PRIMARY_HOST}			\
			--port=${PRIMARY_PORT}			\
			--username=${REPLICATION_ROLE}		\
			> ${WAL_FILES}/pg_receivexlog.log	\
			2>&1 &

		echo $! > ${WAL_FILES}/pg_receivexlog.pid
	fi
}

write_recovery_conf()	{
	#----------------------------------------------------------------------
	#	Write recovery.conf
	#----------------------------------------------------------------------
	Me="write_recovery_conf"
	SorT=${1:?"ERROR:(${Me}): Please specify '${SECONDARY}' or ${TERTIARY}'."}
	ConfigFile=${2:?"ERROR:(${Me}): Please specify a file of configuration changes"}

	RemoteConfigFile="/tmp/RemoteConfigFile.$$"

	if	[ "${SorT}" = "${SECONDARY}" ]
	then
		PgData=${SECONDARY_DATA}
		Prefix="${SSH_SECONDARY}"
		RemoteHost="${SECONDARY_HOST}:"

	elif	[ "${SorT}" = "${TERTIARY}" ]
	then
		PgData=${TERTIARY_DATA}
		Prefix="${SSH_TERTIARY}"
		RemoteHost="${TERTIARY_HOST}:"

	else
		echo "Option '${SorT}' is invalid."
		exit_on_error "Please specify '${SECONDARY}' or ${TERTIARY}'."
	fi

	if	[ "${Prefix}" ]
	then
		scp ${ConfigFile} ${RemoteHost}${RemoteConfigFile}
		${Prefix} mv ${RemoteConfigFile} ${PgData}/recovery.conf
	else
		mv ${ConfigFile} ${PgData}/recovery.conf
	fi

	${Prefix} rm -f ${RemoteConfigFile}

	#----------------------------------------------------------------------
	#	Return
	#----------------------------------------------------------------------
	return
}

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
NON_SUPERUSER_ROLE="pg_non_superuser"			# PostgreSQL non-superuser
NON_SUPERUSER_ROLE_UNTRUSTED="pg_non_superuser_untrusted"	# Untrusted PostgreSQL non-superuser.
NON_SUPERUSER_ROLE_UNTRUSTED_PASSWORD="pg_non_superuser"	# Password for NON_SUPERUSER_ROLE_UNTRUSTED.
PRIMARY="primary"				# ReadWrite DBMS replicating to Secondary DBMS.
REPLICATION_ROLE="delphix_replicator"		# Trusted replication role.
REPLICATION_ROLE_UNTRUSTED="delphix_replicator_untrusted"	# Untrusted replication role.
REPLICATION_ROLE_UNTRUSTED_PASSWORD="delphix_replicator"	# Password for REPLICATION_ROLE_UNTRUSTED.
SECONDARY="secondary"				# ReadOnly DBMS receiving updates from Primarty DBMS.
SUPERUSER_ROLE_UNTRUSTED="postgres_untrusted"	# Untrusted PostgreSQL superuser.
SUPERUSER_ROLE_UNTRUSTED_PASSWORD="postgres"	# Password for SUPERUSER_ROLE_UNTRUSTED.
TAG="#Customization#"				# Customization to postgresql.conf
TERTIARY="tertiary"				# ReadOnly DBMS receiving updates from Secondary DBMS.
WAL_FILES_ROOT="${PG_HOME}/WALarchive"
WAL_FILES="${WAL_FILES_ROOT}/${TARGET}"		# WAL file archive.

#------------------------------------------------------------------------------
#	DBMS specific PostgreSQL environment variables. 
#------------------------------------------------------------------------------
build_pg_env_arrays ${TARGET}

REPLICATING_ENVIRONMENT="${REPLICATING[$(stoi ${TARGET})]}"

PRIMARY_DATA="${PRIMARY_DATA[$(stoi ${TARGET})]}"
PRIMARY_DATABASE="${PRIMARY_DATABASE[$(stoi ${TARGET})]}"
PRIMARY_HOST="${PRIMARY_HOST[$(stoi ${TARGET})]}"
PRIMARY_OWNER="${PRIMARY_OWNER[$(stoi ${TARGET})]}"
PRIMARY_PORT="${PRIMARY_PORT[$(stoi ${TARGET})]}"
PRIMARY_USER="${PRIMARY_USER[$(stoi ${TARGET})]}"

SECONDARY_DATA="${SECONDARY_DATA[$(stoi ${TARGET})]}"
SECONDARY_HOST="${SECONDARY_HOST[$(stoi ${TARGET})]}"
SECONDARY_PORT="${SECONDARY_PORT[$(stoi ${TARGET})]}"

TERTIARY_DATA="${TERTIARY_DATA[$(stoi ${TARGET})]}"
TERTIARY_HOST="${TERTIARY_HOST[$(stoi ${TARGET})]}"
TERTIARY_PORT="${TERTIARY_PORT[$(stoi ${TARGET})]}"

PRIMARY_DATA_SANS_CONFIG="${PRIMARY_DATA}_DATA"
SUPERUSER_ROLE="${PRIMARY_USER}"			# PostgreSQL superuser.

ssh_commands

if	[ "${TARGET}" = "NoDefaultDatabases" ]
then
	#----------------------------------------------------------------------
	#	The true 'master' database will be 'my_postgres', but we first
	#	need to connect to the out-of-the-box 'postgres' database.
	#----------------------------------------------------------------------
	PRIMARY_DATABASE="postgres"
fi

exit_if_not_user ${PRIMARY_OWNER}

#------------------------------------------------------------------------------
#	Install and start the instance(s).
#------------------------------------------------------------------------------
echo "Creating '${TARGET}' PostgreSQL DBMS."

#------------------------------------------------------------------------------
#	Push the password file to all hosts.
#------------------------------------------------------------------------------
echo "Copying the PostgreSQL password file to all hosts."
push_password_file

#------------------------------------------------------------------------------
#	Create the WAL file archive directory.
#------------------------------------------------------------------------------
if	[ "${REPLICATING_ENVIRONMENT}" ]
then
	make_WAL_archive_directory
fi

#------------------------------------------------------------------------------
#	Initialize the Primary DBMS.
#------------------------------------------------------------------------------
echo "Initializing a PostgreSQL instance at '${PRIMARY_HOST}:${PRIMARY_DATA}'."
initialize_pg_data ${PRIMARY}

#------------------------------------------------------------------------------
#	Remove the out-of-the-box pg_hba.conf file.
#------------------------------------------------------------------------------
echo "Removing the out-of-the-box pg_hba.conf file."
${SSH_PRIMARY} rm -f ${PRIMARY_DATA}/pg_hba.conf

#------------------------------------------------------------------------------
#	Make modifications to the Primary DBMS configuration.
#------------------------------------------------------------------------------
echo "Configuring the Primary at '${PRIMARY_HOST}:${PRIMARY_DATA}'."
configure_primary

if	[ "${TARGET}" = "LinkedConfig" ]
then
	#----------------------------------------------------------------------
	#	Create links to the configuration files.
	#----------------------------------------------------------------------
	echo "Creating links to the configuration files."

	ConfigFiles="pg_hba.conf pg_ident.conf postgresql.conf"

	for ConfigFile in ${ConfigFiles}
	do
		BaseName="${PRIMARY_DATA}/${ConfigFile}"
		${SSH_PRIMARY} mv ${BaseName} ${BaseName}.FILE
		${SSH_PRIMARY} ln -s ${BaseName}.FILE ${BaseName}
	done
fi

if	[ "${TARGET}" = "ConfigSansData" ]
then
	#----------------------------------------------------------------------
	#	Move non-configuration files to a new location.
	#----------------------------------------------------------------------
	echo "Separating configuration and data files"

	ConfigFiles="pg_hba.conf pg_ident.conf postgresql.conf"

	${SSH_PRIMARY} mv ${PRIMARY_DATA} ${PRIMARY_DATA_SANS_CONFIG}
	${SSH_PRIMARY} mkdir ${PRIMARY_DATA}

	for ConfigFile in ${ConfigFiles}
	do
		 ${SSH_PRIMARY} mv ${PRIMARY_DATA_SANS_CONFIG}/${ConfigFile} ${PRIMARY_DATA}
	done
fi

#------------------------------------------------------------------------------
#	Start the Primary DBMS.
#------------------------------------------------------------------------------
echo "Starting the PostgreSQL DBMS at '${PRIMARY_HOST}:${PRIMARY_DATA}'."
start_pg ${PRIMARY}

#------------------------------------------------------------------------------
#	Create PostgreSQL roles.
#------------------------------------------------------------------------------
echo "Creating untrusted PostgreSQL superuser '${SUPERUSER_ROLE_UNTRUSTED}'"
create_role	${SUPERUSER_ROLE_UNTRUSTED}	\
		"REPLICATION SUPERUSER"		\
		${SUPERUSER_ROLE_UNTRUSTED_PASSWORD}

echo "Creating trusted PostgreSQL non-superuser '${NON_SUPERUSER_ROLE}'"
create_role	${NON_SUPERUSER_ROLE} NOSUPERUSER

echo "Creating untrusted PostgreSQL non-superuser '${NON_SUPERUSER_ROLE_UNTRUSTED}'"
create_role	${NON_SUPERUSER_ROLE_UNTRUSTED}	\
		NOSUPERUSER			\
		${NON_SUPERUSER_ROLE_UNTRUSTED_PASSWORD}

echo "Creating trusted PostgreSQL replication role '${REPLICATION_ROLE}'"
create_role ${REPLICATION_ROLE} REPLICATION 

echo "Creating untrusted PostgreSQL replication role '${REPLICATION_ROLE_UNTRUSTED}'"
create_role	${REPLICATION_ROLE_UNTRUSTED}	\
		REPLICATION			\
		${REPLICATION_ROLE_UNTRUSTED_PASSWORD}

if	[ "${TARGET}" = "NoDefaultDatabases" ]
then
	echo "Dropping the default databases postgres, template0 and template1."
	drop_default_databases
fi

#------------------------------------------------------------------------------
#	Create Secondary DBMS.
#------------------------------------------------------------------------------
if	[ "${REPLICATING_ENVIRONMENT}" ]
then
	if	[ "${TARGET}" = "ReceiveXlog" ]
	then
		#--------------------------------------------------------------
		#	Start pg_receivexlog.
		#--------------------------------------------------------------
		echo "Starting 'pg_receivexlog' on '${SECONDARY_HOST}'."
		start_pg_receivexlog
	fi

	#----------------------------------------------------------------------
	#	Copy the Primary PostgreSQL data to the Secondary.
	#----------------------------------------------------------------------
	echo "Copying data from the Primary at"
	echo "       ${PRIMARY_HOST}:${PRIMARY_DATA}"
	echo "to the Secondary at"
	echo "       ${SECONDARY_HOST}:${SECONDARY_DATA}"
	baseline_backup ${PRIMARY}

	#----------------------------------------------------------------------
	#	Make modifications to the Secondary DBMS configuration.
	#----------------------------------------------------------------------
	echo "Configuring the Secondary at '${SECONDARY_HOST}:${SECONDARY_DATA}'."
	configure_secondary

	#----------------------------------------------------------------------
	#	Start the Secondary DBMS.
	#----------------------------------------------------------------------
	echo "Starting the Secondary DBMS at '${SECONDARY_HOST}:${SECONDARY_DATA}'."
	start_pg ${SECONDARY}

	#----------------------------------------------------------------------
	#	Create Tertiary DBMS.
	#----------------------------------------------------------------------
	if	[ "${TERTIARY_DATA}" ]
	then
		#--------------------------------------------------------------
		#	Copy the Secondary PostgreSQL data to the Tertiary.
		#--------------------------------------------------------------
		echo "Copying data from the Secondary at"
		echo "       ${SECONDARY_HOST}:${SECONDARY_DATA}"
		echo "to the Tertiary at"
		echo "       ${TERTIARY_HOST}:${TERTIARY_DATA}"
		baseline_backup ${SECONDARY}
	
		#--------------------------------------------------------------
		#	Make modifications to the Tertiary DBMS configuration.
		#--------------------------------------------------------------
		echo "Configuring the Tertiary at '${TERTIARY_HOST}:${TERTIARY_DATA}'."
		configure_tertiary
	
		#--------------------------------------------------------------
		#	Start the Tertiary DBMS.
		#--------------------------------------------------------------
		echo "Starting the Tertiary DBMS at '${TERTIARY_HOST}:${TERTIARY_DATA}'."
		start_pg ${TERTIARY}
	fi
fi

echo "Done."

#------------------------------------------------------------------------------
#	End
#------------------------------------------------------------------------------
