import subprocess

script1 = './post_time_entries.py'
script2 = './check_time_entries.py'

# Exécution du premier script
processPost = subprocess.run(['python', script1], capture_output=True, text=True)
print(f'Sortie du premier script:\n{processPost.stdout}')
print(f'Erreurs du premier script:\n{processPost.stderr}')

# Exécution du deuxième script
processGet = subprocess.run(['python', script2], capture_output=True, text=True)
print(f'Sortie du deuxième script:\n{processGet.stdout}')
print(f'Erreurs du deuxième script:\n{processGet.stderr}')
