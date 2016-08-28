# yi-hack-support
This is the supporting script for whom using hacked rom of Xiaomi Yi Smart camera

(https://github.com/fritz-smh/yi-hack)

# How to use:
## upload_to_ftp.sh

Copy `sd/test/scripts/upload_to_ftp.sh` to folder `test/scripts/` on SD card

Open file `test/scripts/upload_to_ftp.sh` on SD card and change the FTP server configuration:
```ftp_dir="/path/to/folder/on/ftp"
ftp_host="192.168.1.1"
ftp_port="21"
ftp_login="ftp_username"
ftp_pass="ftp_password"
```

Start the setup

WARNING: It's very IMPROTANT to execute the script with its full path `/tmp/hd1/test/scripts/upload_to_ftp.sh setup`
```
telnet <camera_ip>

# /tmp/hd1/test/scripts/upload_to_ftp.sh setup
[.OK.] Create mem file. Start upload videos of last 10 days
[.OK.] Create Log dir
[.OK.] Create PID file
[.OK.] Create crontabs dir
[.OK.] Create cron job
[.OK.] Start crond daemon
[WARN] Please add command "/usr/sbin/crond -b" into a line upper "led $(get_config LED_WHEN_READY)" in "/tmp/hd1/test/equip_test.sh" by yourself.
[INFO] After above done, let use "upload_to_ftp.sh status"
```

Check the status
```
# /tmp/hd1/test/scripts/upload_to_ftp.sh status
[.OK.] Check mem file
[.OK.] Check log directory
[.OK.] Check crontabs directory
[.OK.] Check crond daemon
[.OK.] Check cron job existence
[.OK.] Check cron job usability
[.OK.] Check FTP server 192.168.1.1
```

Add the command to start crond daemon into `/tmp/hd1/test/equip_test.sh` (above line `led $(get_config LED_WHEN_READY)`). This step helps to ensure that crond is started after camera rebooting.
