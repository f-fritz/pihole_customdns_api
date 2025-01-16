#!/bin/bash

# Load environment variables from the .env file
if [ -f .env ]; then
    source .env
else
    echo ".env file not found"
    echo "Please copy the template with 'cp .env.template .env' and fill in your information"
    exit 1
fi

# API Endpoint and action lookup
API_ENDPOINT="${TRANSPORT}://${PIHOLE_IP}:${PORT}/admin/api.php"
ACTION_GET="get"
ACTION_ADD="add"
ACTION_DELETE="delete"

# Function to make API requests
api_request() {
    local action=$1
    local domain=$2
    local ip=$3
    local response_body
    local http_status

    # Build query parameters dynamically based on action
    local query="customdns&auth=${API_TOKEN}&action=${action}"
    [ -n "$domain" ] && query="${query}&domain=${domain}"
    [ -n "$ip" ] && query="${query}&ip=${ip}"

    # write response body and http status code to distinct lines
    response=$(curl -s -w "\n%{http_code}" "${API_ENDPOINT}?${query}")
    
    # split body and the status code
    response_body=$(echo "$response" | sed '$ d') # All except the last line
    http_status=$(echo "$response" | tail -n 1)   # The last line

    # Return the values to be used by the calling function
    echo "$response_body"
    return $http_status
}

log_message() {
    local message=$1
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message"
}

print_help() {
    echo ""
    echo "Usage: $0 [--add [--overwrite]] | [--remove] <domain> <ip_address>"
    echo "  --add           Add a custom DNS entry (default action if no flag provided)"
    echo "  --overwrite     Overwrite an existing entry if the IP doesn't match"
    echo "  --remove        Remove a custom DNS entry"
    echo "  <domain>        Domain name for the custom DNS entry"
    echo "  <ip_address>    IP address for the custom DNS entry"
    echo ""
    echo "Examples:"
    echo "  $0 --add example.com 192.168.1.100"
    echo "  $0 --add --overwrite example.com 192.168.1.200"
    echo "  $0 --remove example.com 192.168.1.200"
    exit 0
}

# Parse command-line arguments
OVERWRITE=false
ADD_FLAG=false
REMOVE_FLAG=false
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
        --delete)
            REMOVE_FLAG=true
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

if [ "$REMOVE_FLAG" = false ]; then
    # Default to add
    ACTION="add"
elif [ "$REMOVE_FLAG" = true ]; then
    ACTION="remove"
fi

if [ -z "$DOMAIN" ] || [ -z "$IP_ADDRESS" ]; then
    print_help
    exit 1
fi

# Handle actions
if [ "$ACTION" == "add" ]; then
    # get existing entries
    response_body=$(api_request "${ACTION_GET}")
    http_status=$?

    if [ "$http_status" -ne 200 ]; then
        log_message "ERROR: Failed to fetch existing DNS entries. HTTP Status: $http_status"
        exit 1
    fi

    current_entries=$(echo "$response_body" | jq -c '.data[]')
    entry_exists=false
    entry_matches=false

    for entry in $current_entries; do
        existing_domain=$(echo "$entry" | jq -r '.[0]')
        existing_ip=$(echo "$entry" | jq -r '.[1]')

        if [ "$existing_domain" == "$DOMAIN" ]; then
            entry_exists=true
            if [ "$existing_ip" == "$IP_ADDRESS" ]; then
                entry_matches=true
            fi
            break
        fi
    done

    if [ "$entry_exists" == true ] && [ "$entry_matches" == true ]; then
        log_message "Custom DNS entry for ${DOMAIN} with IP ${IP_ADDRESS} already exists. No action taken."
        exit 0
    fi

    if [ "$entry_exists" == true ] ; then
        if [ "$OVERWRITE" == true ] ; then
            log_message "Custom DNS entry for ${DOMAIN} exists but with a different IP. Overwriting..."
            delete_response=$(api_request "${ACTION_DELETE}" "$DOMAIN" "$existing_ip")
            if echo "$delete_response" | grep -q '"success":true'; then
                log_message "  SUCCESS: Existing entry deleted successfully."
            else
                log_message "  ERROR: Failed to delete existing entry."
                exit 1
            fi
        else # OVERWRITE == false
            log_message "WARNING: Custom DNS entry for ${DOMAIN} exists but with a different IP. Use --overwrite to force an update."
            exit 1
        fi
    fi

    add_response=$(api_request "${ACTION_ADD}" "$DOMAIN" "$IP_ADDRESS")
    if echo "$add_response" | grep -q '"success":true'; then
        log_message "SUCCESS: Custom DNS entry added successfully."
        exit 0
    else
        log_message "ERROR: Failed to add custom DNS entry."
        exit 1
    fi

elif [ "$ACTION" == "remove" ]; then
    delete_response=$(api_request "${ACTION_DELETE}" "$DOMAIN" "$IP_ADDRESS")
    if echo "$delete_response" | grep -q '"success":true'; then
        log_message " SUCCESS: Custom DNS entry for ${DOMAIN} removed successfully."
        exit 0
    else
        log_message "ERROR: Failed to remove custom DNS entry for ${DOMAIN}."
        log_message "  The given IP must match the one from the existing entry."
        exit 1
    fi
fi
