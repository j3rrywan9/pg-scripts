#!/bin/sh
#------------------------------------------------------------------------------
#	Install autostart/stop scripts for EnterpriseDB.
#	Assumes that EdbGenerateAutoStartScriptAll.sh has been run to create the
#	files in /tmp
#------------------------------------------------------------------------------
List92="
	ppas-9.2AS-CascadingPrimary
	ppas-9.2AS-CascadingSecondary
	ppas-9.2AS-CascadingTertiary
	ppas-9.2AS-ConfigSansDataPrimary
	ppas-9.2AS-LinkedConfigPrimary
	ppas-9.2AS-NoDefaultDatabasesPrimary
	ppas-9.2AS-NoPostgresRolePrimary
	ppas-9.2AS-NotOwnedByPostgresPrimary
	ppas-9.2AS-OffTheShelfPrimary
	ppas-9.2AS-ReceiveXlogPrimary
	ppas-9.2AS-ReceiveXlogSecondary
	ppas-9.2AS-StandalonePrimary
	ppas-9.2AS-WALshippingHotPrimary
	ppas-9.2AS-WALshippingHotSecondary
	ppas-9.2AS-WALshippingHotStreamingPrimary
	ppas-9.2AS-WALshippingHotStreamingSecondary
	ppas-9.2AS-WALshippingPrimary
	ppas-9.2AS-WALshippingSecondary
	"

cd /etc/init.d

for file in ${List92}
do
	echo "Processing ${file}"
	cp /tmp/${file} .
	chmod 744 ${file}
	chkconfig --add ${file}
	chkconfig ${file} on
	chkconfig --list ${file}
done
