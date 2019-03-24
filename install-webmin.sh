#!/bin/bash

yum -y update
yum -y install wget
wget http://prdownloads.sourceforge.net/webadmin/webmin-1.900-1.noarch.rpm
yum -y install perl perl-Net-SSLeay openssl perl-IO-Tty
rpm -U webmin-1.900-1.noarch.rpm

firewall-cmd --zone=public --add-port=10000/tcp --permanent
firewall-cmd --reload

service webmin start
chkconfig webmin on
