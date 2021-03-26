#!/usr/bin/env bash

set -e

# Generate Root CA
generate_root_ca() {
  name="${1}"

  local subject="/C=SE/ST=Stockholm/L=Stockholm/O=Proxy/OU=CA/CN=RootCA"

  openssl req \
    -x509 \
    -sha256 \
    -nodes \
    -newkey rsa:2048 \
    -subj "${subject}" \
    -days 365 \
    -extensions v3_ca \
    -keyout "${name}.key" \
    -out "${name}.crt"
}

# Generate CSR
generate_csr() {
  name="${1}"

  local subject="/C=SE/ST=Stockholm/L=Stockholm/O=Proxy/OU=${name}/CN=localhost"

  openssl req \
    -new \
    -sha256 \
    -nodes \
    -subj "${subject}" \
    -keyout "${name}.key" \
    -out "${name}.csr"
}

# Sign the cert
sign_cert() {
  csr="${1}"
  root_cert="${2}"
  root_key="${3}"

  openssl x509 \
    -req \
    -sha256 \
    -in "${csr}" \
    -CA "${root_cert}" \
    -CAkey "${root_key}" \
    -CAcreateserial \
    -days 365 \
    -out "${csr/.csr/.crt}"

  rm server.csr
}

cert_path="conf/certs"
secrets_path="../secrets"
password="mysupersecretpassword"

pushd "${cert_path}" || exit 1

generate_root_ca "rootca"
generate_csr "server"
sign_cert "server.csr" "rootca.crt" "rootca.key"

# remove the trust- and keystores
(cd "${secrets_path}" && rm -f ./*.jks)

# Store the root CA in the client truststore, this truststore is imported by whatever (java based) client being used.
keytool -keystore kafka.client.truststore.jks -alias RootCA -importcert -file rootca.crt -storepass "${password}" -keypass "${password}" -noprompt

# Store the root CA in the broker truststore, this truststore is passed to the broker via config
keytool -keystore kafka.server.truststore.jks -alias RootCA -importcert -file rootca.crt -storepass "${password}" -keypass "${password}" -noprompt

# Generate a key pair for the broker (alias localhost)
keytool -keystore kafka.server.keystore.jks -alias localhost -keyalg RSA -keysize 2048 -validity 365 -genkeypair -storepass "${password}" -keypass "${password}" -dname "c=SE, st=Stockholm, l=Stockholm, o=Proxy, ou=broker, cn=localhost"

# Generate a certificate request for the broker (alias localhost)
keytool -keystore kafka.server.keystore.jks -alias localhost -certreq -file broker.csr -storepass "${password}" -keypass "${password}"

# Sign the broker certificate with the root CA
openssl x509 -req -sha256 -CA rootca.crt -CAkey rootca.key -in broker.csr -out broker.crt -days 365 -CAcreateserial -passin pass:"${password}"

rm broker.csr

# Store the root CA certificate and the broker certificate in the broker keystore
keytool -keystore kafka.server.keystore.jks -alias RootCA -importcert -file rootca.crt -storepass "${password}" -keypass "${password}" -noprompt
keytool -keystore kafka.server.keystore.jks -alias localhost -importcert -file broker.crt -storepass "${password}" -keypass "${password}" -noprompt

# Create the password file
echo "${password}" > kafka_password_file

# Move the stores and password file to the correct directory
mv ./*.jks kafka_password_file "${secrets_path}"

popd || exit 1
