#!/bin/bash

source ./lib/autority.sh
clear

# Define certificate details as variables
CERT_CN="localhost"
CERT_OU="MyOrganizationUnit"
CERT_O="MyOrganization"
CERT_L="MyCity"
CERT_S="MyState"
CERT_C="US"

# Define passwords
STOREPASS="secret"
KEYPASS="secret"

# Create Distinguished Name string
DNAME="CN=$CERT_CN, OU=$CERT_OU, O=$CERT_O, L=$CERT_L, S=$CERT_S, C=$CERT_C"

echo "=== CERTIFICATE GENERATOR FOR KAFKA ==="
read -p "Press any key to continue..."
echo

AU_KEY=root.key
AU_CRT=root.crt

if [ -f "$AU_KEY" ] && [ -f "$AU_CRT" ]; then
    echo "Authority available"
else
    echo "Authority not available"
    while true; do
        read -p "Generate new CA? (y/n): " yn
        case $yn in
            [Yy]* ) creaCertAU; break;;
            [Nn]* ) echo "Bye! :)"; exit;;
        esac
    done
fi

# 1. Generate Truststore
echo "Generating Truststore..."
keytool -keystore kafka.truststore.jks -alias CARoot -import -file root.crt -storepass "$STOREPASS" -noprompt

# 2. Generate Keystore
echo "Generating Keystore..."
keytool -keystore kafka01.keystore.jks -alias kafka-broker -validity 365 -genkey -keyalg RSA -storepass "$STOREPASS" -keypass "$KEYPASS" \
  -dname "$DNAME" -ext SAN=DNS:$CERT_CN -noprompt

# 3. Export Certificate Request
echo "Exporting Certificate Request..."
keytool -keystore kafka01.keystore.jks -alias kafka-broker -certreq -file kafka01.unsigned.crt -storepass "$STOREPASS" -noprompt

# 4. Sign the Certificate
echo "Signing Certificate..."
openssl x509 -req -CA root.crt -CAkey root.key -in kafka01.unsigned.crt -out kafka01.signed.crt -days 365 -CAcreateserial

# 5. Import CA into Keystore
echo "Importing CA into Keystore..."
keytool -keystore kafka01.keystore.jks -alias CARoot -import -file root.crt -storepass "$STOREPASS" -noprompt

# 6. Import Signed Certificate into Keystore
echo "Importing Signed Certificate into Keystore..."
keytool -keystore kafka01.keystore.jks -alias kafka-broker -import -file kafka01.signed.crt -storepass "$STOREPASS" -noprompt

echo "=== END ==="
echo "Use \"kafka.truststore.jks\" and \"kafka01.keystore.jks\" with password \"$STOREPASS\" to connect to the Broker."
echo
read -p "Press any key to close..."
exit

