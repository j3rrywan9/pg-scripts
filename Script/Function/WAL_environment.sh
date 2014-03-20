WAL_environment()	{
	#----------------------------------------------------------------------
	#	Determine the integer that describes a customer environment.
	#----------------------------------------------------------------------
	Me="WAL_environment"
	MyPGDATA=${1:?"${Me}: Error, you must specify a value for PGDATA."}

	#----------------------------------------------------------------------
	#	PostgreSQL on Linux.
	#----------------------------------------------------------------------
	PgType="pgsql"
	PgVersion="$(cat ${MyPGDATA}/PG_VERSION)"
	WAL_BIN_DIR="/usr/${PgType}-${PgVersion}/bin"

	#----------------------------------------------------------------------
	#	PostgresPlus from EnterpriseDB on Linux.
	#----------------------------------------------------------------------
	echo ${MyPGDATA} | grep "PostgresPlus" > /dev/null 2>&1	\
		&& PgVersion="${PgVersion}AS"			\
		&& PgType="PostgresPlus"			\
		&& WAL_BIN_DIR="/usr/${PgType}/${PgVersion}/bin"

	WAL_ROOT_DIR="/var/lib/${PgType}/${PgVersion}"
	

	if [ "$(uname)" = "Darwin" ]
	then
		#--------------------------------------------------------------
		#	Mac OS.
		#--------------------------------------------------------------
		if	[ "${PgType}" = "pgsql" ]
		then
			WAL_BIN_DIR="/Library/PostgreSQL/${PgVersion}/bin"
			WAL_ROOT_DIR="/Library/PostgreSQL/${PgVersion}"
		else
			WAL_BIN_DIR="/Library/${PgType}/${PgVersion}/bin"
			WAL_ROOT_DIR="/Library/${PgType}/${PgVersion}"
		fi
	fi
}
