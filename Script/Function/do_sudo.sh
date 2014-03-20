do_sudo()	{
	#----------------------------------------------------------------------
	#	Not all the PostgreSQL DBMS are owned, at the file level,
	#	by postgres. Sudo to the DBMS owner.
	#----------------------------------------------------------------------
	Me="do_sudo"
	Owner=${1:?"${Me}: Error, you must specify the DBMS owner."}
	Postgres="postgres"

	if	[ "${Owner}" = "${Postgres}" ]
	then
		Sudo=""

	else
		Sudo="sudo -u ${Owner}"
	fi

	echo ${Sudo}
}
