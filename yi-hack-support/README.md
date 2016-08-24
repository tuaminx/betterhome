# yi-hack-support
This is the supporting script for who is using hacked rom of Xiaomi Yi Smart camera

(https://github.com/fritz-smh/yi-hack)

# How to use:
## upload_to_ftp.sh

Copy `sd/test/scripts/upload_to_ftp.sh` to folder `test/scripts/` on SD card

Copy 3 files `sd/test/ftp_upload.*` to folder `test/` on SD card

Open file `test/scripts/upload_to_ftp.sh` on SD card and change the FTP server configuration:
```ftp_dir="/path/to/folder/on/ftp"
ftp_host="192.168.1.1"
ftp_port="21"
ftp_login="ftp_username"
ftp_pass="ftp_password"
```

Open file `test/ftp_upload.mem` and change the filename you want to be started uploading to FTP server. The script will upload the this file until the file with its filename is script execution time.

`2016Y08M01D01H/01M00S.mp4`

Start the script and check its progress on log file
```
telnet <camera_ip>
/tmp/hd1/test/scripts/upload_to_ftp.sh
tail -f /tmp/hd1/test/ftp_upload.log
```

## Start script by scheduler (crond)

Make crontabs folder
```
mkdir -p /var/spool/cron/crontabs
```

Open crontab for edit by `crontab -e` and paste below content
```
# Edit this file to introduce tasks to be run by cron.
#
# Each task to run has to be defined through a single line
# indicating with different fields when the task will be run
# and what command to run for the task
#
# To define the time you can provide concrete values for
# minute (m), hour (h), day of month (dom), month (mon),
# and day of week (dow) or use '*' in these fields (for 'any').#
# Notice that tasks will be started based on the cron's system
# daemon's notion of time and timezones.
#
# Output of the crontab jobs (including errors) is sent through
# email to the user the crontab file belongs to (unless redirected).
#
# For example, you can run a backup of all your user accounts
# at 5 a.m every week with:
# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/
#
# For more information see the manual pages of crontab(5) and cron(8)
#
# m h  dom mon dow   command
```

Above is just the header. Add a new cron job, syntax is descripted in the header. For example, I want the script to be executed each 7 min

`*/7 * * * * /home/hd1/test/scripts/upload_to_ftp.sh > /dev/null 2>&1`

The most IMPORTANT step. Start crond daemon.

`/usr/sbin/crond -b`

Check if crond run
```
# ps | grep crond
  868 root      1704 S    grep crond
 1422 root      1728 S    /usr/sbin/crond -b
```

The second important step. Add the command to start crond daemon into `/tmp/hd1/test/equip_test.sh` (after line `led $(get_config LED_WHEN_READY)`). This step helps to ensure that crond is started after camera rebooting.
