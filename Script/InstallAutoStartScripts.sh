#!/bin/sh
#------------------------------------------------------------------------------
#	Install autostart/stop scripts for PostgreSQL.
#	Assumes that GenerateAutoStartScriptAll.sh has been run to create the
#	files in /tmp
#------------------------------------------------------------------------------
List91="
	postgresql-9.1-ConfigSansDataPrimary
	postgresql-9.1-LinkedConfigPrimary
	postgresql-9.1-NoDefaultDatabasesPrimary
	postgresql-9.1-NoPostgresRolePrimary
	postgresql-9.1-NotOwnedByPostgresPrimary
	postgresql-9.1-StandalonePrimary
	postgresql-9.1-WALshippingHotPrimary
	postgresql-9.1-WALshippingHotSecondary
	postgresql-9.1-WALshippingHotStreamingPrimary
	postgresql-9.1-WALshippingHotStreamingSecondary
	postgresql-9.1-WALshippingPrimary
	postgresql-9.1-WALshippingSecondary
	"
List92="
	postgresql-9.2-CascadingPrimary
	postgresql-9.2-CascadingSecondary
	postgresql-9.2-CascadingTertiary
	postgresql-9.2-ConfigSansDataPrimary
	postgresql-9.2-LinkedConfigPrimary
	postgresql-9.2-NoDefaultDatabasesPrimary
	postgresql-9.2-NoPostgresRolePrimary
	postgresql-9.2-NotOwnedByPostgresPrimary
	postgresql-9.2-OffTheShelfPrimary
	postgresql-9.2-ReceiveXlogPrimary
	postgresql-9.2-ReceiveXlogSecondary
	postgresql-9.2-StandalonePrimary
	postgresql-9.2-WALshippingHotPrimary
	postgresql-9.2-WALshippingHotSecondary
	postgresql-9.2-WALshippingHotStreamingPrimary
	postgresql-9.2-WALshippingHotStreamingSecondary
	postgresql-9.2-WALshippingPrimary
	postgresql-9.2-WALshippingSecondary
	"
List93="
	postgresql-9.3-CascadingPrimary
	postgresql-9.3-CascadingSecondary
	postgresql-9.3-CascadingTertiary
	postgresql-9.3-ConfigSansDataPrimary
	postgresql-9.3-LinkedConfigPrimary
	postgresql-9.3-NoDefaultDatabasesPrimary
	postgresql-9.3-NoPostgresRolePrimary
	postgresql-9.3-NotOwnedByPostgresPrimary
	postgresql-9.3-ReceiveXlogPrimary
	postgresql-9.3-ReceiveXlogSecondary
	postgresql-9.3-StandalonePrimary
	postgresql-9.3-WALshippingHotPrimary
	postgresql-9.3-WALshippingHotSecondary
	postgresql-9.3-WALshippingHotStreamingPrimary
	postgresql-9.3-WALshippingHotStreamingSecondary
	postgresql-9.3-WALshippingPrimary
	postgresql-9.3-WALshippingSecondary
	"

cd /etc/init.d

for file in ${List92} ${List93}
do
	echo "Processing ${file}"
	cp /tmp/${file} .
	chmod 744 ${file}
	chkconfig --add ${file}
	chkconfig ${file} on
	chkconfig --list ${file}
done
