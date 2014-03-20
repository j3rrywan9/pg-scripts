#!/bin/bash
#------------------------------------------------------------------------------
#	Create one table for each data type, per pg_type.
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
	DROP DATABASE IF EXISTS table_per_type;

	-----------------------------------------------------------------------
	--	Create the database.
	-----------------------------------------------------------------------
	CREATE DATABASE	table_per_type ${TemplateClause};

	\connect table_per_type

	----------------------------------------------------------------------
	--	Create a function to create a table per data type.
	----------------------------------------------------------------------
	CREATE OR REPLACE FUNCTION	table_per_type()
	RETURNS		void
	LANGUAGE	plpgsql
	AS	\$\$
	DECLARE
		l_boolean	boolean;
		l_bytea		text	:= decode('aa','hex');
		l_integer	integer;
		l_interval	text	:= '1 day';
		l_point1	text	:= '(1,1)';
		l_point2	text	:= '(2,2)';
		l_radius	text	:= '3';
		l_record	record;
		l_sql		text;
		l_string	text	:= 'A';
	BEGIN
		FOR l_record IN
			SELECT
				typcategory,
				typname
			FROM
				pg_type
			WHERE
				typcategory not in ('A', 'C', 'P', 'X')
			AND	typname not in (
					'cardinal_number',
					'character_data',
					'line',
					'oid',
					'pg_node_tree',
					'regclass',
					'regconfig',
					'regdictionary',
					'regoper',
					'regoperator',
					'regproc',
					'regprocedure',
					'regtype',
					'reltime',
					'sql_identifier',
					'time_stamp',
					'yes_or_no'
				)
			ORDER BY
				typcategory,
				typname
		LOOP
			l_sql := '';
	
			EXECUTE 'CREATE TABLE IF NOT EXISTS '
					|| l_record.typname
					|| ' (col1 '
					|| l_record.typname
					|| ' not null);';
	
			IF (l_record.typcategory = 'B') THEN
				FOR l_boolean IN
					SELECT true
					UNION
					SELECT false
				LOOP
					l_sql := l_sql
							|| 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| l_boolean
							|| ');';
	
				END LOOP;
	
			ELSIF (l_record.typcategory = 'D') THEN
				l_sql := 'INSERT INTO '
						|| l_record.typname
						|| ' (col1) VALUES ('
						|| quote_literal( '2013-01-01 00:00:00.000000'
						) || ');';
	
			ELSIF (l_record.typcategory = 'G') THEN
				IF (
					l_record.typname = 'box'	OR
					l_record.typname = 'lseg'	OR
					l_record.typname = 'path'	OR
					l_record.typname = 'polygon'
					) THEN
					
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) VALUES ('
							|| quote_literal( '('
							|| l_point1
							|| ','
							|| l_point2
							|| ')' )
							|| ');';
	
				ELSIF (l_record.typname = 'circle') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) VALUES ('
							|| quote_literal( '('
							|| l_point1
							|| ','
							|| l_radius
							|| ')' )
							|| ');';
	
				ELSIF (l_record.typname = 'point') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) VALUES ('
							|| quote_literal( l_point1 )
							|| ');';
	
				END IF;
	
			ELSIF (l_record.typcategory = 'I') THEN
				IF (l_record.typname = 'cidr') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) VALUES ('
							|| quote_literal('192.168.100.128/25')
							|| ');';
	
				ELSIF (l_record.typname = 'inet') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) VALUES ('
							|| quote_literal('192.168.100.128/16')
							|| ');';
	
				END IF;
	
			ELSIF (l_record.typcategory = 'N') THEN
				FOR l_integer IN
					SELECT generate_series(-1,+1,1)
				LOOP
					l_sql := l_sql
							|| 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| l_integer
							|| ');';
	
				END LOOP;
	
			ELSIF (l_record.typcategory = 'R') THEN
	
				IF (
					l_record.typname = 'int4range'	OR
					l_record.typname = 'int8range'	OR
					l_record.typname = 'numrange'
					) THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal( '[3,7]' )
							|| ');';
	
				ELSIF (
					l_record.typname = 'tsrange'  OR
					l_record.typname = 'tstzrange'  OR
					l_record.typname = 'daterange'
					) THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal( '[1/1/2012, 1/1/2013]' )
							|| ');';
				END IF;
	
			ELSIF (l_record.typcategory = 'S') THEN
				l_sql := l_sql
						|| 'INSERT INTO '
						|| l_record.typname
						|| ' (col1) '
						|| ' VALUES ('
						|| quote_literal(l_string)
						|| ');';
	
			ELSIF (l_record.typcategory = 'T') THEN
				IF (l_record.typname != 'tinterval') THEN
					l_sql := l_sql
							|| 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal(l_interval)
							|| ');';
				ELSE
					l_sql := l_sql
							|| 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal( '["May 10, 1947 23:59:12 -08:00" "Jan 14, 1973 03:14:21 -08:00"]' )
							|| ');';
				END IF;
	
			ELSIF (l_record.typcategory = 'U') THEN
				IF (l_record.typname = 'bytea') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal(l_bytea)
							|| ');';
	
				ELSIF (l_record.typname = 'macaddr') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal('08:00:2b:01:02:03')
							|| ');';
	
				ELSIF (l_record.typname = 'tsquery') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal('fat & rat')
							|| ');';
	
				ELSIF (l_record.typname = 'tsvector') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal('a fat cat sat on a mat and ate a fat rat')
							|| ');';
	
				ELSIF (l_record.typname = 'uuid') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11')
							|| ');';
	
				ELSIF (l_record.typname = 'xml') THEN
					l_sql := 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal('<foo>bar</foo>')
							|| ');';
	
				END IF;
	
			ELSIF (l_record.typcategory = 'V') THEN
				IF (l_record.typname = 'bit') THEN
					l_sql := l_sql
							|| 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal(B'0')
							|| ');';
	
				ELSIF (l_record.typname = 'varbit') THEN
					l_sql := l_sql
							|| 'INSERT INTO '
							|| l_record.typname
							|| ' (col1) '
							|| ' VALUES ('
							|| quote_literal(B'101')
							|| ');';
				END IF;
	
			END IF;
	
			BEGIN
				RAISE NOTICE 'CATEGORY: % NAME: %', l_record.typcategory, l_record.typname;
				RAISE NOTICE 'SQL: %', l_sql;
				EXECUTE l_sql;
			EXCEPTION
				WHEN data_exception THEN
					RAISE NOTICE 'Insert into table "%" failed', l_record.typname;
					RAISE NOTICE 'Here is the SQL: %', l_sql;
					RAISE NOTICE 'Continuing.';
			END;
		END LOOP;
		RETURN;
	END;
	\$\$
	;

	----------------------------------------------------------------------
	--	Execute the function.
	----------------------------------------------------------------------
	SELECT table_per_type();

	----------------------------------------------------------------------
	--	Drop the function.
	----------------------------------------------------------------------
	DROP FUNCTION IF EXISTS table_per_type();
EndOfSql

#------------------------------------------------------------------------------
#	Create the tables.
#------------------------------------------------------------------------------
write_log "PostgreSQL Version: ${PG_VERSION}, Environment '${PG_ENV}'"
write_log "Creating tables."

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
