#! /bin/bash

# TODO: improve initial puppet run

KEYSTONE_DBNAME=keystone
KEYSTONE_DBUSER=keystone
KEYSTONE_DBPASS=SECRET

GLANCE_DBNAME=glance
GLANCE_DBUSER=glancedbadmin
GLANCE_DBPASS=SECRET

NOVA_DBNAME=nova
NOVA_DBUSER=novadbadmin
NOVA_DBPASS=SECRET

reset_db() {
	dbname=$1
	dbuser=$2
	dbpass=$3

	echo "Creating DB:$dbname, user:$dbuser, pass:$dbpass"
	mysql -u root <<EOF
DROP DATABASE IF EXISTS $dbname;
CREATE DATABASE $dbname;
GRANT ALL ON $dbname.* TO '$dbuser'@'%' IDENTIFIED BY '$dbpass';
GRANT ALL ON $dbname.* TO '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';
FLUSH PRIVILEGES;
EOF
}

reset_db $KEYSTONE_DBNAME $KEYSTONE_DBUSER $KEYSTONE_DBPASS
reset_db $GLANCE_DBNAME $GLANCE_DBUSER $GLANCE_DBPASS
reset_db $NOVA_DBNAME $NOVA_DBUSER $NOVA_DBPASS

echo "Syncing keystone DB"
keystone-manage db_sync

echo "Syncing Nova DB"
nova-manage db sync
