#!/bin/bash

# Configurations
API_KEY=""
USER_NAME="Your name"
REDMINE_URL="https://redmine.company.com"

print_green() { echo -e "\e[32m$1\e[0m"; }
print_red() { echo -e "\e[31m$1\e[0m"; }
print_yellow() { echo -e "\e[33m$1\e[0m"; }

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

# Calculer la date de 7 jours en arrière
DATE_FROM=$(date -d "last monday" +"%Y-%m-%d")
DATE_TO=$(date -d "last monday +5 days" +"%Y-%m-%d")
MAX_DAYS=5 # On recupére les 7 dernier jour, donc on retir samedi et dimanche

# Fonction pour récupérer votre propre ID utilisateur
get_my_user_id() {
    curl -s -H "X-Redmine-API-Key: $API_KEY" "${REDMINE_URL}/my/account.json" | grep -o '"id":[0-9]*' | grep -o '[0-9]*'
}

# Fonction pour vérifier les heures renseignées pour chaque jour
process_response() {
    local RESPONSE_BODY="$1"
    declare -A hours_per_day

    # Extraire les dates et les heures du JSON de réponse
    while IFS= read -r entry; do
        DATE=$(echo "$entry" | jq -r '.spent_on')
        HOURS=$(echo "$entry" | jq -r '.hours')
        if [ -z "${hours_per_day[$DATE]}" ]; then
            hours_per_day["$DATE"]=$HOURS
        else
            hours_per_day["$DATE"]=$(echo "${hours_per_day[$DATE]} + $HOURS" | bc)
        fi
    done < <(echo "$RESPONSE_BODY" | jq -c '.time_entries[]')

    if [ ${#hours_per_day[@]} -lt $MAX_DAYS ]; then
        print_red "Il manque des jours dans les temps passés"
    fi

    for DATE in $(echo "${!hours_per_day[@]}" | tr ' ' '\n' | sort); do
        TOTAL_HOURS=${hours_per_day[$DATE]}
        if (( $(echo "$TOTAL_HOURS < 8" | bc -l) )); then
            print_yellow "$DATE : $TOTAL_HOURS heures"
        else
            print_green "$DATE : $TOTAL_HOURS heures"
        fi
    done
}

declare -A USER_DICT
id=$(get_my_user_id) 
USER_DICT[$id]="$USER_NAME"

# Boucle sur chaque ID d'utilisateur et récupérer les temps passés
for USER_ID in "${!USER_DICT[@]}"; do
    echo ""
    USER_NAME=${USER_DICT[$USER_ID]}
    echo -e "Utilisateur \e[34m$USER_NAME\e[0m (ID: $USER_ID) depuis le $DATE_FROM au $DATE_TO"
    
    # Effectuer la requête et capturer la sortie et le code de statut HTTP
    RESPONSE=$(curl -s -w "%{http_code}" -H "X-Redmine-API-Key: $API_KEY" "${REDMINE_URL}/time_entries.json?user_id=${USER_ID}&from=$DATE_FROM&to=$DATE_TO&limit=50")

    HTTP_STATUS=$(echo "$RESPONSE" | tail -c 4)
    RESPONSE_BODY=$(echo "$RESPONSE" | head -c -4)
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        process_response "$RESPONSE_BODY"
    else
        echo "Échec de la récupération des temps passés pour l'utilisateur $USER_ID. Code de statut HTTP: $HTTP_STATUS"
    fi
    
done