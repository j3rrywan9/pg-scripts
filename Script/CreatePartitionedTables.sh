#!/bin/bash
#------------------------------------------------------------------------------
#	Create partitioned tables.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
#	Define the environment.
#------------------------------------------------------------------------------
MY_DIR="`dirname ${0}`"
MY_FULL_DIR="`(cd ${MY_DIR}; pwd)`"
source ${MY_FULL_DIR}/ScriptEnv.sh

#------------------------------------------------------------------------------
#	Local Variables.
#------------------------------------------------------------------------------
TemplateClause="TEMPLATE $(database_template ${PG_ENV})"	# Template DB

	#----------------------------------------------------------------------
	#	Temporary files.
	#----------------------------------------------------------------------
SqlError="$(get_temporary_file SqlError)"
SqlFile="$(get_temporary_file SqlFile)"
SqlResult="$(get_temporary_file SqlResult)"

#------------------------------------------------------------------------------
#	Generate the SQL file.
#------------------------------------------------------------------------------
cat > ${SqlFile} <<-EndOfSql
	-----------------------------------------------------------------------
	--	Drop the database.
	-----------------------------------------------------------------------
	DROP DATABASE IF EXISTS partitioned_tables;

	-----------------------------------------------------------------------
	--	Create the database.
	-----------------------------------------------------------------------
	CREATE DATABASE	partitioned_tables ${TemplateClause};

	\connect partitioned_tables

	-----------------------------------------------------------------------
	--	Create the master table.
	-----------------------------------------------------------------------
	CREATE TABLE sales(org int, name varchar(10));
	
	-----------------------------------------------------------------------
	--	Create the child tables.
	-----------------------------------------------------------------------
	CREATE TABLE sales_part1
	   (CHECK (org < 6))
	   INHERITS (sales);
	
	CREATE TABLE sales_part2
	   (CHECK (org >=6 and org <=10))
	   INHERITS (sales);
	
	-----------------------------------------------------------------------
	--	Create the INSERT trigger function.
	-----------------------------------------------------------------------
	CREATE OR REPLACE FUNCTION sales_insert_trigger()
	RETURNS TRIGGER AS \$\$
	BEGIN
	    IF ( NEW.ORG < 6)  THEN
	        INSERT INTO sales_part1 VALUES(NEW.*);
	    ELSIF ( NEW.ORG >= 6 AND NEW.ORG <11) THEN
	        INSERT INTO sales_part2 VALUES(NEW.*);
	    ELSE
	        RAISE EXCEPTION 'Organization out of range.  Fix
	the sales_insert_trigger() function!';
	END IF;
	    RETURN NULL;
	END;
	\$\$
	LANGUAGE plpgsql;
	
	-----------------------------------------------------------------------
	--	Create the INSERT trigger.
	-----------------------------------------------------------------------
	CREATE TRIGGER insert_sales
	    BEFORE INSERT ON sales
	    FOR EACH ROW
	    EXECUTE PROCEDURE sales_insert_trigger();
	
	-----------------------------------------------------------------------
	--	Populate the master table.
	-----------------------------------------------------------------------
	INSERT INTO sales VALUES(1,'Craig');
	INSERT INTO sales VALUES(2,'Mike');
	INSERT INTO sales VALUES(3,'Michelle');
	INSERT INTO sales VALUES(4,'Joe');
	INSERT INTO sales VALUES(5,'Scott');
	INSERT INTO sales VALUES(6,'Roger');
	INSERT INTO sales VALUES(7,'Fred');
	INSERT INTO sales VALUES(8,'Sam');
	INSERT INTO sales VALUES(9,'Sonny');
	INSERT INTO sales VALUES(10,'Chris');
	
	-----------------------------------------------------------------------
	--	Display the data in the master table.
	-----------------------------------------------------------------------
	select * from sales;
	
	-----------------------------------------------------------------------
	--	Display the data in the child tables.
	-----------------------------------------------------------------------
	select * from sales_part1;
	
	select * from sales_part2;
EndOfSql

#------------------------------------------------------------------------------
#	Create the partitioned tables.
#------------------------------------------------------------------------------
write_log "PostgreSQL Version: ${PG_VERSION}, Environment '${PG_ENV}'"
write_log "Creating Partitioned tables."

do_psql ${SqlFile} 1> ${SqlResult} 2> ${SqlError}
Rc=$?

psql_error_check ${Rc} ${SqlError}
Rc=$?

if	[ ${Rc} -eq 0 ]
then
	cat ${SqlResult} >> ${LOG_FILE}
else
	ERROR_COUNT=$(expr ${ERROR_COUNT} + 1)
fi

#------------------------------------------------------------------------------
#	Exit.
#------------------------------------------------------------------------------
do_exit
