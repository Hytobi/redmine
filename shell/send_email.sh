#!/bin/bash

body="$1"
to="$2@exemple.com"
subject="Test"


echo "To: $to"
echo "Subject: $subject"
echo ""
echo "$body" 
#echo "$body" | ssmtp "$to"