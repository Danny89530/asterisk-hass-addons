#!/usr/bin/with-contenv bashio

bashio::log.info "Creating certificate..."

# REPLACE WITH CERTBOT
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=NL/ST=Denial/L=Amsterdam/O=Dis/CN=Asterisk" \
    -keyout /etc/asterisk/keys/asterisk.key  -out /etc/asterisk/keys/asterisk.cert > /dev/null

bashio::log.info "Configuring Asterisk"

sed -i 's/noload => chan_sip.so/;noload => chan_sip.so/' /etc/asterisk/modules.conf > /dev/null

echo '
    [general]
    enabled=yes
    bindaddr=0.0.0.0
    bindport=8088
    tlsenable=yes
    tlsbindaddr=0.0.0.0:8089
    tlscertfile=/etc/asterisk/keys/asterisk.cert
    tlsprivatekey=/etc/asterisk/keys/asterisk.key
' > '/etc/asterisk/http.conf'

echo $'
    [general]
    realm=127.0.0.1 ; Replace this with your IP address
    udpbindaddr=127.0.0.1 ; Replace this with your IP address
    transport=udp
    context=default
    
    [sipjs-phone](!)
    type=friend
    host=dynamic ; Allows any host to register
    encryption=yes ; Tell Asterisk to use encryption for this peer
    avpf=yes ; Tell Asterisk to use AVPF for this peer
    icesupport=yes ; Tell Asterisk to use ICE for this peer
    context=default ; Tell Asterisk which context to use when this peer is dialing
    directmedia=no ; Asterisk will relay media for this peer
    transport=wss,ws,udp,tls ; Asterisk will allow this peer to register on UDP or WebSockets
    force_avp=yes ; Force Asterisk to use avp. Introduced in Asterisk 11.11
    dtlsenable=yes ; Tell Asterisk to enable DTLS for this peer
    dtlsverify=fingerprint ; Tell Asterisk to verify DTLS fingerprint
    dtlscertfile=/etc/asterisk/keys/asterisk.cert ; Tell Asterisk where your DTLS cert file is
    dtlssetup=actpass ; Tell Asterisk to use actpass SDP parameter when setting up DTLS
    rtcp_mux=yes ; Tell Asterisk to do RTCP mux
    dtmfmode=rfc2833
    
    [my-codecs](!)
    allow=!all,ulaw,alaw,speex,gsm,g726,g723\n
    \n
' > '/etc/asterisk/sip.conf'

echo "" > '/etc/asterisk/pjsip.conf'

PERSONS=$(curl -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/core/api/states | jq -r '.[] | select(.entity_id | contains("person.")).attributes.id')
AUTO_ADD=$(bashio::config 'auto_add')

if $AUTO_ADD; then
    EXTENSION=100
    for person in ${PERSONS}
    do
    EXTENSION=$((${EXTENSION}+1))
    echo "
    [${EXTENSION}](sipjs-phone,my-codecs)
    username=${person}
    secret=1234
    " >> '/etc/asterisk/sip.conf'
    done
fi

for extension in $(bashio::config 'custom_extensions|keys')
do
    EXTENSION=$(bashio::config "custom_extensions[${extension}].extension")
    SECRET=$(bashio::config "custom_extensions[${extension}].secret")
    CONFIG=$(bashio::config "custom_extensions[${extension}].configuration")
    TYPE=$(bashio::config "custom_extensions[${extension}].type")
    NAME=$(bashio::config "custom_extensions[${extension}].name")

    if [ "${TYPE}" = "chan_sip" ]; then
    echo "
    [${EXTENSION}]
    username=${NAME}
    secret=${SECRET}
    ${CONFIG}
    " >> '/etc/asterisk/sip.conf'
    else
    echo "
    [${EXTENSION}]
    username=${NAME}
    ${CONFIG}
    " >> '/etc/asterisk/pjsip.conf'
    fi
done

bashio::log.info "pjsip.conf:"
cat /etc/asterisk/pjsip.conf

bashio::log.info "sip.conf:"
cat /etc/asterisk/sip.conf

bashio::log.info "Starting Asterisk:"

asterisk -vvvv -ddd

sleep 5

while true
do
    echo " "
    bashio::log.info $(asterisk -x "sip show peers")
    sleep 5
    echo " "
    bashio::log.info $(asterisk -x "http show status")
    sleep 5
    echo " "
    if $AUTO_ADD; then
        EXTENSION=100
        for person in ${PERSONS}
        do
            EXTENSION=$((${EXTENSION}+1))
            if asterisk -x "sip show peers" | grep "${EXTENSION}" | grep '(Unspecified)'; then
                STATE='off'
            else
                STATE='on'
            fi
            curl -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" -d '{"state": "'"${STATE}"'", "attributes": {"extension": "'"${EXTENSION}"'", "secret": "1234", "user": "'"${person}"'"}}' "http://supervisor/core/api/states/binary_sensor.sip_${person}" > /dev/null
        done
    fi

    for extension in $(bashio::config 'custom_extensions|keys')
    do
        EXTENSION=$(bashio::config "custom_extensions[${extension}].extension")
        SECRET=$(bashio::config "custom_extensions[${extension}].secret")
        NAME=$(bashio::config "custom_extensions[${extension}].name")
        TYPE=$(bashio::config "custom_extensions[${extension}].type")
        if [ "${TYPE}" = "chan_sip" ]; then
            if asterisk -x "sip show peers" | grep "${EXTENSION}" | grep '(Unspecified)'; then
                STATE='off'
            else
                STATE='on'
            fi
        else
            if asterisk -x "pjsip show endpoints" | grep "${EXTENSION}" | grep '(Unspecified)'; then
                STATE='off'
            else
                STATE='on'
            fi
        fi
        curl -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" -d '{"state": "'"${STATE}"'", "attributes": {"extension": "'"${EXTENSION}"'", "secret": "'"${SECRET}"'", "user": "'"${NAME}"'"}}' "http://supervisor/core/api/states/binary_sensor.sip_${NAME}" > /dev/null
    done
done