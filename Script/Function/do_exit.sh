do_exit()	{	
	#----------------------------------------------------------------------
	#	Conditionally clean_up(), then exit.
	#----------------------------------------------------------------------
	if	[ ${ERROR_COUNT} -eq 0 ]
	then
		clean_up
	fi

	write_log "Exit Code: ${ERROR_COUNT}"
	exit ${ERROR_COUNT}
}
