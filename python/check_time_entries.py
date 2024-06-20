import requests
import sys
from collections import defaultdict
from datetime import datetime, timedelta

# Configurations
API_KEY = ""
USER_NAME = "Your Name"
REDMINE_URL = "https://redmine.company.com"

def print_green(message):
    print(f"\033[32m{message}\033[0m")

def print_red(message):
    print(f"\033[31m{message}\033[0m")

def print_yellow(message):
    print(f"\033[33m{message}\033[0m")

def print_blue(message):
    print(f"\033[94m{message}\033[0m")

if not API_KEY:
    print_red("Please set your Redmine API key in the script.")
    exit(1)
if "company" in REDMINE_URL:
    print_red("Please set your Redmine URL in the script.")
    exit(1)

def is_valid_date(date_string):
    try:
        datetime.strptime(date_string, "%Y-%m-%d")
        return True
    except ValueError:
        return False

def calculate_max_days(date_from, date_to):
    date_from_obj = datetime.strptime(date_from, "%Y-%m-%d")
    date_to_obj = datetime.strptime(date_to, "%Y-%m-%d")
    max_days = (date_to_obj - date_from_obj).days + 1
    if max_days < 1:
        print_red("DATE_TO must be greater than DATE_FROM")
        sys.exit(1)
    return max_days

# Set the date range
MAX_DAYS = 5  # default: 5 days (Monday to Friday)
args = sys.argv

if len(args) > 2:
    DATE_FROM = args[1]
    if not is_valid_date(DATE_FROM):
        print_red(f"Invalid date format DATE_FROM: {DATE_FROM}, expected: YYYY-MM-DD")
        sys.exit(1)
    
    DATE_TO = args[2]
    if not is_valid_date(DATE_TO):
        print_red(f"Invalid date format DATE_TO: {DATE_TO}, expected: YYYY-MM-DD")
        sys.exit(1)
    
    MAX_DAYS = calculate_max_days(DATE_FROM, DATE_TO)

elif len(args) > 1:
    DATE_FROM = args[1]
    if not is_valid_date(DATE_FROM):
        print_red(f"Invalid date format DATE_FROM: {DATE_FROM}, expected: YYYY-MM-DD")
        sys.exit(1)
    
    DATE_TO = datetime.today().strftime("%Y-%m-%d")
    MAX_DAYS = calculate_max_days(DATE_FROM, DATE_TO)

else:
    DATE_FROM = (datetime.today() - timedelta(days=datetime.today().weekday())).strftime("%Y-%m-%d")
    DATE_TO = (datetime.strptime(DATE_FROM, "%Y-%m-%d") + timedelta(days=MAX_DAYS)).strftime("%Y-%m-%d")

# Init a dictionary to store with key as date and value as hours
hours_per_day = {}
dict_size = 0
for i in range(MAX_DAYS):
    date = (datetime.strptime(DATE_FROM, "%Y-%m-%d") + timedelta(days=i)).strftime("%Y-%m-%d")
    # if it's not a weekend
    if datetime.strptime(date, "%Y-%m-%d").weekday() < 5:
        hours_per_day[date] = 0
        dict_size += 1

print_blue(f"Date range: {DATE_FROM} to {DATE_TO} ({dict_size} working days)")

def print_dict():
    missing_time = ""
    for date in sorted(hours_per_day.keys(), key=lambda x: datetime.strptime(x, '%Y-%m-%d')):
        total_hours = hours_per_day[date]
        if total_hours == 8:
            print_green(f"{date} : {total_hours} heures")
        elif 0 < total_hours < 8:
            print_yellow(f"{date} : {total_hours} heures")
            missing_time += f"{date} : {total_hours} heures \n"
        else:
            print_red(f"{date} : Missing time entries")
            missing_time += f"{date} : Missing time entries \n"

    if missing_time:
        print()
        print_yellow("Sending an email to remind you to fill in the missing time entries.")
        send_email(missing_time, convert_name())

def send_email(missing_time, name):
    # TODO: Send an email to the user to remind them to fill in the missing time entries
    pass

def convert_name():
    global USER_NAME
    parts = USER_NAME.lower().split()
    if len(parts) == 2:
        first_name_initial = parts[0][0].upper()
        last_name = parts[1].capitalize()
        return f"{first_name_initial}. {last_name}"
    else:
        # Gestion des cas où le nom complet n'est pas dans le format attendu
        return USER_NAME.capitalize()

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
    for entry in response_body['time_entries']:
        date = entry['spent_on']
        hours = entry['hours']
        hours_per_day[date] += hours

    print_dict()

# Get user ID and dictionary
user_id = get_my_user_id()
user_dict = {user_id: USER_NAME}

# Loop through each user ID and retrieve the logged time
for user_id, user_name in user_dict.items():
    print(f"\nUtilisateur \033[34m{user_name}\033[0m (ID: {user_id}) depuis le {DATE_FROM} au {DATE_TO}")
    limit = ((MAX_DAYS / 7) + 1) * 40

    response = requests.get(f"{REDMINE_URL}/time_entries.json?user_id={user_id}&from={DATE_FROM}&to={DATE_TO}&limit={limit}",
                            headers={"X-Redmine-API-Key": API_KEY})
    if response.status_code == 200:
        process_response(response.json())
    else:
        print_red(f"Échec de la récupération des temps passés pour l'utilisateur {user_id}. Code de statut HTTP: {response.status_code}")