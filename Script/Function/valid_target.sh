valid_target()	{
	#----------------------------------------------------------------------
	#	Validate Customer Environment.
	#----------------------------------------------------------------------
	Target=${1:?"ERROR: Please specify a Customer Environment"}
	ValidTargets="$(targets)"
	echo ${ValidTargets} | grep -qw ${Target}
}
