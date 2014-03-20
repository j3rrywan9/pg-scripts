#!/bin/bash
#------------------------------------------------------------------------------
#	Show a one-liner describing each PostgreSQL DBMS.
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Local Functions.
#------------------------------------------------------------------------------
function cpad {
	word="$1"

	while [ ${#word} -lt $2 ]
	do
		word="$word$3";

		if [ ${#word} -lt $2 ]; then
			word="$3$word"
		fi;
	done;

	echo -n "$word";
}

function header {
	separator
	echo -n "|"
	cpad "PgVer" ${PgVerWidth} " "
	echo -n "|"
	cpad "Environment" ${EnvironmentWidth} " "
	echo -n "|"
	cpad "Ordinality" ${OrdinalityWidth} " "
	echo -n "|"
	cpad "Port" ${PortWidth} " "
	echo -n "|"
	cpad "PGDATA" ${PgdataWidth} " "
	echo "|"
	separator
}

function line_item {
	echo -n "|"
	lpad "${1}" ${PgVerWidth} " "
	echo -n "|"
	rpad "${2}" ${EnvironmentWidth} " "
	echo -n "|"
	rpad "${3}" ${OrdinalityWidth} " "
	echo -n "|"
	lpad "${4}" ${PortWidth} " "
	echo -n "|"
	rpad "${5}" ${PgdataWidth} " "
	echo "|"
}

function lpad {
	word="$1"

	while [ ${#word} -lt $2 ]
	do
		word="$3$word";
	done;

	echo -n "$word";
}

function separator {
	local Separator

	if	[ ! "${Separator}" ]
	then
		for Width in ${PgVerWidth} ${EnvironmentWidth}	\
				${OrdinalityWidth} ${PortWidth} ${PgdataWidth}
		do
			Separator=${Separator}"+"$(repeat "-" ${Width})
		done

		Separator=${Separator}"+"
	fi

	echo "${Separator}"
}

function rpad {
	word="$1"

	while [ ${#word} -lt $2 ]
	do
		word="$word$3";
	done;

	echo -n "$word";
}

function repeat {
	str=$1
	num=$2
	v=$(printf "%-${num}s" "$str")
	echo "${v// /${str}}"
}

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
EnvironmentWidth=25
Environments="$(targets)"
OrdinalityWidth=12
PgVerWidth=5
PgVers="${EDB_NO_DOT_VERSIONS} ${PG_NO_DOT_VERSIONS}"
PgdataWidth=72
PortWidth=6

#------------------------------------------------------------------------------
#	Display the PostgreSQL DBMS instance properties.
#------------------------------------------------------------------------------
header

for PgVer in ${PgVers}
do
	source ${SCRIPT_DIR}/PG_ROOT${PgVer}.sh

	for Environment in ${Environments}
	do
		build_pg_env_arrays ${Environment}

		PRIMARY_DATA=${PRIMARY_DATA[$(stoi ${Environment})]}
		PRIMARY_PORT=${PRIMARY_PORT[$(stoi ${Environment})]}
		SECONDARY_DATA=${SECONDARY_DATA[$(stoi ${Environment})]}
		SECONDARY_PORT=${SECONDARY_PORT[$(stoi ${Environment})]}
		TERTIARY_DATA=${TERTIARY_DATA[$(stoi ${Environment})]}
		TERTIARY_PORT=${TERTIARY_PORT[$(stoi ${Environment})]}

		line_item ${PgVer}		\
				${Environment}	\
				PRIMARY		\
				${PRIMARY_PORT}	\
				${PRIMARY_DATA}

		if	[ "${SECONDARY_DATA}" ]
		then
			line_item ${PgVer}			\
					${Environment}		\
					SECONDARY		\
					${SECONDARY_PORT}	\
					${SECONDARY_DATA}

			if	[ "${TERTIARY_DATA}" ]
			then
				line_item ${PgVer}			\
						${Environment}		\
						TERTIARY		\
						${TERTIARY_PORT}	\
						${TERTIARY_DATA}
			fi
		fi
	done
done

header

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
exit
