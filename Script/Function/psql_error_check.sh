psql_error_check()	{
	#---------------------------------------------------------------------
	#	Check for errors from psql.
	#---------------------------------------------------------------------
	Me="psql_error_check"
	MyErrorCode=${1:?"${Me}: Error, please specify an integer error code."}
	MyErrorFile=${2:?"${Me}: Error, please specify an error file."}
	OptionalErrorText=${3}

	#---------------------------------------------------------------------
	#	Local variables.
	#---------------------------------------------------------------------
	SuccessText="Success."
	FailureText="Failure."

	if	[ "${OptionalErrorText}" ]
	then
		SuccessText="${SuccessText} (${OptionalErrorText})"
		FailureText="${FailureText} (${OptionalErrorText})"
	fi

	#---------------------------------------------------------------------
	#	Remove NOTICE from the error file.
	#---------------------------------------------------------------------
	sed /NOTICE/d ${MyErrorFile} > ${MyErrorFile}.${PID}	\
		&& mv ${MyErrorFile}.${PID} ${MyErrorFile}

	#---------------------------------------------------------------------
	#	Check the error code and the error file.
	#	psql may return success, even though the SQL fails.
	#---------------------------------------------------------------------
	if	[ \( ${MyErrorCode} -eq 0 \) -a \( ! -s ${MyErrorFile} \) ]
	then
		#-------------------------------------------------------------
		#	Success.
		#-------------------------------------------------------------
		write_log "${SuccessText}"
	else
		#-------------------------------------------------------------
		#	Failure.
		#-------------------------------------------------------------
		write_log "${FailureText}"

		if	[ -s ${MyErrorFile} ]
		then
			write_log "Here is the PostgreSQL error."
			write_log
			cat ${MyErrorFile} >> ${LOG_FILE}
		fi

		MyErrorCode=1
	fi

	#---------------------------------------------------------------------
	#	Return.
	#---------------------------------------------------------------------
	return	$MyErrorCode
}
