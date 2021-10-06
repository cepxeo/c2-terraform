#!/bin/bash

domain="<DOMAIN>"
domainPkcs="$domain.p12"
domainStore="$domain.store"
password="0nlym3allowed"

c2_server_ip="<COBALT_SERVER_IP>"

func_config_nignx() {
  sudo sed -i "s/<DOMAIN_NAME>/$domain/" /etc/nginx/sites-enabled/default
  sudo sed -i "s/<C2_SERVER>/$c2_server_ip/" /etc/nginx/sites-enabled/default
}

func_build_pkcs(){
  cd /etc/letsencrypt/live/$domain
  echo '[Starting] Building PKCS12 .p12 cert.'
  openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out $domainPkcs -name $domain -passout pass:$password
  echo '[Success] Built $domainPkcs PKCS12 cert.'
  echo '[Starting] Building Java keystore via keytool.'
  keytool -importkeystore -deststorepass $password -destkeypass $password -destkeystore $domainStore -srckeystore $domainPkcs -srcstoretype PKCS12 -srcstorepass $password -alias $domain
  echo '[Success] Java keystore $domainStore built.'
  cp $domainStore /tmp/
}

echo '[Starting] Obtaining LetsEncrypt certificate.'
sudo certbot certonly --non-interactive --quiet --register-unsafely-without-email --agree-tos -a webroot --webroot-path=/var/www/html -d $domain

func_config_nignx

sudo apt -y install default-jre
func_build_pkcs
