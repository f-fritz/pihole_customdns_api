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
API_ENDPOINT="${TRANSPORT}://${PIHOLE_IP}:${PORT}/admin/api.php"
ACTION_GET="get"
ACTION_ADD="add"
ACTION_DELETE="delete"

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <domain> <ip_address>"
    exit 1
fi

DOMAIN="$1"
IP_ADDRESS="$2"

# Function to make API requests
api_request() {
    local action=$1
    local response
    response=$(curl -s -w "%{http_code}" -o /tmp/pihole_api_response.json "${API_ENDPOINT}?customdns&auth=${API_TOKEN}&action=${action}")
    if [ "$response" -ne 200 ]; then
        echo "API request failed with HTTP status $response."
        exit 1
    fi
    cat /tmp/pihole_api_response.json
}

# Function to log messages with timestamps
log_message() {
    local message=$1
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message"
}

# Retrieve current custom DNS entries
response=$(api_request "${ACTION_GET}")
log_message "Response from get request: $response"

# Parse the response to find the domain and IP
current_entries=$(echo "$response" | jq -c '.data[]')
entry_exists=false

for entry in $current_entries; do
    existing_domain=$(echo "$entry" | jq -r '.[0]')
    existing_ip=$(echo "$entry" | jq -r '.[1]')
    
    if [ "$existing_domain" == "$DOMAIN" ]; then
        entry_exists=true
        if [ "$existing_ip" == "$IP_ADDRESS" ]; then
            log_message "Custom DNS entry for ${DOMAIN} already exists with the correct IP address."
            exit 0
        else
            log_message "Custom DNS entry for ${DOMAIN} exists but with a different IP address. Updating..."
            # Delete the existing entry
            delete_response=$(api_request "${ACTION_DELETE}&domain=${DOMAIN}&ip=${existing_ip}")
            log_message "Response from delete request: $delete_response"
            
            if echo "$delete_response" | grep -q '"success":true'; then
                log_message "Existing entry deleted successfully."
            else
                log_message "Failed to delete existing entry."
                exit 1
            fi
        fi
        break
    fi
done

if [ "$entry_exists" = false ]; then
    log_message "No existing entry for ${DOMAIN}. Adding new entry..."
fi

# Add the new entry
add_response=$(api_request "${ACTION_ADD}&domain=${DOMAIN}&ip=${IP_ADDRESS}")
log_message "Response from add request: $add_response"

if echo "$add_response" | grep -q '"success":true'; then
    log_message "Custom DNS entry added successfully."
else
    log_message "Failed to add new custom DNS entry."
    exit 1
fi