wait_for_all_service_containers()
{
    META_URL="${1:-http://rancher-metadata/2015-07-25}"
    SET_SCALE=$(curl -s -H 'Accept: application/json' ${META_URL}/self/service| jq -r .scale)
    while [ "$(curl -s -H 'Accept: application/json' ${META_URL}/self/service|jq '.containers |length')" -lt "${SET_SCALE}" ]; do
        sleep 1
    done    
}
