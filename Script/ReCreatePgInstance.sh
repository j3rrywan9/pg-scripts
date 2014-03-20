#!/bin/bash
#------------------------------------------------------------------------------
#	Destroy, create and populate a DBMS.
#------------------------------------------------------------------------------
Environment=${1:-"OffTheShelf"}
Version=${2:-"92"}
LoadData=${3:-"TRUE"}

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

write_log "Recreating version '${Version}' of the '${Environment}' instance."

#------------------------------------------------------------------------------
#	Set PostgreSQL Version links.
#------------------------------------------------------------------------------
rm ${SCRIPT_DIR}/PG_ROOT.sh	\
	&& ln -s ${SCRIPT_DIR}/PG_ROOT${Version}.sh ${SCRIPT_DIR}/PG_ROOT.sh

#------------------------------------------------------------------------------
#	Set DBMS Environment links.
#------------------------------------------------------------------------------
rm ${SCRIPT_DIR}/PgEnv.sh	\
	&& ln -s ${SCRIPT_DIR}/PgEnv.${Environment}.sh ${SCRIPT_DIR}/PgEnv.sh

#------------------------------------------------------------------------------
#	Destroy the existing DBMS instance.
#------------------------------------------------------------------------------
write_log "Destroying the old instance."
${SCRIPT_DIR}/DestroyPgInstance.sh ${Environment}

#------------------------------------------------------------------------------
#	Create a new DBMS instance.
#------------------------------------------------------------------------------
write_log "Creating the new instance."
${SCRIPT_DIR}/CreatePgInstance.sh ${Environment}

#------------------------------------------------------------------------------
#	Populate the DBMS instance.
#------------------------------------------------------------------------------
if	[ "${LoadData}" = "TRUE" ]
then
	write_log "Populating the new instance."
	${SCRIPT_DIR}/RunScripts.sh ${Environment} ${Version}
else
	write_log "The new instance has no user objects."
fi

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
do_exit
