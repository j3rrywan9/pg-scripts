build_pg_env_arrays()	{
	#----------------------------------------------------------------------
	#	Build arrays of PostgreSQL environment variables for
	#	the customer environments.
	#----------------------------------------------------------------------
	Targets="${1}"

	#----------------------------------------------------------------------
	#	Local Functions.
	#----------------------------------------------------------------------
	dbms_owner()	{
		Me="dbms_owner"
		TheTaget=${1:?"ERROR:(${Me}): Please specify a target."}
		TheDbmsOwner="${DbmsOwner}"

		if	[ "${TheTaget}" = "NotOwnedByPostgres" ]
		then
			TheDbmsOwner="${ForeignDbmsOwner}"
		fi

		echo ${TheDbmsOwner}
	}

	master_database()	{
		Me="master_database"
		TheTaget=${1:?"ERROR:(${Me}): Please specify a target."}
		TheMasterDatabase="${MasterDatabase}"

		if	[ "${TheTaget}" = "NoDefaultDatabases" ]
		then
			TheMasterDatabase="${ForeignMasterDatabase}"
		fi

		echo ${TheMasterDatabase}
	}

	superuser()	{
		Me="superuser"
		TheTaget=${1:?"ERROR:(${Me}): Please specify a target."}
		TheSuperUser="${SuperUser}"

		if	[ "${TheTaget}" = "NotOwnedByPostgres" ]	\
			||	[ "${TheTaget}" = "NoPostgresRole" ]
		then
			TheSuperUser="${ForeignSuperUser}"
		fi

		echo ${TheSuperUser}
	}

	#----------------------------------------------------------------------
	#	Local Variables.
	#----------------------------------------------------------------------
	DbmsOwner="postgres"
	EnterpriseDB=""			# EnterpriseDB if non-empty string
	ForeignDbmsOwner="delphix"
	ForeignMasterDatabase="my_postgres"
	ForeignSuperUser="delphix"
	MasterDatabase="postgres"
	SuperUser="postgres"

	Primary=1
	Secondary=2
	Tertiary=3

	if	[ ! "${Targets}" ]
	then
		Targets="$(targets)"
	fi
	
	#----------------------------------------------------------------------
	#	Host names and IP-addresses.
	#----------------------------------------------------------------------
	host_names_and_ip_addresses

	#----------------------------------------------------------------------
	#	Create a 5 digit port number.
	#	Digit 1: Primary, Secondary or Tertiary.
	#	Digits 2 and 3: Target environment.
	#	Digits 4 and 5: PostgreSQL version.
	#----------------------------------------------------------------------

	#----------------------------------------------------------------------
	#	PGPORT: Digits 4 and 5
	#----------------------------------------------------------------------
	MyPgIntegerVersion=$(echo ${PG_VERSION} | sed -e 's/\.//' -e 's/[A-Za-z]//g')
	MyPgIntegerVersion=$(expr $MyPgIntegerVersion - 90)

	#----------------------------------------------------------------------
	#	EnterpriseDB Version.
	#----------------------------------------------------------------------
	echo ${PG_VERSION} | grep "AS" > /dev/null 2>&1			\
		&& MyPgIntegerVersion=$(expr $MyPgIntegerVersion + 10)	\
		&& EnterpriseDB="true"

	if	[ ${MyPgIntegerVersion} -lt 10 ]
	then
		MyPgIntegerVersion=0${MyPgIntegerVersion}
	fi

	for Target in ${Targets}
	do
		REPLICATING[$(stoi ${Target})]=$(replicating ${Target})
			
		#--------------------------------------------------------------
		#	Digits 2 and 3: Target environment.
		#--------------------------------------------------------------
		TargetNumber=$(stoi ${Target})

		if	[ ${TargetNumber} -lt 10 ]
		then
			TargetNumber=0${TargetNumber}
		fi

		#--------------------------------------------------------------
		#	Primary DBMS.
		#--------------------------------------------------------------
		if	[ "${Target}" = "OffTheShelf" ]
		then
			PRIMARY_DATA[$(stoi ${Target})]="${PG_HOME}/data"
			PRIMARY_DATABASE[$(stoi ${Target})]="$(master_database ${Target})"
			PRIMARY_HOST[$(stoi ${Target})]="${PG1_IP_ADDRESS}"
			PRIMARY_OWNER[$(stoi ${Target})]="$(dbms_owner ${Target})"

			if	[ ! "${EnterpriseDB}" ]
			then
				PRIMARY_PORT[$(stoi ${Target})]="5432"
			else
				PRIMARY_PORT[$(stoi ${Target})]="5444"
			fi

			PRIMARY_USER[$(stoi ${Target})]="$(superuser ${Target})"
			PRIMARY_PASSWORD[$(stoi ${Target})]="$(get_PGPASSWORD ${PRIMARY_HOST[$(stoi ${Target})]} ${PRIMARY_USER[$(stoi ${Target})]} ${PRIMARY_PORT[$(stoi ${Target})]})"
		else
			PRIMARY_DATA[$(stoi ${Target})]="${PG_HOME}/data.${Target}Primary"
			PRIMARY_DATABASE[$(stoi ${Target})]="$(master_database ${Target})"
			PRIMARY_HOST[$(stoi ${Target})]="${PG1_IP_ADDRESS}"
			PRIMARY_OWNER[$(stoi ${Target})]="$(dbms_owner ${Target})"
			PRIMARY_PORT[$(stoi ${Target})]="${Primary}${TargetNumber}${MyPgIntegerVersion}"
			PRIMARY_USER[$(stoi ${Target})]="$(superuser ${Target})"
			PRIMARY_PASSWORD[$(stoi ${Target})]="$(get_PGPASSWORD ${PRIMARY_HOST[$(stoi ${Target})]} ${PRIMARY_USER[$(stoi ${Target})]} ${PRIMARY_PORT[$(stoi ${Target})]})"
		fi
	
		if	[ "${REPLICATING[$(stoi ${Target})]}" ]
		then
			#------------------------------------------------------
			#	Secondary DBMS.
			#------------------------------------------------------
			SECONDARY_DATA[$(stoi ${Target})]="${PG_HOME}/data.${Target}Secondary"
			SECONDARY_DATABASE[$(stoi ${Target})]="$(master_database ${Target})"
			SECONDARY_HOST[$(stoi ${Target})]="${PG2_IP_ADDRESS}"
			SECONDARY_OWNER[$(stoi ${Target})]="$(dbms_owner ${Target})"
			SECONDARY_PORT[$(stoi ${Target})]="${Secondary}${TargetNumber}${MyPgIntegerVersion}"
			SECONDARY_USER[$(stoi ${Target})]="$(superuser ${Target})"
			SECONDARY_PASSWORD[$(stoi ${Target})]="$(get_PGPASSWORD ${SECONDARY_HOST[$(stoi ${Target})]} ${SECONDARY_USER[$(stoi ${Target})]} ${SECONDARY_PORT[$(stoi ${Target})]})"

			if	[ "${Target}" = "Cascading" ]
			then
				#----------------------------------------------
				#	Tertiary DBMS.
				#----------------------------------------------
				TERTIARY_DATA[$(stoi ${Target})]="${PG_HOME}/data.${Target}Tertiary"
				TERTIARY_DATABASE[$(stoi ${Target})]="$(master_database ${Target})"
				TERTIARY_HOST[$(stoi ${Target})]="${PG3_IP_ADDRESS}"
				TERTIARY_OWNER[$(stoi ${Target})]="$(dbms_owner ${Target})"
				TERTIARY_PORT[$(stoi ${Target})]="${Tertiary}${TargetNumber}${MyPgIntegerVersion}"
				TERTIARY_USER[$(stoi ${Target})]="$(superuser ${Target})"
				TERTIARY_PASSWORD[$(stoi ${Target})]="$(get_PGPASSWORD ${TERTIARY_HOST[$(stoi ${Target})]} ${TERTIARY_USER[$(stoi ${Target})]} ${TERTIARY_PORT[$(stoi ${Target})]})"
			fi
		fi
	done

	#----------------------------------------------------------------------
	#	Return.
	#----------------------------------------------------------------------
	return
}
