#!/bin/bash

set -e # Exit in case of any error

err_report() {
    echo "$2 -> Error on line $1 with $3"
}
trap 'err_report $LINENO ${BASH_SOURCE[$i]} ${BASH_COMMAND}' ERR


cat << EOF | tee -a /stratio_volume/certs_restore_nginx-qa.list > /dev/null
nginx-qa    | "DNS:nginx-qa.marathon.mesos" | client-server | userland/certificates/nginx-qa
nginx-qa | "DNS:nginx-qa.labs.stratio.com" | client-server | userland/certificates/nginx-qa
EOF

VAULT_TOKEN=$(grep -Po '"root_token":\s*"(\d*?,|.*?[^\\]")' /stratio_volume/vault_response | awk -F":" '{print $2}' | sed -e 's/^\s*"//' -e 's/"$//')
INTERNAL_DOMAIN=$(grep -Po '"internalDomain":\s"(\d*?,|.*?[^\\]")' /stratio_volume/descriptor.json | awk -F":" '{print $2}' | sed -e 's/^\s"//' -e 's/"$//')
CONSUL_DATACENTER=$(grep -Po '"consulDatacenter":\s"(\d*?,|.*?[^\\]")' /stratio_volume/descriptor.json | awk -F":" '{print $2}' | sed -e 's/^\s"//' -e 's/"$//')

PARAMS=""
if [ -f "/stratio_volume/certificates_additional_data" ]; then
    PASSWORD=$(awk -F '"' '/^pki_password/{print $2}' /stratio_volume/certificates_additional_data)
    if [[ "$PASSWORD" ]]; then
        echo "QA - Get CA password"
        PARAMS="-p $PASSWORD"
    fi
fi

cd /stratio/*secret-utils/
bash -e gencerts -l /stratio_volume/certs_restore_nginx-qa.list -w -v vault.service.$INTERNAL_DOMAIN -o 8200 -t $VAULT_TOKEN -d $INTERNAL_DOMAIN -c $CONSUL_DATACENTER $PARAMS