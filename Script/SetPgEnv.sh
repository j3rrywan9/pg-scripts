#!/bin/bash
#------------------------------------------------------------------------------
#       Define PostgreSQL environment variables.
#------------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#	PG_ROOT.
#-----------------------------------------------------------------------------
source ~postgres/Script/PG_ROOT.sh

#-----------------------------------------------------------------------------
#	Common Functions.
#-----------------------------------------------------------------------------
if	[ ! "${FUNCTION_DIR}" ]
then
	SCRIPT_DIR="${HOME}/Script"
	FUNCTION_DIR="${SCRIPT_DIR}/Function"
fi

for function in $(ls ${FUNCTION_DIR}/*.sh)
do
        source ${function}
done

#------------------------------------------------------------------------------
#	Validate the command line arguments.
#------------------------------------------------------------------------------
TARGET=${1:?"ERROR: Please specify a DBMS type from the list '$(targets)'."}
PST=${2:-1}     	# Primary(1), Secondary(2) or Tertiary(3).

if	[ "${TARGET}" ]
then
	valid_target ${TARGET}
	Rc=$?

	if	[ ${Rc} -ne 0 ]
	then
		echo "Invalid DBMS type '${TARGET}'"
		echo "Please select from the list '$(targets)'."
		return 1
	fi
else
	return 1
fi

#-----------------------------------------------------------------------------
#	PATH.
#-----------------------------------------------------------------------------
if   [ "${Uname}" != "Darwin" ]
then
	#----------------------------------------------------------------------
	#	Linux.
	#----------------------------------------------------------------------
	ORIGINAL_PATH="/usr/lib64/qt-3.3/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"
else
	#----------------------------------------------------------------------
	#	Mac OS.
	#----------------------------------------------------------------------
	ORIGINAL_PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11/bin:/Users/srees/Bin:."
fi

export PATH="${PG_BIN}:${ORIGINAL_PATH}"

#------------------------------------------------------------------------------
#	DBMS specific PostgreSQL environment variables. 
#------------------------------------------------------------------------------
build_pg_env_arrays ${TARGET}

if	[ ${PST} -eq 1 ]
then
	export PGDATA="${PRIMARY_DATA[$(stoi ${TARGET})]}"
	export PGDATABASE="${PRIMARY_DATABASE[$(stoi ${TARGET})]}"
	export PGHOST="${PRIMARY_HOST[$(stoi ${TARGET})]}"
	export PGPASSWORD="${PRIMARY_PASSWORD[$(stoi ${TARGET})]}"
	export PGPORT="${PRIMARY_PORT[$(stoi ${TARGET})]}"
	export PGUSER="${PRIMARY_USER[$(stoi ${TARGET})]}"

elif	[ ${PST} -eq 2 ]
then
	export PGDATA="${SECONDARY_DATA[$(stoi ${TARGET})]}"
	export PGDATABASE="${SECONDARY_DATABASE[$(stoi ${TARGET})]}"
	export PGHOST="${SECONDARY_HOST[$(stoi ${TARGET})]}"
	export PGPASSWORD="${SECONDARY_PASSWORD[$(stoi ${TARGET})]}"
	export PGPORT="${SECONDARY_PORT[$(stoi ${TARGET})]}"
	export PGUSER="${SECONDARY_USER[$(stoi ${TARGET})]}"

elif	[ ${PST} -eq 3 ]
then
	export PGDATA="${TERTIARY_DATA[$(stoi ${TARGET})]}"
	export PGDATABASE="${TERTIARY_DATABASE[$(stoi ${TARGET})]}"
	export PGHOST="${TERTIARY_HOST[$(stoi ${TARGET})]}"
	export PGPASSWORD="${TERTIARY_PASSWORD[$(stoi ${TARGET})]}"
	export PGPORT="${TERTIARY_PORT[$(stoi ${TARGET})]}"
	export PGUSER="${TERTIARY_USER[$(stoi ${TARGET})]}"

else
	echo "Unexpected value '${PST}'. Valid values are 1, 2 or 3"
	return 1
fi

export PG_ENV="${TARGET}"

#-----------------------------------------------------------------------------
#	Return.
#-----------------------------------------------------------------------------
