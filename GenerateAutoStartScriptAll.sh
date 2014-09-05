#!/bin/bash
#------------------------------------------------------------------------------
#       Generate a RHEL autostart script for all DBMS.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#       Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#       Local Variables.
#------------------------------------------------------------------------------
Environments="$(targets)"
PgVers="${PG_VERSIONS}"
RootName="/tmp/postgresql-"

for PgVer in ${PgVers}
do
        echo "PostgreSQL Version: ${PgVer}"

        for Environment in ${Environments}
        do
                echo "${Environment}"
                build_pg_env_arrays ${Environment}

                PRIMARY_DATA=${PRIMARY_DATA[$(stoi ${Environment})]}
                SECONDARY_DATA=${SECONDARY_DATA[$(stoi ${Environment})]}
                TERTIARY_DATA=${TERTIARY_DATA[$(stoi ${Environment})]}

                #--------------------------------------------------------------
                #       Primary DBMS.
                #--------------------------------------------------------------
                Node="Primary"
                Script="${RootName}${PgVer}-${Environment}${Node}"

                ${SCRIPT_DIR}/GenerateAutoStartScript.sh                \
                                                        ${PgVer}        \
                                                        ${Environment}  \
                                                        ${Node}         \
                                                        > ${Script}

                if      [ "${SECONDARY_DATA}" ]
                then
                        #------------------------------------------------------
                        #       Secondary DBMS.
                        #------------------------------------------------------
                        Node="Secondary"
                        Script="${RootName}${PgVer}-${Environment}${Node}"

                        ${SCRIPT_DIR}/GenerateAutoStartScript.sh        \
                                                        ${PgVer}        \
                                                        ${Environment}  \
                                                        ${Node}         \
                                                        > ${Script}

                        if      [ "${TERTIARY_DATA}" ]
                        then
                                #----------------------------------------------
                                #       Tertiary DBMS.
                                #----------------------------------------------
                                Node="Tertiary"
                                Script="${RootName}${PgVer}-${Environment}${Node}"

                                ${SCRIPT_DIR}/GenerateAutoStartScript.sh\
                                                        ${PgVer}        \
                                                        ${Environment}  \
                                                        ${Node}         \
                                                        > ${Script}
                        fi
                fi
        done
done

#------------------------------------------------------------------------------
#       Exit.
#------------------------------------------------------------------------------
exit
