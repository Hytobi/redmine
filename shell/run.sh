## Vérification de l'existence de jq
if ! command -v jq &> /dev/null; then
    echo "jq n'est pas installé. Veuillez l'installer pour continuer."
    read -p "Voulez-vous installer jq maintenant ? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt-get install jq
    else
        exit 1
    fi
fi

## Verification de l'existence de xlsx2csv
if ! command -v xlsx2csv &> /dev/null; then
    echo "xlsx2csv n'est pas installé. Veuillez l'installer"
    read -p "Voulez-vous installer xlsx2csv maintenant ? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt-get install xlsx2csv
    else
        exit 1
    fi
fi

if [ ! -f "timesheet.xlsx" ]; then
    echo "Le fichier timesheet.xlsx n'existe pas."
    exit 1
fi

./post_by_file.sh
./check_redmine.sh