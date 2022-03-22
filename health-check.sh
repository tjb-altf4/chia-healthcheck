#!/bin/bash

# define services to check (appname|servicename)
readonly blockchains=(
    "chia|chia-blockchain"
    "chives|chives-blockchain"
    "cactus|cactus-blockchain"
    "hddcoin|hddcoin-blockchain"
    "flax|flax-blockchain"
    "staicoin|staicoin-blockchain"
    "flora|flora-blockchain"
    "stor|stor-blockchain"
    # "greendoge|greendoge-blockchain"
    # "cryptodoge|cryptodoge-blockchain"
    # "ethgreen|ethgreen-blockchain'
    # "maize|maize-blockchain'
    # "aedge|aedge-blockchain'
    "shibgreen|shibgreen-blockchain"
    "tranzact|tranzact-blockchain"
    # "|skynet-blockchain'
    # "|mint-blockchain'
    # "|btcgreen-blockchain"
    "venidium|venidium-blockchain"
    # "|wheat-blockchain"
    "rolls|pecanrolls-blockchain"
)

function check_health() {
	echo "$(date +%FT%T)"
	
    local blockchain service
	for all in ${blockchains[@]}
	do
        # initialise new check
        IFS=$'|' read -r blockchain service <<< "$all"
        error=0

        # check if service has been created
        if [ "$(docker ps -a | grep ${service})" ]; then
            echo "$(date +%FT%T)   INFO: ${service} service exists"   

            # check if service is running
            if [ "$( docker container inspect -f '{{.State.Status}}' "${service}" )" == "running" ]; then
                echo "$(date +%FT%T)   INFO: ${service} service is running"   
            else
                echo "$(date +%FT%T)   WARN: ${service} service is NOT running"
                error=1
            fi
        
            # check if service status is available
            if ((!error)); then
                if  [[ "$(docker exec ${service} ${blockchain} show -s)" =~ "Current Blockchain Status" ]]; then
                    echo "$(date +%FT%T)   INFO: ${service} full-node is healthy"
                else                     
                    dateStarted=$(date +%s -d $(docker inspect -f '{{ .State.StartedAt }}' ${service}))
                    dateNow=$(date +%s)
                    let runtime=($dateNow-$dateStarted)/60

                    if [ $runtime -lt 15 ]; then
                        echo "$(date +%FT%T)   INFO: ${service} service is still starting up, deferring check"
                    else                 
                        echo "$(date +%FT%T)   WARN: ${service} full-node is NOT healthy"
                        error=1
                    fi
                fi
            fi

            # restart service if error found
            if ((error)); then
                echo "$(date +%FT%T)   INFO: ${service} service is being restarted..."
                docker restart ${service} --time 15
                /usr/local/emhttp/webGui/scripts/notify -e "Farming Healthcheck" -s "${service} was found in a degraded state" -d "${service} service is being restarted..."  -i "warning"
            fi            
        else 
            echo "$(date +%FT%T)  ERROR: ${service} service does not exist"
            /usr/local/emhttp/webGui/scripts/notify -e "Farming Healthcheck" -s "${service} service does not exist" -d "Please check configuration"  -i "alert"
        fi
    done
    echo "$(date +%FT%T)"
}

# check if appdata backup/restore is running
startup_error=0
app_backup=/tmp/ca.backup2/tempFiles/backupInProgress
app_restore=/tmp/ca.backup2/tempFiles/restoreInProgress

if [ -f ${app_backup} ] || [ -f ${app_restore} ]; then
    echo "$(date +%FT%T)   INFO: appdata backup/restore is running, skipping check!"
    startup_error=1
fi

# check if docker system service is running 
if  [[  "$(docker -v)" =~ "Docker version" ]]; then
    echo "$(date +%FT%T)   INFO: Docker service is running"    
else
    echo "$(date +%FT%T)  ERROR: Docker service is not running"
    startup_error=1
    /usr/local/emhttp/webGui/scripts/notify -e "Farming Healthcheck" -s "Docker service is not running" -d "Please check docker service in console"  -i "alert"
fi

# start health check if no startup errors found
if ((!startup_error)); then
    echo; echo "$(date +%FT%T)   INFO: starting healthcheck..."
    check_health
    echo "$(date +%FT%T)   INFO: healthcheck complete"; echo
fi
