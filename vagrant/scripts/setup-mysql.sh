#!/bin/bash

source "/vagrant/scripts/common.sh" || source "/home/vagrant/vagrant-scripts/common.sh"

function installMysql {
	echo "install mysql server"
	export DEBIAN_FRONTEND=noninteractive
	echo debconf mysql-server/root_password password $MYSQL_ROOT_PASSWORD | debconf-set-selections
	echo debconf mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD | debconf-set-selections
	apt-get update
	apt-get -qq install mysql-server 
	apt-get -qq install expect 
	tee ~/mysql.sh << EOF
	spawn $(which mysql_secure_installation)
	expect "Enter password for user root:"
	send "$MYSQL_ROOT_PASSWORD\r"
	expect "Press y|Y for Yes, any other key for No:"
	send "n\r"
	expect "Change the password for root ? ((Press y|Y for Yes, any other key for No) :"
	send "y\r"
	expect "New password:"
	send "$MYSQL_ROOT_PASSWORD\r"
	expect "Re-enter new password:\r"
	send "$MYSQL_ROOT_PASSWORD\r"
	expect -re "Remove anonymous users.*"
	send "n\r"
	expect -re "Disallow root login remotely.*"
	send "n\r"
	expect -re "Remove test database and access to it.*"
	send "n\r"
	expect "eload privilege tables now.*"
	send "n\r"
EOF
	expect ~/mysql.sh
	echo "Finished mysql server install"
}

function setupMysql {
	echo "Edit mysqld.cnf..."
	cp -f /vagrant/resources/mysql/$MYSQL_CONF ${MYSQL_CONF_DIR}
	# Allow root access from host
	echo "Allow root access from network..."
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" | mysql -u root -P 3306 -p${MYSQL_ROOT_PASSWORD}
    echo "Create hive_metastore schema..."
	echo "CREATE SCHEMA hive_metastore;" | mysql -u root -P 3306 -p${MYSQL_ROOT_PASSWORD}
	echo "Create hive meta-db user..."
	echo "CREATE USER 'hive'@'%' IDENTIFIED BY 'hive';" | mysql -u root -P 3306 -p${MYSQL_ROOT_PASSWORD}
	echo "grant permissions to hive meta-db user..."
	echo "GRANT ALL PRIVILEGES ON hive_metastore.* TO 'hive'@'%' IDENTIFIED BY 'hive';" | mysql -u root -P 3306 -p${MYSQL_ROOT_PASSWORD}
	echo "Create airflow_mdb schema..."	
    echo "CREATE SCHEMA airflow_mdb;" | mysql -u root -P 3306 -p${MYSQL_ROOT_PASSWORD}
    echo "Create airflow user..."
    echo "CREATE USER 'airflow'@'%' IDENTIFIED BY 'airflow';" | mysql -u root -P 3306 -p${MYSQL_ROOT_PASSWORD}
    echo "grant permissions to airflow user..."
	echo "GRANT ALL PRIVILEGES ON airflow_mdb.* TO 'airflow'@'%' IDENTIFIED BY 'airflow';" | mysql -u root -P 3306 -p${MYSQL_ROOT_PASSWORD}
    echo "Create tables for airflow_mdb..."
    mysql -u airflow -P 3306 -p${MYSQL_AIRFLOW_PASSWORD} -D airflow_mdb < /home/vagrant/airflow-materials/data-pipelines/mysql_table_tasks.sql 
    mysql -u airflow -P 3306 -p${MYSQL_AIRFLOW_PASSWORD} -D airflow_mdb < /home/vagrant/airflow-materials/data-pipelines/mysql_table_sources.sql 
    	echo "SET GLOBAL explicit_defaults_for_timestamp = 1;" | mysql -u root -P 3306 -p${MYSQL_ROOT_PASSWORD}
    echo "Restarting mysqld for changes to take effect..."
#	systemctl restart mysql.service
	service mysql restart
	echo "setup of mysql finished"
}

echo "setup mysql"
installMysql
setupMysql
