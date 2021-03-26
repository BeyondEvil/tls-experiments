# TLS Experiments

The code in this repo will setup TLS _encryption_ **not** mTLS (mutual authentication)

To test the MQTT broker you can use [MQTT.fx](https://softblade.de/en/mqtt-fx/)

To test Kafka you can use [Conduktor](https://www.conduktor.io/)

To use TLS with the MQTT broker the broker needs a root CA and a certificate and key. The client then needs to have access to the same root CA.

To use TLS with Kafka, the broker needs to have the root CA stored in its _truststore_. Furthermore, it needs both the root CA and its own (signed) cert stored in its _keystore_.

The broker then also needs the trust- and keystore passwords.

The client needs to have the root CA stored in its _truststore_ including the password to the store.
