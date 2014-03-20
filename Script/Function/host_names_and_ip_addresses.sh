host_names_and_ip_addresses()	{
	#----------------------------------------------------------------------
	#	Define the hostnames and ip-addresses used by PostgreSQL
	#	in the customer environments.
	#----------------------------------------------------------------------
	Hostname="$(hostname)"

	if	[ "${Hostname}" = "pg92src-01.delphix.com" ]		\
			|| [ "${Hostname}" = "pg92src-02.delphix.com" ]	\
			|| [ "${Hostname}" = "pg92src-03.delphix.com" ]
	then
		#--------------------------------------------------------------
		#	Running on ESX based VM. DBMS are spread over 3 hosts.
		#--------------------------------------------------------------
		PG1_HOSTNAME="pg92src-01.delphix.com"
		PG2_HOSTNAME="pg92src-02.delphix.com"
		PG3_HOSTNAME="pg92src-03.delphix.com"
		PG1_IP_ADDRESS="172.16.100.95"
		PG2_IP_ADDRESS="172.16.103.247"
		PG3_IP_ADDRESS="172.16.103.237"
	else
		#--------------------------------------------------------------
		#	Running on a Mac or dcenter VM. All DBMS are local.
		#--------------------------------------------------------------
		PG1_HOSTNAME="localhost"
		PG2_HOSTNAME="localhost"
		PG3_HOSTNAME="localhost"
		PG1_IP_ADDRESS="localhost"
		PG2_IP_ADDRESS="localhost"
		PG3_IP_ADDRESS="localhost"
	fi

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return
}
