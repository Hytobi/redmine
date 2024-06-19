import requests
import json
import datetime
from collections import defaultdict
from termcolor import colored

# Configurations
API_KEY = ""
USER_NAME = "Your name"
REDMINE_URL = "https://redmine.company.com"

def print_green(message):
    print(colored(message, 'green'))

def print_red(message):
    print(colored(message, 'red'))

def print_yellow(message):
    print(colored(message, 'yellow'))

if not API_KEY:
    print_red("Please set your Redmine API key in the script.")
    exit(1)
if "company" in REDMINE_URL:
    print_red("Please set your Redmine URL in the script.")
    exit(1)

# Calculate the date from 7 days ago
date_from = (datetime.date.today() - datetime.timedelta(days=datetime.date.today().weekday())).strftime('%Y-%m-%d')
date_to = (datetime.date.today() - datetime.timedelta(days=datetime.date.today().weekday()) + datetime.timedelta(days=5)).strftime('%Y-%m-%d')
MAX_DAYS = 5  # We retrieve the last 7 days, excluding Saturday and Sunday

# Function to get your own user ID
def get_my_user_id():
    response = requests.get(f"{REDMINE_URL}/my/account.json", headers={"X-Redmine-API-Key": API_KEY})
    if response.status_code == 200:
        return response.json()['user']['id']
    else:
        print_red(f"Failed to retrieve user ID. HTTP response code: {response.status_code}")
        exit(1)

# Function to process the response and check the logged hours for each day
def process_response(response_body):
    hours_per_day = defaultdict(float)

    for entry in response_body['time_entries']:
        date = entry['spent_on']
        hours = entry['hours']
        hours_per_day[date] += hours

    if len(hours_per_day) < MAX_DAYS:
        print_red("Il manque des jours dans les temps passés")

    for date in sorted(hours_per_day):
        total_hours = hours_per_day[date]
        if total_hours < 8:
            print_yellow(f"{date} : {total_hours} heures")
        else:
            print_green(f"{date} : {total_hours} heures")

# Get user ID and dictionary
user_id = get_my_user_id()
user_dict = {user_id: USER_NAME}

# Loop through each user ID and retrieve the logged time
for user_id, user_name in user_dict.items():
    print(f"\nUtilisateur {colored(user_name, 'blue')} (ID: {user_id}) depuis le {date_from} au {date_to}")

    response = requests.get(f"{REDMINE_URL}/time_entries.json?user_id={user_id}&from={date_from}&to={date_to}&limit=50",
                            headers={"X-Redmine-API-Key": API_KEY})
    if response.status_code == 200:
        process_response(response.json())
    else:
        print_red(f"Échec de la récupération des temps passés pour l'utilisateur {user_id}. Code de statut HTTP: {response.status_code}")
