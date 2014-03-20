#!/bin/bash
#------------------------------------------------------------------------------
#	Modify ACL's for files and directories.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Must be 'root' to perform these operations.
#------------------------------------------------------------------------------
exit_if_not_user root

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
EdbDataRoot="/var/lib/PostgresPlus"	# EnterpriseDB data is rooted here.
EdbInstallations="${EDB_VERSIONS}"
PgDataRoot="/var/lib/pgsql"	# PostgreSQL data is rooted here.
PgHome="/home/postgres"		# Scripts are at ${PgHome}/Script
PgInstallations="${PG_VERSIONS}"

#------------------------------------------------------------------------------
#	Directories.
#------------------------------------------------------------------------------
mkdir -p ${PgDataRoot} ${EdbDataRoot}

for EdbInstallation in ${EdbInstallations}
do
	mkdir -p ${EdbDataRoot}/${EdbInstallation}
done

for PgInstallation in ${PgInstallations}
do
	mkdir -p ${PgDataRoot}/${PgInstallation}
done

chmod -R 777 ${PgDataRoot} ${EdbDataRoot}
chown -R postgres:postgres ${PgDataRoot} ${EdbDataRoot}

chmod 755 ${PgHome}	# So that others may access Scripts.

#------------------------------------------------------------------------------
#	End
#------------------------------------------------------------------------------
