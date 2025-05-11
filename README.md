# cron-affinity
This script is supposed to go into your cron file to poll FurAffinity for nofications and push them to you via a Telegram bot.

## Please set a respectful interval to not spam FurAffinitys servers
This script scans https://www.furaffinity.net/blm/ (which you should give a read btw!) for sake of causing the least possible SQL queries, but it still is a non-0 load on their servers. Let's show our appreciation for the FurAffinity teams hard work and not cause them an extra headache!

## Settings
Configuration is done via the "settings" file next to the script, it includes the following variables:

| Setting | Description |
| --- | --- |
| bot_token | This is your Telegram bot token you get from the Botfather after creating a bot.<br>**Don't EVER share this**, this goes in the settings file and never in any chats. |
| chat_id | This is the chat ID between you and the bot after you did /start on your own bot or added it to a group (why?).<br>To get this ID, send the bot a message and run `curl -s https://api.telegram/bot[YOUR TOKEN]/getUpdates` |
| notify_for | This sets what to notify for, the letter for each type of notification just needs to be in here somewhere.<br><br>**Example 1:** `SCJWFN` would notify for everything, it can also be `WFNJCS` or whatever, this changes nothing<br>**Example 2:** `CN` would notify for comments and notes only<br>**Example 3:** `S` would only notify for new submissions |

## Cookies.txt
Another necessary file is your cookies.txt in netscape format, exporting this depends on your browser and you will probably have to Google how to do it, otherwise the script does create the minimum necessary file for you to fill out.
