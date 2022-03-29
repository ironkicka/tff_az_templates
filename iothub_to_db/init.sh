#!/bin/bash
sudo apt-get update
sudo apt-get -y install mysql-client
cd /home/azureuser && wget --no-check-certificate https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem
