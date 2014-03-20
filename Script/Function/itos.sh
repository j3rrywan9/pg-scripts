itos()	{
	#----------------------------------------------------------------------
	#	Determine the text that describes a customer environment.
	#----------------------------------------------------------------------
	Me="itos"
	Index=${1:?"${Me}: Error, you must specify an integer to translate."}
	MapFile="${SCRIPT_DIR}/CustomerEnvironments"

	if	[ -f ${MapFile} ]
	then
		Value="$(grep -w ${Index} ${MapFile} | awk '{print $2}')"

	else
		echo "${Me}: File '${MapFile}' not found."
		echo "Exiting ..."
		exit 1
	fi

	echo ${Value}
}
