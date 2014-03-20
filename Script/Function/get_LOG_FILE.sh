get_LOG_FILE()	{
	#----------------------------------------------------------------------
	#	Determine the file name where messages will be logged.
	#----------------------------------------------------------------------
	TIMESTAMP=${TIMESTAMP:="$(get_TIMESTAMP)"}

	echo "${LOG_DIR}/${EXECNAME}.${TIMESTAMP}.log"
}
