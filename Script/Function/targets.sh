targets()	{
	#----------------------------------------------------------------------
	#	List all Customer Environments.
	#----------------------------------------------------------------------
	cat ${SCRIPT_DIR}/CustomerEnvironments |awk '{print $2}' |sort
}
