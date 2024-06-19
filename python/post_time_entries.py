import requests
import pandas as pd
import math

# Configuration
API_KEY = ""
REDMINE_URL = "https://redmine.company.com"

def print_green(message):
    print(f"\033[32m{message}\033[0m")

def print_red(message):
    print(f"\033[31m{message}\033[0m")

if not API_KEY:
    print_red("Please set your Redmine API key in the script.")
    exit(1)
if "company" in REDMINE_URL:
    print_red("Please set your Redmine URL in the script.")
    exit(1)

def sanitize_floats(data):
    if isinstance(data, float):
        if math.isnan(data) or math.isinf(data):
            return None
        return data
    elif isinstance(data, dict):
        return {k: sanitize_floats(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [sanitize_floats(v) for v in data]
    return data

def log_time(issue_id, hours, comments, date_spent):

    date = (str(date_spent))[:10]
    if not issue_id.isdigit():
        print_red(f"L'ID de l'issue doit être un nombre: {issue_id}")
        return

    json_data = {
        "time_entry": {
            "issue_id": issue_id,
            "hours": hours,
            "comments": comments,
            "spent_on": date
        }
    }

    # Nettoyer les données avant de les convertir en JSON
    json_data = sanitize_floats(json_data)

    headers = {
        "Content-Type": "application/json",
        "X-Redmine-API-Key": API_KEY
    }

    response = requests.post(f"{REDMINE_URL}/time_entries.json", json=json_data, headers=headers)

    if response.status_code == 201:
        print_green(f"Time logged successfully for issue {issue_id}.")
    elif response.status_code == 422:
        print_red(f"Failed to log time for issue {issue_id}. Error: {response.json()['errors']}")
    else:
        print_red(f"Failed to log time for issue {issue_id}. HTTP response code: {response.status_code}")

# Convert the Excel file to a DataFrame
try:
    df = pd.read_excel('timesheet.xlsx')
except Exception as e:
    print_red(f"Failed to convert the Excel file to DataFrame: {e}")
    exit(1)

# Iterate over the DataFrame rows and log time
for index, row in df.iterrows():
    if row['issue_id'] != 'issue_id':  # Skip header
        log_time(str(row['issue_id']), row['hours'], row['comments'], row['date_spent'])

# Ask user if they want to clear the content of the Excel file (but keep the columns)
response = input("Voulez-vous effacer le contenu du fichier Excel ? [y/n]: ")
if response.lower() == 'y':
    df.iloc[0:0] = df.iloc[0:0]  # Clear all rows but keep columns
    df.to_excel('timesheet.xlsx', index=False)
    print_green("Le fichier Excel a été vidé.")