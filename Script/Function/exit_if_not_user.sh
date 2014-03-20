exit_if_not_user()	{	
	#----------------------------------------------------------------------
	#	Exit if not the expected O.S. user.
	#----------------------------------------------------------------------
	Me="exit_if_not_user"
	ExpectedUser=${1:?"${Me}: Error, please specify the user name."}

	WhoAmI="$(whoami)"

	if	[ "${WhoAmI}" != "${ExpectedUser}" ]
	then
		echo "You must be logged in as '${ExpectedUser}'".
		echo "You are be logged in as '${WhoAmI}'".
		echo "Exiting ..."
		exit 1
	fi
}
