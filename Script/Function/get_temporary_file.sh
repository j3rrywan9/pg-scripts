get_temporary_file()	{
	#----------------------------------------------------------------------
	#	Generate a unique name for a temporary file in TEMPORARY_DIR.
	#----------------------------------------------------------------------
	UniqueFileNameTag="${1}"

	#----------------------------------------------------------------------
	#	Construct the file name.
	#----------------------------------------------------------------------
	UniqueFileName="${TEMPORARY_DIR}/${RANDOM}"

	if	[ "${UniqueFileNameTag}" ]
	then
		UniqueFileName="${UniqueFileName}.${UniqueFileNameTag}"
	fi

	echo "${UniqueFileName}"
}
