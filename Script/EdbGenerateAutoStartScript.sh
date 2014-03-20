#!/bin/sh
#------------------------------------------------------------------------------
#	Create a RHEL autostart script for EnterpriseDB.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
SCRIPT_DIR="${MY_FULL_DIR}"
FUNCTION_DIR="${SCRIPT_DIR}/Function"

#------------------------------------------------------------------------------
#	Common Functions.
#------------------------------------------------------------------------------
source ${SCRIPT_DIR}/PG_ROOT.sh

for function in $(ls ${FUNCTION_DIR}/*.sh)
do
	source ${function}
done

#------------------------------------------------------------------------------
#	Validate the DBMS type.
#------------------------------------------------------------------------------
PGMAJORVERSION=${1:?"ERROR: Please specify the EnterpriseDB Major Version, e.g. 9.2AS"}
TARGET=${2:?"ERROR: Please specify a DBMS type from the list '$(targets)'."}
PST=${3:?"ERROR: You must specify 'Primary', Secondary' or 'Tertiary'."}

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
DBMS_OWNER="postgres"	# Owner of the DBMS processes and files.
PRIMARY="Primary"       # ReadWrite DBMS replicating to Secondary DBMS.
SECONDARY="Secondary"   # ReadOnly DBMS receiving updates from Primarty DBMS.
TERTIARY="Tertiary"     # ReadOnly DBMS receiving updates from Secondary DBMS.

valid_target ${TARGET}
Rc=$?

if	[ ${Rc} -ne 0 ]
then
	echo "Invalid DBMS type '${TARGET}'"
	echo "Please select from the list '$(targets)'."
	exit 1
fi

test "${PST}" != "${PRIMARY}"			\
	&& test "${PST}" != "${SECONDARY}"	\
	&& test "${PST}" != "${TERTIARY}"	\
	&& test echo "'${PST}' must be '"${PRIMARY}"','"${SECONDARY}"' or '"${TERTIARY}"'"	\
	&& exit 1

if	[ "${TARGET}" = "NotOwnedByPostgres" ]
then
	DBMS_OWNER="delphix"
fi

#------------------------------------------------------------------------------
#	Emit the commands.
#------------------------------------------------------------------------------
cat <<EnfOfFile
#!/bin/bash
#
# chkconfig: 2345 85 15
# description: Starts and stops the Postgres Plus Advanced Server ${PGMAJORVERSION} database server

# Postgres Plus Advanced Server Service script for Linux

# Set defaults for configuration variables
PGMAJORVERSION="${PGMAJORVERSION}"
TARGET="${TARGET}"
PST="${PST}"

TAG="\${TARGET}\${PST}"
#PGDATAROOT="/var/lib/PostgresPlus/\${PGMAJORVERSION}"
PGDATAROOT="/var/lib/PostgreSQL/\${PGMAJORVERSION}"

#PGROOT="/usr/PostgresPlus/\${PGMAJORVERSION}"
PGROOT="/usr/PostgreSQL/\${PGMAJORVERSION}"
PGBIN="\${PGROOT}/bin"
PGLIB="\${PGROOT}/lib"

if	[ "\${TARGET}" != "OffTheShelf" ]
then
	PGDATA=\${PGDATAROOT}/data.\${TAG}
else
	PGDATA=\${PGDATAROOT}/data
fi

PGLOG=\${PGDATAROOT}/pgstartup.\${TAG}.log
WALDIR="\${PGDATAROOT}/WALarchive/\${TARGET}"

export PGDATA

start()
{
	startserver=0
	if [ -e "\${PGDATA}/postmaster.pid" ]
	then
		pidofpro=\`head -n 1 \${PGDATA}/postmaster.pid\`
		alive=\`ps -p \$pidofpro | grep \$pidofpro\`

		if [ "x\$alive" != "x" ]
		then
			exit
		else
			startserver=1
		fi
	else
		startserver=1
	fi
	if [ \$startserver != 0 ]
	then
		echo $"Starting Postgres Plus Advanced Server \${PGMAJORVERSION}: "
		su - ${DBMS_OWNER} -c "LD_LIBRARY_PATH=\${PGLIB}:\$LD_LIBRARY_PATH \${PGBIN}/pg_ctl -w start -D \"\${PGDATA}\" -l \"\${PGDATA}/pg_log/startup.log\""
	
        if [ \$? -eq 0 ];
		then
			echo "Postgres Plus Advanced Server \${PGMAJORVERSION} started successfully"
            exit 0
		else
			echo "Postgres Plus Advanced Server \${PGMAJORVERSION} did not start in a timely fashion, please see \${PGDATA}/pg_log/startup.log for details"
            exit 1
		fi
	fi
}

stop()
{
	if [ -e "\${PGDATA}/postmaster.pid" ]
	then
		pidofproc=\`head -n 1 \${PGDATA}/postmaster.pid\`
		pidalive=\`ps -p \$pidofproc | grep \$pidofproc\`
		
		if [ "x\$pidalive" != "x" ]
		then
			echo $"Stopping Postgres Plus Advanced Server \${PGMAJORVERSION}: "
			su - ${DBMS_OWNER} -c "LD_LIBRARY_PATH=\${PGLIB}:$\LD_LIBRARY_PATH \${PGBIN}/pg_ctl stop -m fast -w -D \"\${PGDATA}\""
		fi
	fi
}

reload()
{
	echo $"Reloading Postgres Plus Advanced Server \${PGMAJORVERSION}: "
	su - ${DBMS_OWNER} -c "LD_LIBRARY_PATH=\${PGLIB}:\$LD_LIBRARY_PATH \${PGBIN}/pg_ctl reload -D \"\${PGDATA}\""
}

restart()
{
	echo $"Restarting Postgres Plus Advanced Server \${PGMAJORVERSION}: "
	su - ${DBMS_OWNER} -c "LD_LIBRARY_PATH=\${PGLIB}:\$LD_LIBRARY_PATH \${PGBIN}/pg_ctl restart -m fast -w -D \"\${PGDATA}\" -l \"\${PGDATA}/pg_log/startup.log\""

        if [ \$? -eq 0 ];
		then
			echo "Postgres Plus Advanced Server \${PGMAJORVERSION} restarted successfully"
            exit 0
		else
			echo "Postgres Plus Advanced Server \${PGMAJORVERSION} did not start in a timely fashion, please see \${PGDATA}/pg_log/startup.log for details"
            exit 1
	fi
}

# See how we were called.
case "\$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  reload)
        reload
        ;;
  restart)
        restart
        ;;
  condrestart)
        if [ -e "\${PGDATA}/postmaster.pid" ]; then
            restart
        fi
        ;;
  status)
        su - ${DBMS_OWNER} -s /bin/bash -m -c "LD_LIBRARY_PATH=\${PGLIB}:\$LD_LIBRARY_PATH \${PGBIN}/pg_ctl status -D \"\${PGDATA}\""
        ;;
  *)
        echo \$"Usage: \$0 {start|stop|restart|condrestart|reload|status}"
        exit 1
esac

EnfOfFile
