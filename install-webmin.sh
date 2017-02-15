#!/bin/bash

touch /etc/apt/sources.list.d/webmin.list
echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list.d/webmin.list
echo "http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list.d/webmin.list