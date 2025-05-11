#!/bin/bash
#
# cron-affinity by FynnleyNeko
# This script is supposed to go into your cron file to poll FurAffinity for nofications and push them to you
# via a Telegram bot. Please make sure your interval is respectful to FurAffinity and enjoy the script! <3
#
# Configuration is done via the "settings" file next to the script, it includes the following variables:
#
# bot_token:  This is your Telegram bot token you get from the Botfather after creating a bot
#             Don't EVER share this, this goes in the settings file and never in any chats
#
# chat_id:    This is the chat ID between you and the bot after you did /start on your own bot or added it to a group (why?)
#             To get this ID, send the bot a message and run "curl -s https://api.telegram/bot[YOUR TOKEN]/getUpdates"
#
# notify_for: This sets what to notify for, the letter for each type of notification just needs to be in here somewhere
#             Example 1: SCJWFN would notify for everything, it can also be WFNJCS or whatever, this changes nothing
#             Example 2: CN would notify for comments and notes only
#             Example 3: S would only notify for new submissions
#
# Another necessary file is your cookies.txt in netscape format, exporting this depends on your browser and you
# will probably have to Google how to do it, otherwise the script does create the minimum necessary file for
# you to fill out. This is not really recommended tho.
#
# State is saved in the "previous" file, but if it goes missing the only real result is one notification with whacky numbers

# Set working directory to script location (settings, state and cookies file will appear next to the script this way)
cd "${0%/*}"

# Verify all settings and create the corresponding files if necessary
if [ ! -f ./settings ]; then
  echo -e "bot_token=\nchat_id=\nnotify_for=\n" > ./settings
  echo "Settings file was missing, please fill it out!"
  exit 78 # This means config error according to sysexits
else
  # Read settings
  SETTINGS=$(cat ./settings)

  # Read bot token and do preliminary format check
  BOT_TOKEN=$(echo "$SETTINGS" | grep bot_token | sed 's/.*=//' | grep -oP '[0-9]{8,10}:[a-zA-Z0-9_-]{35}' )
  if [ -z "${BOT_TOKEN}" ]; then
    echo "Settings file is invalid. Your Telegram bot token is not in the right format!"
    exit 78 # This means config error according to sysexits
  fi

  # We seem to still be running, so let's test if the token is also actually valid
  TEST_TG=$(curl -sf 'https://api.telegram.org/bot'$BOT_TOKEN'/getMe')
  if [ -z "${TEST_TG}" ]; then
    echo "Settings file is invalid. Your Telegram bot token is invalid!"
	exit 78 # This means config error according to sysexits
  fi

  # Read chat id and check format
  CHAT_ID=$(echo "$SETTINGS" | grep chat_id | sed 's/.*=//' | grep -oP '[1-9][0-9]{0,11}')
  if [ -z "${CHAT_ID}" ]; then
    echo "Settings file is invalid. The chat ID isn't in the right format!"
	exit 78 # This means config error according to sysexits
  fi

  # We seem to still be running, so let's test if the token is also actually valid
  TEST_CI=$(curl -sf -d "chat_id=$CHAT_ID" 'https://api.telegram.org/bot'$BOT_TOKEN'/getChat')
  if [ -z "${TEST_CI}" ]; then
    echo "Settings file is invalid. Your Telegram bot is working, but it can't find the specified chat ID!"
	exit 78 # This means config error according to sysexits
  fi

  # Read notification settings
  NOTIFY_FOR=$(echo "$SETTINGS" | grep notify_for | sed 's/.*=//' | grep -oP '^[SCJWFN]*')
  if [ -z "${NOTIFY_FOR}" ]; then
    echo "Settings file is invalid. You have selected either invalid notification categories or none at all!"
	exit 78 # This means config error according to sysexits
  fi
fi
if [ ! -f ./cookies.txt ]; then
  echo -e ".furaffinity.net\tTRUE\t/\tTRUE\t(expiry unix timestamp)\ta\t(a cookie)\n.furaffinity.net\tTRUE\t/\tTRUE\t(expiry unix timestamp)\tb\t(b cookie)\n" > ./cookies.txt
  echo "Cookies file was missing, please export it from your browser or fill it out manually! (Netscape format)"
  exit 78 # This means config error according to sysexits
else
  # Read cookies file and try to extract the two we care about
  COOKIES=$(cat ./cookies.txt)
  COOKIE_A=$(echo "$COOKIES" | grep $'\ta\t')
  COOKIE_B=$(echo "$COOKIES" | grep $'\tb\t')

  # Check if we got both of them
  if [[ -z "${COOKIE_A}" || -z "${COOKIE_B}" ]]; then
    echo "Can't find all required cookies! (a and b)"
    exit 78 # This means config error according to sysexits
  fi

  # Trim the cookies to the validity timestamps for the next check
  COOKIE_A=$(echo $COOKIE_A | grep -oP '[[:digit:]]*' | head -1)
  COOKIE_B=$(echo $COOKIE_A | grep -oP '[[:digit:]]*' | head -1)
  CURRENT_TIME=$(date '+%s')

  # Compare timestamps and exit if the cookies are invalid
  if (( $COOKIE_A < $CURRENT_TIME || $COOKIE_B < $CURRENT_TIME )); then
    echo "Your cookies aren't valid anymore, please get a new cookies.txt file!"
	echo 78 # This means config error according to sysexitsw
  fi
fi
# Checks are now done! If we manage to still run at this point this should all work

# Load previous notification state and get new notification state
PREVIOUS=$(cat ./previous 2>/dev/null) # Sending that "File doesn't exist" error to the nether realm, it all defaults to 0 automatically anyways
NOTIFICATIONS=$(curl -b ./cookies.txt -s https://www.furaffinity.net/blm/) # Not only does this page cause the least SQL queries for FA, you should also give it a read!

# Test if the HTML request worked, by searching for signs of a logged in user in the response HTML, this is missing from error pages and if the cookies were invalid
TEST_FA=$(echo "$NOTIFICATIONS" | grep loggedin_user_avatar)
if [ -z "${TEST_FA}" ]; then
  echo "Couldn't read notifications from FurAffinity! Is it down or did you change your password? (Please check your cookies.txt)"
  exit 69 # This is NOT a joke, this means service unavailable according to sysexits
fi

# Extract individual notification states from current state
NOTIFICATIONS=$(echo "$NOTIFICATIONS" | grep "notification-container")
SUBMISSIONS=$(echo "$NOTIFICATIONS" | grep "/msg/submissions/" | head -n 1 | sed 's/\s*[^[:digit:]]*<[^>]*>//g')
COMMENTS=$(echo "$NOTIFICATIONS" | grep "/msg/others/#comments" | head -n 1 | sed 's/\s*[^[:digit:]]*<[^>]*>//g')
JOURNALS=$(echo "$NOTIFICATIONS" | grep "/msg/others/#journals" | head -n 1 | sed 's/\s*[^[:digit:]]*<[^>]*>//g')
WATCHES=$(echo "$NOTIFICATIONS" | grep "/msg/others/#watches" | head -n 1 | sed 's/\s*[^[:digit:]]*<[^>]*>//g')
FAVORITES=$(echo "$NOTIFICATIONS" | grep "/msg/others/#favorites" | head -n 1 | sed 's/\s*[^[:digit:]]*<[^>]*>//g')
NOTES=$(echo "$NOTIFICATIONS" | grep "/msg/pms/" | head -n 1 | sed 's/\s*[^[:digit:]]*<[^>]*>//g')

# Extract individual notification states from previous state
P_SUBMISSIONS=$(echo $PREVIOUS | grep -oP '([[:digit:]]*S)' | head -c -2)
P_COMMENTS=$(echo $PREVIOUS | grep -oP '([[:digit:]]*C)' | head -c -2)
P_JOURNALS=$(echo $PREVIOUS | grep -oP '([[:digit:]]*J)' | head -c -2)
P_WATCHES=$(echo $PREVIOUS | grep -oP '([[:digit:]]*W)' | head -c -2)
P_FAVORITES=$(echo $PREVIOUS | grep -oP '([[:digit:]]*F)' | head -c -2)
P_NOTES=$(echo $PREVIOUS | grep -oP '([[:digit:]]*N)' | head -c -2)

# Construct notification message
# If you share the bot token with other apps (like I do for Home-Assistant), add something like $'FurAffinity Notifications\n\n' here
# to add a prefix to your notifications, remember to keep the $'' intact and dont use "" or '', because they don't interpret newlines
MESSAGE=$''

# This adds the submission count if it's enabled
if [ $(echo $NOTIFY_FOR | grep -oP 'S') ]; then
  if (( ${SUBMISSIONS:=0} > ${P_SUBMISSIONS:=0} )); then
    (( DIFF = ${SUBMISSIONS:=0} - ${P_SUBMISSIONS:=0} ))
    if (( $DIFF > 1 )); then
      CATEGORY=$'submissions\n'
    else
      CATEGORY=$'submission\n'
    fi
    MESSAGE=$MESSAGE$DIFF" new "$CATEGORY
  fi
fi
# This adds the comment count if it's enabled
if [ $(echo $NOTIFY_FOR | grep -oP 'C') ]; then
  if (( ${COMMENTS:=0} > ${P_COMMENTS:=0} )); then
    (( DIFF = ${COMMENTS:=0} - ${P_COMMENTS:=0} ))
    if (( $DIFF > 1 )); then
      CATEGORY=$'comments\n'
    else
      CATEGORY=$'comment\n'
    fi
    MESSAGE=$MESSAGE$DIFF" new "$CATEGORY
  fi
fi
# This adds the journal count if it's enabled
if [ $(echo $NOTIFY_FOR | grep -oP 'J') ]; then
  if (( ${JOURNALS:=0} > ${P_JOURNALS:=0} )); then
    (( DIFF = ${JOURNALS:=0} - ${P_JOURNALS:=0} ))
    if (( $DIFF > 1 )); then
      CATEGORY=$'journals\n'
    else
      CATEGORY=$'journal\n'
    fi
    MESSAGE=$MESSAGE$DIFF" new "$CATEGORY
  fi
fi
# This adds the watcher count if it's enabled
if [ $(echo $NOTIFY_FOR | grep -oP 'W') ]; then
  if (( ${WATCHES:=0} > ${P_WATCHES:=0} )); then
    (( DIFF = ${WATCHES:=0} - ${P_WATCHES:=0} ))
    if (( $DIFF > 1 )); then
      CATEGORY=$'watchers\n'
    else
      CATEGORY=$'watcher\n'
    fi
    MESSAGE=$MESSAGE$DIFF" new "$CATEGORY
  fi
fi
# This adds the favorite count if it's enabled
if [ $(echo $NOTIFY_FOR | grep -oP 'F') ]; then
  if (( ${FAVORITES:=0} > ${P_FAVORITES:=0} )); then
    (( DIFF = ${FAVORITES:=0} - ${P_FAVORITES:=0} ))
    if (( $DIFF > 1 )); then
      CATEGORY=$'favorites\n'
    else
      CATEGORY=$'favorite\n'
    fi
    MESSAGE=$MESSAGE$DIFF" new "$CATEGORY

  fi
fi
# This adds the note count if it's enabled
if [ $(echo $NOTIFY_FOR | grep -oP 'N') ]; then
  if (( ${NOTES:=0} > ${P_NOTES:=0} )); then
    (( DIFF = ${NOTES:=0} - ${P_NOTES:=0} ))
    if (( $DIFF > 1 )); then
      CATEGORY=$'notes\n'
    else
      CATEGORY=$'note\n'
    fi
    MESSAGE=$MESSAGE$DIFF" new "$CATEGORY

  fi
fi

# Send notification to Telegram (if it isn't empty)
if [ -z "${MESSAGE}" ]; then
  # Feel free to comment this out, I just like knowing the script ran. If all goes well but there's nothing new
  # this will be the only message you see from this script.
  echo "Nothing to notify about this time."

  # Writing the previous state here because non-enabled categories might have updated their numbers
  echo ${SUBMISSIONS:=0}"S"${COMMENTS:=0}"C"${JOURNALS:=0}"J"${WATCHES:=0}"W"${FAVORITES:=0}"F"${NOTES:=0}"N" > ./previous
else
  # Telegram sends a result json, not the prettiest, but it will show up in the log if it worked or why it didn't
  # althought at this point we have checked so much that it really should. I still verify if it did.
  SENT=$(curl -s -d "text=$MESSAGE" -d "chat_id=$CHAT_ID" 'https://api.telegram.org/bot'$BOT_TOKEN'/sendMessage')

  if [ $(echo "$SENT" | grep '"ok":true') ]; then
    # Save notification states to previous file for next run and output the full answer of Telegrams API
    echo ${SUBMISSIONS:=0}"S"${COMMENTS:=0}"C"${JOURNALS:=0}"J"${WATCHES:=0}"W"${FAVORITES:=0}"F"${NOTES:=0}"N" > ./previous
    echo "$SENT"
  else
    # If we land here that's not great, so we don't save state
    echo "$SENT"
  fi
fi
