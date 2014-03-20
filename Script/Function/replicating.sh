replicating()	{
	#----------------------------------------------------------------------
	#	Determine if $Target is a replicating environment.
	#----------------------------------------------------------------------
	Me="replicating"
	Target=${1:?"${Me}: Error, you must specify an environment."}
	MapFile="${SCRIPT_DIR}/CustomerEnvironments"

	if	[ -f ${MapFile} ]
	then
		Value="$(grep -w ${Target} ${MapFile} | awk '{print $3}')"
	else
		echo "${Me}: File '${MapFile}' not found."
		echo "Exiting ..."
		exit 1
	fi

	echo ${Value}
}
