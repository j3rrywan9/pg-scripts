error_check()	{
	#---------------------------------------------------------------------
	#	Check for errors.
	#---------------------------------------------------------------------
	Me="error_check"
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
	#	Check the error code.
	#---------------------------------------------------------------------
	if	[ ${MyErrorCode} -eq 0 ]
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
			write_log "Here is the error."
			write_log
			cat ${MyErrorFile} >> ${LOG_FILE}
		fi
	fi

	#---------------------------------------------------------------------
	#	Return.
	#---------------------------------------------------------------------
	return	$MyErrorCode
}
