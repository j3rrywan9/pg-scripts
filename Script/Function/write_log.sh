write_log()	{
	#----------------------------------------------------------------------
	#	Write to LOG_FILE.
	#----------------------------------------------------------------------
	LOG_FILE=${LOG_FILE:?"write_log: Error, environment variable LOG_FILE is undefined."}

	echo -e "#<$(date)># ${1}"	>> ${LOG_FILE}
}
