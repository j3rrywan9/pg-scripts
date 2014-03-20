interrupt_handler()	{
	#----------------------------------------------------------------------
	#	Trap interrupts.
	#----------------------------------------------------------------------
	trap 'write_log "Received interrupt, exiting..."
		ERROR_COUNT=1
		clean_up
		exit ${ERROR_COUNT}' 1 2 3 15
}
