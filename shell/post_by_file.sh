#!/bin/bash



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

# POST /time_entries.json
log_time() {
    local issue_id="$1"
    local hours="$2"
    local comments="$3"
    local date_spent="$4"

    # If the issue ID is not a number or is empty, return
    if ! [[ "$issue_id" =~ ^[0-9]+$ ]]; then
        if [ -z "$issue_id" ]; then
            return
        fi
        print_red "L'ID de l'issue doit être un nombre: $issue_id"
        return
    fi

    # If one of the required fields is empty, return
    if [ -z "$hours" ] || [ -z "$date_spent" ]; then
        print_red "Hours and date_spent are required fields for issue: $issue_id"
        return
    fi

    # Create a JSON payload
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

    # Send a POST request to log time
    local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "X-Redmine-API-Key: $API_KEY" \
        -d "$json_data" \
        "$REDMINE_URL/time_entries.json")

    # Print the response message
    if [ "$response" -eq 201 ]; then
        print_green "Time logged successfully issue: $issue_id date_spent: $date_spent."
    elif [ "$response" -eq 422 ]; then
        print_red "Failed to log time for issue $issue_id for $date_spent. You may have already logged time on this date."
    else
        print_red "Failed to log time for issue $issue_id. HTTP response code: $response"
    fi
}

# Convert the Excel file to CSV
xlsx2csv timesheet.xlsx timesheet.csv
if [ $? -ne 0 ]; then
    echo "Failed to convert the Excel file to CSV."
    exit 1
fi

# Read the CSV file and log time for each row
while IFS=, read -r issue_id hours comments date_spent; do
    # Skip the header row
    if [ "$issue_id" != "issue_id" ]; then
        log_time "$issue_id" "$hours" "$comments" "$date_spent"
    fi
done < timesheet.csv

# Remove the CSV file
rm timesheet.csv

# Ask the user if they want to clear the Excel file
read -p "Do you want to clear the Excel file? [Y/n] " -n 1 -r
echo
if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
    xlsx2csv --skip-empty-rows timesheet.xlsx timesheet.csv
    mv timesheet.csv timesheet.xlsx
    print_green "Le fichier Excel a été vidé."
elif [[ $REPLY =~ ^[Nn]$ ]]; then
    print_green "Le fichier Excel n'a pas été vidé."
else
    print_red "Invalid input. The Excel file was not cleared."
fi