#!/bin/bash
#------------------------------------------------------------------------------
#	Generate a WAL file at $FREQUENCY for $DURATION
#	with $TransactionsPerWal per WAL file.
#------------------------------------------------------------------------------
PGHOST=${1:?"ERROR: You must specify a DBMS."}
PGPORT=${2:?"ERROR: You must specify a Port."}
Frequency=${3:-60}		# WAL creation frequency (seconds).
Duration=${4:-3600}		# WAL creation duration (seconds).
TransactionsPerWal=${5:-10}	# Transactions per WAL file (approximate).

TransactionInterval=$(expr ${Frequency} / ${TransactionsPerWal})

#------------------------------------------------------------------------------
#	PostgreSQL Global Variables.
#------------------------------------------------------------------------------
export PGDATABASE="${PGDATABASE:-"postgres"}"
export PGHOST
export PGPASSWORD="${PGPASSWORD:-""}"
export PGPORT
export PGUSER="${PGUSER:-"postgres"}"

#-----------------------------------------------------------------------------
#	Ensure we can find psql.
#-----------------------------------------------------------------------------
PSQL=$(which psql 2> /dev/null)

if	[ -z ${PSQL} ]
then
	echo "Unable to find 'psql'."
	echo "Exiting."
	exit 1
fi

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
Counter=0
Database="delphix_generate_wal"	# PostgreSQL database on DBMS $PGHOST.
ErrorCount=0			# Count of errors.
MaxErrors=10			# Maximum number of errors before forcing exit.
Me="$(basename ${0})"		# My name.
TemporaryDir="/tmp/${Me}.$$"	# Directory for temporary files.
Table="generate_wal"		# PostgreSQL table in database $Database.

	#----------------------------------------------------------------------
	#	Temporary files.
	#----------------------------------------------------------------------
SqlError="${TemporaryDir}/SqlError"
SqlFile="${TemporaryDir}/SqlFile"
SqlResult="${TemporaryDir}/SqlResult"

#------------------------------------------------------------------------------
#	Create directories.
#------------------------------------------------------------------------------
mkdir -p ${TemporaryDir}

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
	CREATE DATABASE	${Database};

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

while	[ ${Counter} -lt ${Duration} ] && [ ${ErrorCount} -lt ${MaxErrors} ]
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
echo "Generating WAL files every ${Frequency} seconds by inserting"
echo "data into '${Database}.public.${Table}'."
echo "Each WAL file contains ${TransactionsPerWal} write transactions."

${PSQL} -ef ${SqlFile} 1> ${SqlResult} 2> ${SqlError}
Rc=$?

if      [ ${Rc} -eq 0 ] && [ ! -s ${SqlError} ]
then
	cat ${SqlResult}
else
	ErrorCount=$(expr ${ErrorCount} + 1)
fi

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
rm -rf ${TemporaryDir}
exit ${ErrorCount}
