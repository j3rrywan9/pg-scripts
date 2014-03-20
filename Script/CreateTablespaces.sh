#!/bin/bash
#------------------------------------------------------------------------------
#	Create tablespaces.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Local Functions.
#------------------------------------------------------------------------------
create_databases()	{
	#----------------------------------------------------------------------
	#	Create the databases.
	#----------------------------------------------------------------------
	write_log "Creating Databases."

	do_psql ${CreateDatabases} 1> ${SqlResult} 2> ${SqlError}
	Rc=$?
	
	psql_error_check ${Rc} ${SqlError}
	Rc=$?
	
	if	[ ${Rc} -eq 0 ]
	then
		cat ${SqlResult} >> ${LOG_FILE}
	else
		ERROR_COUNT=$(expr ${ERROR_COUNT} + 1)
	fi

	return ${Rc}
}

create_tables()	{
	#----------------------------------------------------------------------
	#	Create the tables.
	#----------------------------------------------------------------------
	write_log "Creating Tables."

	for Database in ${Databases}
	do
		export PGDATABASE="${Database}"
		do_psql ${CreateTables} 1> ${SqlResult} 2> ${SqlError}
		Rc=$?
		
		psql_error_check ${Rc} ${SqlError}
		Rc=$?
		
		if	[ ${Rc} -eq 0 ]
		then
			cat ${SqlResult} >> ${LOG_FILE}
		else
			ERROR_COUNT=$(expr ${ERROR_COUNT} + 1)
		fi
	done

	return ${ERROR_COUNT}
}

create_tablespaces()	{
	#----------------------------------------------------------------------
	#	Create the tablespaces.
	#----------------------------------------------------------------------
	write_log "Creating Tablespaces."

	do_psql ${CreateTablespaces} 1> ${SqlResult} 2> ${SqlError}
	Rc=$?
	
	psql_error_check ${Rc} ${SqlError}
	Rc=$?
	
	if	[ ${Rc} -eq 0 ]
	then
		cat ${SqlResult} >> ${LOG_FILE}
	else
		ERROR_COUNT=$(expr ${ERROR_COUNT} + 1)
	fi

	return ${Rc}
}

drop_databases()	{
	#----------------------------------------------------------------------
	#	Drop the databases.
	#----------------------------------------------------------------------
	write_log "Dropping Databases."

	do_psql ${DropDatabases} 1> ${SqlResult} 2> ${SqlError}
	Rc=$?
	
	psql_error_check ${Rc} ${SqlError}
	Rc=$?
	
	if	[ ${Rc} -eq 0 ]
	then
		cat ${SqlResult} >> ${LOG_FILE}
	else
		ERROR_COUNT=$(expr ${ERROR_COUNT} + 1)
	fi

	return ${Rc}
}

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
Databases="db_on_default_tablespace db_on_user_tablespace"
SystemTableSpaces="pg_default"
TemplateClause="TEMPLATE $(database_template ${PG_ENV})"	# Template DB
UserTableSpaceRootDir="${PG_HOME}/UserTablespace"
UserTableSpaceEnvDir="${UserTableSpaceRootDir}/${PG_ENV}"
UserTableSpaces="tablespace1 tablespace2"

	#----------------------------------------------------------------------
	#	Temporary files.
	#----------------------------------------------------------------------
CreateDatabases="$(get_temporary_file CreateDatabases)"
CreateTables="$(get_temporary_file CreateTables)"
CreateTablespaces="$(get_temporary_file CreateTablespaces)"
DropDatabases="$(get_temporary_file DropDatabases)"
SqlError="$(get_temporary_file SqlError)"
SqlResult="$(get_temporary_file SqlResult)"

#------------------------------------------------------------------------------
#	Create the directories corresponding to the tablespaces.
#------------------------------------------------------------------------------
build_pg_env_arrays ${PG_ENV}
ssh_commands

DbmsOwner="${PRIMARY_OWNER[$(stoi ${PG_ENV})]}"
SECONDARY_DATA="${SECONDARY_DATA[$(stoi ${PG_ENV})]}"
TERTIARY_DATA="${TERTIARY_DATA[$(stoi ${PG_ENV})]}"

Sudo="$(do_sudo ${DbmsOwner})"

write_log "PostgreSQL Version: ${PG_VERSION}, Environment '${PG_ENV}'"

for TableSpace in ${UserTableSpaces}
do
	directory="${UserTableSpaceEnvDir}/${TableSpace}"

	write_log "Creating tablespace '${TableSpace}' on the Primary at '${directory}'."

	${SSH_PRIMARY} mkdir -p  ${UserTableSpaceRootDir}	>> ${LOG_FILE} 2>&1
	${SSH_PRIMARY} chmod -f 777 ${UserTableSpaceRootDir}	>> ${LOG_FILE} 2>&1
	${SSH_PRIMARY} ${Sudo} mkdir -p ${directory}		>> ${LOG_FILE} 2>&1

	if	[ "${SECONDARY_DATA}" ]
	then
		write_log "Creating tablespace '${TableSpace}' on the Secondary at '${directory}'."

		${SSH_SECONDARY} mkdir -p ${UserTableSpaceRootDir}	>> ${LOG_FILE} 2>&1
		${SSH_SECONDARY} chmod -f 777 ${UserTableSpaceRootDir}	>> ${LOG_FILE} 2>&1
		${SSH_SECONDARY} ${Sudo} mkdir -p ${directory}		>> ${LOG_FILE} 2>&1

		if	[ "${TERTIARY_DATA}" ]
		then
			write_log "Creating tablespace '${TableSpace}' on the Tertiary at '${directory}'."

			${SSH_TERTIARY} mkdir -p ${UserTableSpaceRootDir}	>> ${LOG_FILE} 2>&1
			${SSH_TERTIARY} chmod -f 777 ${UserTableSpaceRootDir}	>> ${LOG_FILE} 2>&1
			${SSH_TERTIARY} ${Sudo} mkdir -p ${directory}		>> ${LOG_FILE} 2>&1
		fi
	fi
done

#------------------------------------------------------------------------------
#	Generate the SQL files.
#------------------------------------------------------------------------------
	#----------------------------------------------------------------------
	#	Create tablespaces.
	#----------------------------------------------------------------------
for TableSpace in ${UserTableSpaces}
do
	cat >> ${CreateTablespaces} <<-EndOfSql
		DROP TABLESPACE IF EXISTS	${TableSpace};

		CREATE TABLESPACE	${TableSpace}
		LOCATION	'${UserTableSpaceEnvDir}/${TableSpace}';
	EndOfSql
done

	#----------------------------------------------------------------------
	#	Create databases.
	#----------------------------------------------------------------------
cat > ${CreateDatabases} <<-EndOfSql
	CREATE DATABASE	db_on_default_tablespace ${TemplateClause};

	CREATE DATABASE	db_on_user_tablespace
	WITH
	TABLESPACE	tablespace1
	${TemplateClause};
EndOfSql

	#----------------------------------------------------------------------
	#	Create and populate tables.
	#----------------------------------------------------------------------
for TableSpace in ${SystemTableSpaces} ${UserTableSpaces}
do
	cat >> ${CreateTables} <<-EndOfSql
		CREATE TABLE	table_on_${TableSpace} (col1 integer not null)
		TABLESPACE	${TableSpace};

		INSERT INTO	table_on_${TableSpace} (col1)
		VALUES		(1);
	EndOfSql
done

cat >> ${CreateTables} <<-EndOfSql
	CREATE TABLE	table_on_default_tablespace (col1 integer not null);

	INSERT INTO	table_on_default_tablespace (col1)
	VALUES		(1);
EndOfSql

	#----------------------------------------------------------------------
	#	Drop databases.
	#----------------------------------------------------------------------
cat > ${DropDatabases} <<-EndOfSql
	DROP DATABASE IF EXISTS	db_on_default_tablespace;
	DROP DATABASE IF EXISTS	db_on_user_tablespace;
EndOfSql

#------------------------------------------------------------------------------
#	Execute the SQL files to create and populate the tablespaces.
#------------------------------------------------------------------------------
drop_databases && create_tablespaces && create_databases && create_tables

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
do_exit
