#!/bin/sh
#------------------------------------------------------------------------------
#	Create a RHEL autostart script for PostgreSQL.
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
PGMAJORVERSION=${1:?"ERROR: Please specify the PostgreSQL Major Version, e.g. 9.2"}
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
#!/bin/sh
# chkconfig: - 64 36
# description: PostgreSQL ${TARGET}, ${PST} DBMS.
# processname: ${DBMS_OWNER}
#
# postgresql    This is the init script for starting up the PostgreSQL '${TARGET}' ${PST} DBMS.
#

# Source function library.
INITD=/etc/rc.d/init.d
. \$INITD/functions

# Get function listing for cross-distribution logic.
TYPESET=\`typeset -f|grep "declare"\`

# Get network config.
. /etc/sysconfig/network

# Find the name of the script
NAME=\`basename \$0\`
if [ \${NAME:0:1} = "S" -o \${NAME:0:1} = "K" ]
then
	NAME=\${NAME:3}
fi

# For SELinux we need to use 'runuser' not 'su'
if [ -x /sbin/runuser ]
then
    SU=runuser
else
    SU=su
fi

# Set defaults for configuration variables
PGMAJORVERSION="${PGMAJORVERSION}"
TARGET="${TARGET}"
PST="${PST}"

TAG="\${TARGET}\${PST}"
PGDATAROOT="/var/lib/pgsql/\${PGMAJORVERSION}"

PGENGINE=/usr/pgsql-\${PGMAJORVERSION}/bin

if	[ "\${TARGET}" != "OffTheShelf" ]
then
	PGDATA=\${PGDATAROOT}/data.\${TAG}
else
	PGDATA=\${PGDATAROOT}/data
fi

PGLOG=\${PGDATAROOT}/pgstartup.\${TAG}.log
WALDIR="\${PGDATAROOT}/WALarchive/\${TARGET}"

export PGDATA

#
#	Workaround for PostgreSQL bug related to separate config and data directories.
#
if	[ "\${TARGET}" = "ConfigSansData" ] && [ "\${PGMAJORVERSION}" = "9.1" ]
then
	SUFFIX="_DATA"
else
	SUFFIX=""
fi

[ -f "\$PGENGINE/postmaster" ] || exit 1

script_result=0

start(){
	echo "\$(date): Entering function 'start()'" >> \$PGLOG

	PSQL_START=\$"Starting \${NAME} service: "

	# Make sure startup-time log file is valid
	if [ ! -e "\$PGLOG" -a ! -h "\$PGLOG" ]
	then
		touch "\$PGLOG" || exit 1
		chown ${DBMS_OWNER}:${DBMS_OWNER} "\$PGLOG"
		chmod go-rwx "\$PGLOG"
		[ -x /sbin/restorecon ] && /sbin/restorecon "\$PGLOG"
	fi

	#
	# Check for empty WAL files.
	#
	EmptyWalFiles="/tmp/EmptyWalFiles.\$\$"
	rm -f \${EmptyWalFiles}
	find \${PGDATA}\${SUFFIX}/pg_xlog \${WALDIR} -maxdepth 1 -type f -empty > \${EmptyWalFiles} 2> /dev/null

	if	[ -s \${EmptyWalFiles} ]
	then
		echo "Empty WAL file(s) found."  >> \$PGLOG
		cat \${EmptyWalFiles} >> \$PGLOG

		cat <<-EndOfFile >> \$PGLOG
		Aborting Start-Up.

		You can run
		   \${PG_ROOT}/Script/DestroyPgInstance.sh \${TARGET}
		to erase this environment.
		Then, optionally run
		   \${PG_ROOT}/Script/CreatePgInstance.sh \${TARGET}
		to re-create this environment.

		N.B. All data will be lost if you run DestroyPgInstance.sh
		EndOfFile

		echo "\$(date): Exiting function 'start()'" >> \$PGLOG
		rm -f \${EmptyWalFiles}
		exit 1
	fi

	rm -f \${EmptyWalFiles}

	if	[ -f \${PGDATA}\${SUFFIX}/postmaster.pid ]
	then
		echo "'\${PGDATA}\${SUFFIX}/postmaster.pid' exists." >> \$PGLOG
		echo "Removing '\${PGDATA}\${SUFFIX}/postmaster.pid' now."  >> \$PGLOG
		rm -f \${PGDATA}\${SUFFIX}/postmaster.pid
	fi

	echo -n "\$PSQL_START"
	\$SU -l ${DBMS_OWNER} -c "\$PGENGINE/pg_ctl -D \$PGDATA start &" >> "\$PGLOG" 2>&1 < /dev/null
	sleep 2

	pid=\`head -n 1 "\${PGDATA}\${SUFFIX}/postmaster.pid" 2>/dev/null\`

	if [ "x\$pid" != x ]
	then
		success "\$PSQL_START"
		echo
	else
		failure "\$PSQL_START"
		echo
		script_result=1
	fi

	echo "\$(date): Exiting function 'start()'" >> \$PGLOG
}

status(){
	echo -n "Status of \${NAME} service: "

	\$SU -l ${DBMS_OWNER} -c "\$PGENGINE/pg_ctl -D \${PGDATA}\${SUFFIX} status" > /dev/null 2>&1 < /dev/null
	ret=\$? 

	if [ \$ret -eq 0 ]
	then
		echo_success
	else
		echo_failure
		script_result=1
	fi
	echo

}

stop(){
	echo "\$(date): Entering function 'stop()'" >> \$PGLOG

	echo -n "Stopping \${NAME} service: "

	\$SU -l ${DBMS_OWNER} -c "\$PGENGINE/pg_ctl -D \${PGDATA}\${SUFFIX} stop -s -m fast" > /dev/null 2>&1 < /dev/null
	ret=\$? 

	if [ \$ret -eq 0 ]
	then
		echo_success

		if	[ -f \${PGDATA}\${SUFFIX}/postmaster.pid ]
		then
			echo "'\${PGDATA}\${SUFFIX}/postmaster.pid' exists after successful shutdown." >> \$PGLOG
			echo "Removing '\${PGDATA}\${SUFFIX}/postmaster.pid' now."  >> \$PGLOG
			rm -f \${PGDATA}\${SUFFIX}/postmaster.pid
		fi
	else
		echo_failure
		script_result=1

		echo "Shutdown failed." >> \$PGLOG	

		if	[ -f \${PGDATA}\${SUFFIX}/postmaster.pid ]
		then
			echo "'\${PGDATA}\${SUFFIX}/postmaster.pid' still exists." >> \$PGLOG
		else
			echo "'\${PGDATA}\${SUFFIX}/postmaster.pid' does not exist." >> \$PGLOG
		fi
	fi

	echo "\$(date): Exiting function 'stop()'" >> \$PGLOG

}

restart(){
    stop
    start
}

reload(){
    \$SU -l ${DBMS_OWNER} -c "\$PGENGINE/pg_ctl reload -D '\${PGDATA}\${SUFFIX}' -s" > /dev/null 2>&1 < /dev/null
}

# See how we were called.
case "\$1" in
  start)
	start
	;;
  stop)
	stop
	;;
  status)
	status
	;;
  restart)
	restart
	;;
  reload)
	reload
	;;
  *)
	echo \$"Usage: \$0 {start|stop|status|reload|restart}"
	exit 2
esac

exit \$script_result
EnfOfFile
