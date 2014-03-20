get_PGPASSWORD()	{
	#----------------------------------------------------------------------
	#	Get the password for PostgreSQL user User on Host .
	#----------------------------------------------------------------------
	Me="get_PGPASSWORD"
	Host=${1:?"${Me}: Error, you must specify a PostgreSQL host name."}
	User=${2:?"${Me}: Error, you must specify a PostgreSQL user name."}
	Port=${3:?"${Me}: Error, you must specify a PostgreSQL port number."}

	#----------------------------------------------------------------------
	#	Local variables.
	#----------------------------------------------------------------------
	Password=""

	#----------------------------------------------------------------------
	#	Display the password.
	#----------------------------------------------------------------------
	if	[ ${Port} -eq 9170 ]
	then
		Password="postgres9170"

	elif	[ ${Port} -eq 9220 ]
	then
		Password="postgres9220"

	elif	[ ${Port} -eq 9300 ]
	then
		Password="postgres9300"
	fi

	echo "${Password}"

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return
}
