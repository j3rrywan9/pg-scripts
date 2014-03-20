database_template()	{
	#----------------------------------------------------------------------
	#	Genertate a TEMPLATE-clause for a CREATE DATABASE statement.
	#----------------------------------------------------------------------
	Me="database_template"
	TheEnvironment=${1:?"${Me}: Error, you must specify an environment."}
	Template="template1"

	if	[ "${TheEnvironment}" = "NoDefaultDatabases" ]
	then
		Template="my_template"
	fi

	echo ${Template}
}
