ssh_commands()	{
	#----------------------------------------------------------------------
	#	Generate the appropriate ssh commands based upon the
	#	physical host from which this function is being run.
	#----------------------------------------------------------------------
	Hostname="$(hostname)"
	host_names_and_ip_addresses

	SSH_PRIMARY=""
	SSH_F_PRIMARY=""
	SSH_SECONDARY=""
	SSH_F_SECONDARY=""
	SSH_TERTIARY=""
	SSH_F_TERTIARY=""

	if	[ "${Hostname}" = "${PG1_HOSTNAME}" ]
	then
		SSH_SECONDARY="ssh ${PG2_IP_ADDRESS}"
		SSH_F_SECONDARY="ssh -f ${PG2_IP_ADDRESS}"
		SSH_TERTIARY="ssh ${PG3_IP_ADDRESS}"
		SSH_F_TERTIARY="ssh -f ${PG3_IP_ADDRESS}"

	elif	[ "${Hostname}" = "${PG2_HOSTNAME}" ]
	then
		SSH_PRIMARY="ssh ${PG1_IP_ADDRESS}"
		SSH_F_PRIMARY="ssh -f ${PG1_IP_ADDRESS}"
		SSH_TERTIARY="ssh ${PG3_IP_ADDRESS}"
		SSH_F_TERTIARY="ssh -f ${PG3_IP_ADDRESS}"

	elif	[ "${Hostname}" = "${PG3_HOSTNAME}" ]
	then
		SSH_PRIMARY="ssh ${PG1_IP_ADDRESS}"
		SSH_F_PRIMARY="ssh -f ${PG1_IP_ADDRESS}"
		SSH_SECONDARY="ssh ${PG2_IP_ADDRESS}"
		SSH_F_SECONDARY="ssh -f ${PG2_IP_ADDRESS}"
	fi

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return
}
