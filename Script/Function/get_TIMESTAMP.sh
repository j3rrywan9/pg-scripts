get_TIMESTAMP()	{
	#----------------------------------------------------------------------
	#	Generate a timestamp in the format YYYYMMDD_HHMMSS.
	#----------------------------------------------------------------------
	Day=${1:-"today"}		# "today", by default.
	Format="+%Y%m%d_%H%M%S"

	FormatDate "${Day}" "${Format}"
}
