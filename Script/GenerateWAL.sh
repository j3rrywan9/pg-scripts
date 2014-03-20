#!/bin/bash
#------------------------------------------------------------------------------
#	Generate a WAL file at $FREQUENCY for $DURATION
#	with $TransactionsPerWal per WAL file.
#------------------------------------------------------------------------------
Frequency=${1:-60}		# WAL creation frequency (seconds).
Duration=${2:-3600}		# WAL creation duration (seconds).
TransactionsPerWal=${3:-10}	# Transactions per WAL file (approximate).

TransactionInterval=$(expr ${Frequency} / ${TransactionsPerWal})

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
Counter=0
Database="delphix_generate_wal"	# PostgreSQL database on DBMS $PGHOST.
ERROR_COUNT=0			# Count of errors.
MaxErrors=10			# Maximum number of errors before forcing exit.
Table="generate_wal"		# PostgreSQL table in database $Database.
TemplateClause="TEMPLATE $(database_template ${PG_ENV})"	# Template DB

	#----------------------------------------------------------------------
	#	Temporary files.
	#----------------------------------------------------------------------
SqlError="$(get_temporary_file SqlError)"
SqlFile="$(get_temporary_file SqlFile)"
SqlResult="$(get_temporary_file SqlResult)"

#------------------------------------------------------------------------------
#	Generate the SQL file to create the database.
#------------------------------------------------------------------------------
cat > ${SqlFile} <<-EndOfSql
	-----------------------------------------------------------------------
	--	Drop the database.
	-----------------------------------------------------------------------
	DROP DATABASE IF EXISTS ${Database};

	-----------------------------------------------------------------------
	--	Create the database.
	-----------------------------------------------------------------------
	CREATE DATABASE	${Database} ${TemplateClause};

	\connect ${Database}

	-----------------------------------------------------------------------
	--	Create the table.
	-----------------------------------------------------------------------
	CREATE TABLE	${Table}	(
		label text not null,
		ts timestamptz not null default now(),
		txid bigint not null default txid_current(),
		wal_file char(24) not null
			default pg_xlogfile_name(pg_current_xlog_location())
	);

EndOfSql

#------------------------------------------------------------------------------
#	Create the SQL statements to generate transactions.
#------------------------------------------------------------------------------

	#----------------------------------------------------------------------
	#	Switch WAL files.
	#----------------------------------------------------------------------
echo "select pg_switch_xlog();" >> ${SqlFile}
echo "create table t (a int); drop table t;" >> ${SqlFile}

while	[ ${Counter} -lt ${Duration} ] && [ ${ERROR_COUNT} -lt ${MaxErrors} ]
do
	Transaction=0

	while	[ ${Transaction} -lt ${TransactionsPerWal} ]
	do
		Label="${Counter}-${Transaction}"

		cat >> ${SqlFile} <<-EndOfSql
			insert into ${Table} (label) values ('${Label}');
			select pg_create_restore_point('${Label}');
			select pg_sleep(${TransactionInterval});
		EndOfSql

		Transaction=$(expr ${Transaction} + 1)
	done

	#----------------------------------------------------------------------
	#	Switch WAL files.
	#----------------------------------------------------------------------
	echo "select pg_switch_xlog();" >> ${SqlFile}
	echo "create table t (a int); drop table t;" >> ${SqlFile}

	Counter=$(expr ${Counter} + ${Frequency})
done

#------------------------------------------------------------------------------
#	Execute the SQL.
#------------------------------------------------------------------------------
write_log "Generating WAL files every ${Frequency} seconds by inserting"
write_log "data into '${Database}.public.${Table}'."
write_log "Each WAL file contains ${TransactionsPerWal} write transactions."

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
