#!/bin/bash
#------------------------------------------------------------------------------
#	Create Unlogged Index.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
TemplateClause="TEMPLATE $(database_template ${PG_ENV})"	# Template DB

	#----------------------------------------------------------------------
	#	Temporary files.
	#----------------------------------------------------------------------
SqlError="$(get_temporary_file SqlError)"
SqlFile="$(get_temporary_file SqlFile)"
SqlResult="$(get_temporary_file SqlResult)"

#------------------------------------------------------------------------------
#	Generate the SQL file.
#------------------------------------------------------------------------------
cat > ${SqlFile} <<-EndOfSql
	-----------------------------------------------------------------------
	--	Drop the database.
	-----------------------------------------------------------------------
	DROP DATABASE IF EXISTS unlogged_index;

	-----------------------------------------------------------------------
	--	Create the database.
	-----------------------------------------------------------------------
	CREATE DATABASE	unlogged_index ${TemplateClause};

	\connect unlogged_index

	-----------------------------------------------------------------------
	--	Create the table to host the index.
	-----------------------------------------------------------------------
	CREATE UNLOGGED TABLE	unlogged_index_table	(
		col1 integer not null
	);

	-----------------------------------------------------------------------
	--	Create the unlogged index.
	-----------------------------------------------------------------------
	CREATE INDEX unlogged_index ON unlogged_index_table USING hash (col1);

	-----------------------------------------------------------------------
	--	Populate the table.
	-----------------------------------------------------------------------
	INSERT INTO	unlogged_index_table (col1)	VALUES (1);
	INSERT INTO	unlogged_index_table (col1)	VALUES (2);
	INSERT INTO	unlogged_index_table (col1)	VALUES (3);

	-----------------------------------------------------------------------
	--	Display the data.
	-----------------------------------------------------------------------
	SELECT	col1
	FROM	unlogged_index_table
	ORDER BY
		col1;
EndOfSql

#------------------------------------------------------------------------------
#	Create the unlogged tables.
#------------------------------------------------------------------------------
write_log "PostgreSQL Version: ${PG_VERSION}, Environment '${PG_ENV}'"
write_log "Creating Unlogged Index."

do_psql ${SqlFile} 1> ${SqlResult} 2> ${SqlError}
Rc=$?

psql_error_check ${Rc} ${SqlError}
Rc=$?

if	[ ${Rc} -eq 0 ]
then
	cat ${SqlResult} >> ${LOG_FILE}
else
	ERROR_COUNT=$(expr ${ERROR_COUNT} + 1)
fi

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
do_exit
