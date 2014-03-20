do_psql()	{
	#----------------------------------------------------------------------
	#	Invoke 'psql' to execute the SQL defined by ${Sql}.
	#	${Sql} may be a string of SQL commands or the name of a file.
	#----------------------------------------------------------------------
	Me="do_psql"
	Sql=${1:?"${Me}: Error, you must specify SQL statement(s) to execute."}
	PsqlOptions="${2}"

	MyPsqlOptions="--no-psqlrc"

	#----------------------------------------------------------------------
	#	Is ${SQL} a file or a literal SQL command ?
	#----------------------------------------------------------------------
	if	[ -f "${Sql}" ]
	then
		SqlSource="file"

		test ${dopsql_DEBUG}					\
			&& write_log "dopsql_DEBUG: --SQL File Start"	\
			&& cat ${Sql}					\
			&& write_log "dopsql_DEBUG: --SQL File End"
	else
		SqlSource="command"

		test ${dopsql_DEBUG} && write_log "dopsql_DEBUG: Sql: ${Sql}"
	fi

	#----------------------------------------------------------------------
	#	Debug.
	#----------------------------------------------------------------------
	test ${dopsql_DEBUG} &&							\
		write_log "dopsql_DEBUG: PGDATABASE: ${PGDATABASE}" &&		\
		write_log "dopsql_DEBUG: PGHOST: ${PGHOST}" &&			\
		write_log "dopsql_DEBUG: PGPASSWORD: ${PGPASSWORD}" &&		\
		write_log "dopsql_DEBUG: PGPORT: ${PGPORT}" &&			\
		write_log "dopsql_DEBUG: PGUSER: ${PGUSER}" &&			\
		write_log "dopsql_DEBUG: PSQL_OPTIONS: ${PSQL_OPTIONS}" &&	\
		write_log "dopsql_DEBUG: PsqlOptions: ${PsqlOptions}" &&	\
		write_log "dopsql_DEBUG: SqlSource: ${SqlSource}"
	
	#----------------------------------------------------------------------
	#	Determine the PostgreSQL version.
	#----------------------------------------------------------------------
	PgVersion="$(${PSQL}	--host		${PGHOST}	\
				--port		${PGPORT}	\
				--dbname	${PGDATABASE}	\
				--username	${PGUSER}	\
				--command	"show server_version_num"\
				--tuples-only	\
				2> /dev/null)"
	Rc=$?

	test ${dopsql_DEBUG} && write_log "dopsql_DEBUG: PgVersion: ${PgVersion}"

	if	[ ${Rc} -eq 0 ]
	then
		#--------------------------------------------------------------
		#	System catalogs have changed post version 9.2 .
		#--------------------------------------------------------------
		if	[ ${PgVersion} -ge 90200 ]
		then
			if	[ "${SqlSource}" = "command" ]
			then
				#----------------------------------------------
				#	Modify the SQL string.
				#----------------------------------------------
				Sql="$(echo "${Sql}"			\
					| sed	-e s/procpid/pid/g	\
						-e s/current_query/query/g)"

				test ${dopsql_DEBUG} && write_log "dopsql_DEBUG: Sql: ${Sql}"
			else
				#----------------------------------------------
				#	Modify the SQL file.
				#----------------------------------------------
				ModifiedSqlFile="$(get_temporary_file ModifiedSqlFile)"

				sed	-e s/procpid/pid/g		\
					-e s/current_query/query/g	\
					${Sql}				\
					>& "${ModifiedSqlFile}"

				Sql="${ModifiedSqlFile}"

				test ${dopsql_DEBUG}					\
					&& write_log "dopsql_DEBUG: --SqlFile Start"	\
					&& cat ${Sql}					\
					&& write_log "dopsql_DEBUG: --SqlFile End"
			fi
		fi

		#--------------------------------------------------------------
		#	Invoke 'psql' to execute the ${Sql}.
		#--------------------------------------------------------------
		${PSQL}	--host		${PGHOST}	\
			--port		${PGPORT}	\
			--dbname	${PGDATABASE}	\
			--username	${PGUSER}	\
			--${SqlSource}	"${Sql}"	\
			${MyPsqlOptions}		\
			${PsqlOptions}			\
			${PSQL_OPTIONS}
		Rc=$?
	else
		write_log "Unable to determine the PostgreSQL version."
	fi

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return	${Rc}
}
