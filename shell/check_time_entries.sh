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
    print_red "Also, please set your name in the script."
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

calculate_max_days() {
    MAX_DAYS=$(( ($(date -d "$DATE_TO" +%s) - $(date -d "$DATE_FROM" +%s)) / 86400 + 1 ))
    if [ $MAX_DAYS -lt 1 ]; then
        print_red "DATE_TO must be greater than DATE_FROM"
        exit 1
    fi
}

# Set the date range
MAX_DAYS=5 # default: 5 days (Monday to Friday)
if [ -n "$2" ]; then
    DATE_FROM=$1
    if ! date -d "$DATE_FROM" &>/dev/null; then
        print_red "Invalid date format DATE_FROM: $DATE_FROM, expected: YYYY-MM-DD"
        exit 1
    fi
    DATE_TO=$2
    if ! date -d "$DATE_TO" &>/dev/null; then
        print_red "Invalid date format DATE_TO: $DATE_TO, expected: YYYY-MM-DD"
        exit 1
    fi
    calculate_max_days
elif [ -n "$1" ]; then
    DATE_FROM=$1
    if ! date -d "$DATE_FROM" &>/dev/null; then
        print_red "Invalid date format DATE_FROM: $DATE_FROM, expected: YYYY-MM-DD"
        exit 1
    fi
    DATE_TO=$(date +"%Y-%m-%d")
    calculate_max_days
else
    DATE_FROM=$(date -d "last monday" +"%Y-%m-%d")
    DATE_TO=$(date -d "$DATE_FROM +$MAX_DAYS days" +"%Y-%m-%d")
fi

# Init a dictionary to store with key as date and value as hours
declare -A hours_per_day
DICT_SIZE=0
for i in $(seq 0 $((MAX_DAYS - 1))); do
    DATE=$(date -d "$DATE_FROM +$i days" +"%Y-%m-%d")
    # if its not a weekend
    if [ $(date -d "$DATE" +%u) -lt 6 ]; then
        hours_per_day["$DATE"]=0
        DICT_SIZE=$((DICT_SIZE + 1))
    fi
done
print_blue "Date range: $DATE_FROM to $DATE_TO ($DICT_SIZE working days)"

# GET /my/account.json : Get the user ID
get_my_user_id() {
    curl -s -H "X-Redmine-API-Key: $API_KEY" "${REDMINE_URL}/my/account.json" | grep -o '"id":[0-9]*' | grep -o '[0-9]*'
}

convert_name() {
    # Convertir tout en minuscules
    local lower_name=$(echo "$USER_NAME" | tr '[:upper:]' '[:lower:]')
    
    # Extraire le prénom et le nom
    local first_name=$(echo "$lower_name" | awk '{print $1}')
    local last_name=$(echo "$lower_name" | awk '{print $2}')
    
    # Extraire la première lettre du prénom
    local first_initial=$(echo "$first_name" | cut -c 1)
    
    # Combiner pour obtenir le résultat souhaité
    local result="${first_initial}${last_name}"
    
    echo "$result"
}

print_dict() {
    missing_time=""
    for DATE in $(echo "${!hours_per_day[@]}" | tr ' ' '\n' | sort); do
        TOTAL_HOURS=${hours_per_day[$DATE]}
        if (( $(echo "$TOTAL_HOURS == 8" | bc -l) )); then
            print_green "$DATE : $TOTAL_HOURS heures"
        elif (( $(echo "$TOTAL_HOURS < 8" | bc -l) )) && (( $(echo "$TOTAL_HOURS > 0" | bc -l) )); then
            print_yellow "$DATE : $TOTAL_HOURS heures"
            missing_time="$missing_time$DATE : $TOTAL_HOURS heures \n "
        else
            print_red "$DATE : Missing time entries"
            missing_time="$missing_time$DATE : $TOTAL_HOURS heures \n "
        fi
    done

    if [ -n "$missing_time" ]; then
        echo
        print_yellow "Sending an email to remind you to fill in the missing time entries."
        ./send_email.sh "$missing_time" "$(convert_name)"
    fi
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
# Can change this to have multiple users
id=$(get_my_user_id)
USER_DICT[$id]="$USER_NAME"

# Loop through each user
for USER_ID in "${!USER_DICT[@]}"; do
    echo 
    USER_NAME=${USER_DICT[$USER_ID]}
    echo -e "User \e[34m$USER_NAME\e[0m (ID: $USER_ID) from $DATE_FROM to $DATE_TO"
    limit=$((((MAX_DAYS / 7) + 1) * 40))

    RESPONSE=$(curl -s -w "%{http_code}" -H "X-Redmine-API-Key: $API_KEY" "${REDMINE_URL}/time_entries.json?user_id=${USER_ID}&from=$DATE_FROM&to=$DATE_TO&limit=$limit")

    HTTP_STATUS=$(echo "$RESPONSE" | tail -c 4)
    RESPONSE_BODY=$(echo "$RESPONSE" | head -c -4)
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        process_response "$RESPONSE_BODY"
    else
        echo "Error while fetching time entries: $RESPONSE_BODY"
    fi
done