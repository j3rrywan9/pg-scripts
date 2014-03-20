stoi()	{
	#----------------------------------------------------------------------
	#	Determine the integer that describes a customer environment.
	#----------------------------------------------------------------------
	Me="stoi"
	Value=${1:?"${Me}: Error, you must specify a string to translate."}
	MapFile="${SCRIPT_DIR}/CustomerEnvironments"

	if	[ -f ${MapFile} ]
	then
		Value="$(grep -w ${Value} ${MapFile} | awk '{print $1}')"

	else
		echo "${Me}: File '${MapFile}' not found."
		echo "Exiting ..."
		exit 1
	fi

	echo ${Value}
}
