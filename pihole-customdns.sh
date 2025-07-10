#!/bin/bash

# Load environment variables from the .env file
if [ -f .env ]; then
    source .env
else
    echo ".env file not found"
    echo "Please copy the template with 'cp .env.template .env' and fill in your information"
    exit 1
fi

# API Endpoint
API_ENDPOINT="${TRANSPORT}://${PIHOLE_IP}:${PORT}/api"

# authenticate and retrieve session ID
authenticate() {
    local response
    response=$(curl -s -X POST -H "Content-Type: application/json" --data '{"password": "'${PIHOLE_PASSWORD}'"}' ${API_ENDPOINT}/auth)
    
    SID=$(echo "$response" | jq -r '.session.sid')
    
    if [ -z "$SID" ] || [ "$SID" == "null" ]; then
        echo "Error: Authentication failed."
        exit 1
    fi
}

# deauthenticate
deauthenticate() {
    curl -X DELETE -H "Content-Type: application/json" --data '{"sid": "'${SID}'"}' ${API_ENDPOINT}/auth
}

# make API requests
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    response=$(curl -s -X $method -H "Content-Type: application/json" --data '{"sid": "'${SID}'"}' $data "${API_ENDPOINT}${endpoint}")

    echo $endpoint
    echo "$response"
}

log_message() {
    local message=$1
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message"
}

print_help() {
    echo ""
    echo "Usage: $0 [--add [--overwrite]] | [--remove] | [--get] <domain> <ip_address>"
    echo "  --add           Add a custom DNS entry (default action if no flag provided)"
    echo "  --overwrite     Overwrite an existing entry if the IP doesn't match"
    echo "  --remove        Remove a custom DNS entry"
    echo "  --get           List all existing custom DNS entries"
    echo "  <domain>        Domain name for the custom DNS entry"
    echo "  <ip_address>    IP address for the custom DNS entry"
    echo ""
    echo "Examples:"
    echo "  $0 --add example.com 192.168.1.100"
    echo "  $0 --add --overwrite example.com 192.168.1.200"
    echo "  $0 --remove example.com 192.168.1.200"
    echo "  $0 --get"
    exit 0
}

# Parse command-line arguments
OVERWRITE=false
ADD_FLAG=false
REMOVE_FLAG=false
GET_FLAG=false
DOMAIN=""
IP_ADDRESS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --add)
            ADD_FLAG=true
            shift
            ;;
        --overwrite)
            OVERWRITE=true
            shift
            ;;
        --remove)
            REMOVE_FLAG=true
            shift
            ;;
        --get)
            GET_FLAG=true
            shift
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            if [ -z "$DOMAIN" ]; then
                DOMAIN="$1"
            elif [ -z "$IP_ADDRESS" ]; then
                IP_ADDRESS="$1"
            else
                echo "Unknown argument: $1"
                print_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ "$ADD_FLAG" = true ] && [ "$REMOVE_FLAG" = true ]; then
    echo "ERROR: --add and --remove cannot be used together."
    print_help
    exit 1
fi

authenticate

if [ "$GET_FLAG" = true ]; then
    log_message "Fetching existing custom DNS entries..."
    response_body=$(api_request "GET" "/config/dns/hosts/")
    echo $response_body
    # echo $response_body | jq .
    deauthenticate
    exit 0
fi

if [ "$ADD_FLAG" = true ]; then
    log_message "Adding custom DNS entry: $DOMAIN -> $IP_ADDRESS"
    response_body=$(api_request "PUT" "/config/dns/hosts/${IP_ADDRESS}%20${DOMAIN}")
    echo "$response_body"
    deauthenticate
    exit 0
fi

if [ "$REMOVE_FLAG" = true ]; then
    log_message "Removing custom DNS entry: $DOMAIN -> $IP_ADDRESS"
    response_body=$(api_request "DELETE" "/config/dns/hosts/${IP_ADDRESS}%20${DOMAIN}")
    echo "$response_body"
    deauthenticate
    exit 0
fi

log_message "No valid operation specified. Use --help for usage details."
deauthenticate
exit 1
