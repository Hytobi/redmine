#!/bin/bash

# Configurations
API_KEY=""
USER_NAME="Your name"
REDMINE_URL="https://redmine.company.com"

print_green() { echo -e "\e[32m$1\e[0m"; }
print_red() { echo -e "\e[31m$1\e[0m"; }
print_yellow() { echo -e "\e[33m$1\e[0m"; }
print_blue() { echo -e "\e[34m$1\e[0m"; }

if [ -z "$API_KEY" ]; then
    print_red "Please set your Redmine API key in the script."
    if [ $USER_NAME == "Your name" ]; then
        print_red "Also, please set your name in the script."
    fi
    exit 1
fi
if [[ $REDMINE_URL == *"company"* ]]; then
    print_red "Please set your Redmine URL in the script."
    exit 1
fi

# Usages
print_blue "./check_redmine.sh (default: current week)"
print_blue "./check_redmine.sh DATE_FROM (format: YYYY-MM-DD)"
print_blue "./check_redmine.sh DATE_FROM DATE_TO (format: YYYY-MM-DD)"
echo

# Set the date range
MAX_DAYS=5 # default: 5 days (Monday to Friday)
if [ -n "$2" ]; then
    DATE_FROM=$1
    DATE_TO=$2
    # Validate the date format
    if ! date -d "$DATE_FROM" &>/dev/null; then
        print_red "Invalid date format DATE_FROM: $DATE_FROM, expected: YYYY-MM-DD"
        exit 1
    fi
    if ! date -d "$DATE_TO" &>/dev/null; then
        print_red "Invalid date format DATE_TO: $DATE_TO, expected: YYYY-MM-DD"
        exit 1
    fi
    # Calculate the number of days between the two dates
    MAX_DAYS=$(( ($(date -d "$DATE_TO" +%s) - $(date -d "$DATE_FROM" +%s)) / 86400 + 1 ))
    MAX_DAYS=$((MAX_DAYS - (MAX_DAYS / 7) * 2)) # remove saturday and sunday
    if [ $MAX_DAYS -lt 1 ]; then
        print_red "DATE_TO must be greater than DATE_FROM"
        exit 1
    fi
elif [ -n "$1" ]; then
    DATE_FROM=$1
    if ! date -d "$DATE_FROM" &>/dev/null; then
        print_red "Invalid date format DATE_FROM: $DATE_FROM, expected: YYYY-MM-DD"
        exit 1
    fi
    DATE_TO=$(date -d "$DATE_FROM +$MAX_DAYS days" +"%Y-%m-%d")
else
    DATE_FROM=$(date -d "last monday" +"%Y-%m-%d")
    DATE_TO=$(date -d "$DATE_FROM +$MAX_DAYS days" +"%Y-%m-%d")
fi
print_blue "Date range: $DATE_FROM to $DATE_TO ($MAX_DAYS working days)"

# Init a dictionary to store with key as date and value as hours
declare -A hours_per_day
for i in $(seq 0 $((MAX_DAYS - 1))); do
    DATE=$(date -d "$DATE_FROM +$i days" +"%Y-%m-%d")
    # if its not a weekend
    if [ $(date -d "$DATE" +%u) -lt 6 ]; then
        hours_per_day["$DATE"]=0
    fi
done

# GET /my/account.json : Get the user ID
get_my_user_id() {
    curl -s -H "X-Redmine-API-Key: $API_KEY" "${REDMINE_URL}/my/account.json" | grep -o '"id":[0-9]*' | grep -o '[0-9]*'
}

print_dict() {
    for DATE in $(echo "${!hours_per_day[@]}" | tr ' ' '\n' | sort); do
        TOTAL_HOURS=${hours_per_day[$DATE]}
        if (( $(echo "$TOTAL_HOURS == 8" | bc -l) )); then
            print_green "$DATE : $TOTAL_HOURS heures"
        elif (( $(echo "$TOTAL_HOURS < 8" | bc -l) )) && (( $(echo "$TOTAL_HOURS > 0" | bc -l) )); then
            print_yellow "$DATE : $TOTAL_HOURS heures"
        else
            print_red "$DATE : Missing time entries"
        fi
    done
}

# Process the response
process_response() {
    local RESPONSE_BODY="$1"

    # Keep track of the total hours per day
    while IFS= read -r entry; do
        DATE=$(echo "$entry" | jq -r '.spent_on')
        HOURS=$(echo "$entry" | jq -r '.hours')
        if [ -z "${hours_per_day[$DATE]}" ]; then
            hours_per_day["$DATE"]=$HOURS
        else
            hours_per_day["$DATE"]=$(echo "${hours_per_day[$DATE]} + $HOURS" | bc)
        fi
    done < <(echo "$RESPONSE_BODY" | jq -c '.time_entries[]')

    print_dict
}

declare -A USER_DICT
id=$(get_my_user_id) 
USER_DICT[$id]="$USER_NAME"

# Boucle sur chaque ID d'utilisateur et récupérer les temps passés
for USER_ID in "${!USER_DICT[@]}"; do
    echo ""
    USER_NAME=${USER_DICT[$USER_ID]}
    echo -e "User \e[34m$USER_NAME\e[0m (ID: $USER_ID) depuis le $DATE_FROM au $DATE_TO"
    limit=$((((MAX_DAYS / 7) + 1) * 40))
    
    # Effectuer la requête et capturer la sortie et le code de statut HTTP
    RESPONSE=$(curl -s -w "%{http_code}" -H "X-Redmine-API-Key: $API_KEY" "${REDMINE_URL}/time_entries.json?user_id=${USER_ID}&from=$DATE_FROM&to=$DATE_TO&limit=$limit")

    HTTP_STATUS=$(echo "$RESPONSE" | tail -c 4)
    RESPONSE_BODY=$(echo "$RESPONSE" | head -c -4)
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        process_response "$RESPONSE_BODY"
    else
        echo "Échec de la récupération des temps passés pour l'utilisateur $USER_ID. Code de statut HTTP: $HTTP_STATUS"
    fi
    
done