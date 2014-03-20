#!/bin/bash
#------------------------------------------------------------------------------
#	Gather PostgreSQL metrics at $FREQUENCY for $DURATION.
#------------------------------------------------------------------------------
Frequency=${1:-60}			# Sample frequency (seconds).
Duration=${2:-3600}			# Sample duration (seconds).
OutputDir=${3:-"/tmp/PgMetrics"}	# Write output files here.

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
ERROR_COUNT=0		# Count of errors.
Iterations=$(expr ${Duration} / ${Frequency})
MaxErrors=10		# Maximum number of errors before forcing exit.
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
	write_log "The operating system '${Uname}' in not recognized."
	write_log "Exiting ..."
	ERROR_COUNT=$(expr ${ERROR_COUNT} + 1)
	do_exit
fi

	#----------------------------------------------------------------------
	#	Temporary files.
	#----------------------------------------------------------------------
SqlError="$(get_temporary_file SqlError)"

#------------------------------------------------------------------------------
#	Lauch Operating System monitors.
#------------------------------------------------------------------------------
mkdir -p ${OutputDir}

${IOSTAT} 1>> ${OutputDir}/iostat.dat 2>&1 &
${VMSTAT} 1>> ${OutputDir}/vmstat.dat 2>&1 &

#------------------------------------------------------------------------------
#	Retrieving PostgreSQL metrics.
#------------------------------------------------------------------------------
write_log "Retrieving PostgreSQL metrics for DBMS '${PGHOST}', port '${PGPORT}'."

while	[ ${Counter} -lt ${Duration} ] && [ ${ERROR_COUNT} -lt ${MaxErrors} ]
do
	for Table in ${Tables}
	do
		OutPutFile="${OutputDir}/${Table}.dat"
		Sql="COPY (select now(), * from ${Table}) TO STDOUT"

		do_psql "${Sql}" 1>> ${OutPutFile} 2> ${SqlError}
		Rc=$?
	
		psql_error_check ${Rc} ${SqlError}
		Rc=$?
	
		if	[ ${Rc} -ne 0 ]
		then
			ERROR_COUNT=$(expr ${ERROR_COUNT} + 1)
		fi
	done

	Counter=$(expr ${Counter} + ${Frequency})
	sleep ${Frequency}
done

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
do_exit
