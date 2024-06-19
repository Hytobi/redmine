#!/bin/bash

#TODO: Fix la sup du excel

# Configuration
API_KEY=""
REDMINE_URL="https://redmine.company.com"

print_green() { echo -e "\e[32m$1\e[0m"; }
print_red() { echo -e "\e[31m$1\e[0m"; }

if [ -z "$API_KEY" ]; then
    print_red "Please set your Redmine API key in the script."
    exit 1
fi
if [[ $REDMINE_URL == *"company"* ]]; then
    print_red "Please set your Redmine URL in the script."
    exit 1
fi

# Fonction pour enregistrer le temps passé
log_time() {
    local issue_id="$1"
    local hours="$2"
    local comments="$3"
    local date_spent="$4"

    # si l'id n'est pas un nombre: cas de suppression de la ligne ?
    if ! [[ "$issue_id" =~ ^[0-9]+$ ]]; then
        print_red "L'ID de l'issue doit être un nombre: $issue_id"
        return
    fi

    local json_data=$(jq -n \
        --arg issue_id "$issue_id" \
        --arg hours "$hours" \
        --arg comments "$comments" \
        --arg spent_on "$date_spent" \
        '{
            time_entry: {
                issue_id: $issue_id,
                hours: $hours,
                comments: $comments,
                spent_on: $spent_on
            }
        }')

    local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "X-Redmine-API-Key: $API_KEY" \
        -d "$json_data" \
        "$REDMINE_URL/time_entries.json")

    if [ "$response" -eq 201 ]; then
        print_green "Time logged successfully for issue $issue_id."
    else if [ "$response" -eq 422 ]; then
        error=`$response | jq -r '.errors'`
        print_red "Failed to log time for issue $issue_id. error: $error."
    else
        print_red "Failed to log time for issue $issue_id. HTTP response code: $response"
    fi
}

# Convertir le fichier Excel en CSV
xlsx2csv timesheet.xlsx timesheet.csv

if [ $? -ne 0 ]; then
    echo "Failed to convert the Excel file to CSV."
    exit 1
fi

# Lire le fichier CSV et boucler sur les lignes
while IFS=, read -r issue_id hours comments date_spent; do
    # Skip the header row
    if [ "$issue_id" != "issue_id" ]; then
        log_time "$issue_id" "$hours" "$comments" "$date_spent"
    fi
done < timesheet.csv

# Nettoyage des fichiers temporaires
rm timesheet.csv

## Demand a l'utilisateur s'il veut efacer le contenu du fichier exec (mais laisse les colonnes)
read -p "Voulez-vous effacer le contenu du fichier Excel ? [y/n]: " response
if [ "$response" == "y" ]; then
    xlsx2csv --skip-empty-rows timesheet.xlsx timesheet.csv
    mv timesheet.csv timesheet.xlsx
    print_green "Le fichier Excel a été vidé."
fi