#!/bin/bash
#------------------------------------------------------------------------------
#	Gather PostgreSQL metrics at $FREQUENCY for $DURATION.
#------------------------------------------------------------------------------
PGHOST=${1:?"ERROR: You must specify a DBMS."}
PGPORT=${2:?"ERROR: You must specify a Port."}
Frequency=${3:-60}			# Sample frequency (seconds).
Duration=${4:-3600}			# Sample duration (seconds).
OutputDir=${5:-"/tmp/PgMetrics"}	# Write output files here.

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
ErrorCount=0			# Count of errors.
Iterations=$(expr ${Duration} / ${Frequency})
MaxErrors=10			# Maximum number of errors before forcing exit.
Me="$(basename ${0})"		# My name.
TemporaryDir="/tmp/${Me}.$$"	# Directory for temporary files.

Tables="
	pg_stat_bgwriter 
	pg_stat_database
	"

Uname="$(uname)"	# OS name

if	[ "${Uname}" = "Linux" ]
then
	IOSTAT="iostat -mtx ${Frequency} ${Iterations}"
	VMSTAT="vmstat -t ${Frequency} ${Iterations}"

elif	[ "${Uname}" = "Darwin" ]
then
	IOSTAT="iostat -d -C -c ${Iterations} -K -w ${Frequency}"
	VMSTAT="vm_stat ${Frequency}"
else
	echo "The operating system '${Uname}' in not recognized."
	echo "Exiting ..."
	exit 1
fi

	#----------------------------------------------------------------------
	#	Temporary files.
	#----------------------------------------------------------------------
SqlError="${TemporaryDir}/SqlError)"

#------------------------------------------------------------------------------
#	Create directories.
#------------------------------------------------------------------------------
mkdir -p ${OutputDir} ${TemporaryDir}

#------------------------------------------------------------------------------
#	Lauch Operating System monitors.
#------------------------------------------------------------------------------
${IOSTAT} 1>> ${OutputDir}/iostat.dat 2>&1 &
${VMSTAT} 1>> ${OutputDir}/vmstat.dat 2>&1 &

#------------------------------------------------------------------------------
#	Retrieving PostgreSQL metrics.
#------------------------------------------------------------------------------
echo "Retrieving PostgreSQL metrics for DBMS '${PGHOST}', port '${PGPORT}'."

while	[ ${Counter} -lt ${Duration} ] && [ ${ErrorCount} -lt ${MaxErrors} ]
do
	for Table in ${Tables}
	do
		OutPutFile="${OutputDir}/${Table}.dat"
		Sql="COPY (select now(), * from ${Table}) TO STDOUT"

		${PSQL} -c "${Sql}" 1>> ${OutPutFile} 2> ${SqlError}
		Rc=$?
	
		if      [ ${Rc} -ne 0 ] || [ -s ${SqlError} ]
		then
			echo "PostgreSQL error:-"

			if	[  -s ${SqlError} ]
			then
				cat ${SqlError}
				echo
			fi

			ErrorCount=$(expr ${ErrorCount} + 1)
		fi
	done

	Counter=$(expr ${Counter} + ${Frequency})
	sleep ${Frequency}
done

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
rm -rf ${TemporaryDir}
exit ${ErrorCount}
