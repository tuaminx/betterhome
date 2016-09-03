#!/bin/sh

SCRIPT_DIR="/tmp/hd1/test/scripts"

# ----------------------------
ftp_dir="/path/to/folder/on/ftp"
ftp_host="192.168.1.something"
ftp_port="21"
ftp_login="ftp_username"
ftp_pass="ftp_password"
ftp_mem_file="$SCRIPT_DIR/ftp_upload/ftp_upload.mem"
ftp_log_dir="$SCRIPT_DIR/ftp_upload/log"
pid_file="$SCRIPT_DIR/ftp_upload/ftp_upload.pid"
# ----------------------------

record_dir="/tmp/hd1/record/"

max_d01=31
max_d02=28
max_d03=31
max_d04=30
max_d05=31
max_d06=30
max_d07=31
max_d08=31
max_d09=30
max_d10=31
max_d11=30
max_d12=31

is_server_live()
{
    ping -c1 -W2 $1 > /dev/null
    return $?
}

is_pid_exist()
{
    count=$(ps | grep $1 | wc -l)
    if [ $count -gt 1 ]; then
       return 0
    fi
    return 1
}

pid_store()
{
    echo $1 > ${2-"$pid_file"}
}

pid_get()
{
    cat ${1-"$pid_file"}
}

pid_clear()
{
    cat /dev/null > ${1-"$pid_file"}
}

log()
{
   echo $2 $1 | svlogd -tt ${3-"$ftp_log_dir"}
   #echo $2 "$(date +'%Y%m%d.%H%M%S') $1" >> $ftp_log_file
}

mem_store()
{
   last_folder=$1
   last_file=$2
   echo "${last_folder}/${last_file}" > ${1-"$ftp_mem_file"}
}

mem_get()
{
   mfile=${1-"$ftp_mem_file"}
   last_folder=$(cat ${mfile} | cut -d'/' -f1)
   last_file=$(cat ${mfile} | cut -d'/' -f2)
   if [ -z "${last_folder}" ] || [ -z "${last_file}" ]; then
      log "[SCR] Cannot find last folder and file in $mfile"
      log "[SRC] The file should content as: 2016Y08M01D13H/23M00S.mp4"
      exit 1
   fi
}

ftp_get_pasv_port()
{
   user=${1-"$ftp_login"}
   pass=${2-"$ftp_pass"}
   fdir=${3-"$ftp_dir"}
   fhost=${4-"$ftp_host"}
   fport=${5-"$ftp_port"}

   ret=`(sleep 1
         echo "USER ${user}"
         sleep 1
         echo "PASS ${pass}"
         sleep 1
         echo "CWD ${fdir}"
         sleep 1
         echo "PASV"
         sleep 1
         echo "LIST"
         sleep 1
         echo "QUIT"
         sleep 1) | telnet ${fhost} ${fport}`
   ret=$(echo $ret | sed -n 's/.*(\(.*\)).*/\1/p')
   #echo $ret
   a=$(echo $ret | cut -d',' -f5)
   b=$(echo $ret | cut -d',' -f6)
   echo $((a * 256 + b))
}

ftp_get_return()
{
   port=$1
   tmp_f=$2
   telnet ${ftp_host} ${port} > $tmp_f 2>&1
}

ftp_mkd()
{
   user=${2-"$ftp_login"}
   pass=${3-"$ftp_pass"}
   fdir=${4-"$ftp_dir"}
   fhost=${5-"$ftp_host"}
   fport=${6-"$ftp_port"}
   logdir=${7-"$ftp_log_dir"}

   (sleep 1;
    echo "USER ${user}";
    sleep 1;
    echo "PASS ${pass}";
    sleep 1;
    echo "MKD ${fdir}/$1";
    sleep 1;
    echo "QUIT";
    sleep 1 ) | telnet ${fhost} ${fport} 2>&1 | svlogd -tt $logdir
}

ftp_upload()
{
   user=${3-"$ftp_login"}
   pass=${4-"$ftp_pass"}
   fdir=${5-"$ftp_dir"}
   fhost=${6-"$ftp_host"}
   fport=${7-"$ftp_port"}
   logdir=${8-"$ftp_log_dir"}

   from_f=$1
   to_f=$2
   ftpput -u ${user} -p ${pass} -P ${fport} ${fhost} \
          ${fdir}/${to_f} ${from_f} 2>&1 | svlogd -tt $logdir
   return $?
}

is_leap_year()
{
   year=$1
   if [ $((year % 400)) -eq 0 ]; then
      return 0
   elif [ $((year % 4)) -eq 0 ] && [ $((year % 100)) -ne 0 ]; then
      return 0
   else
      return 1
   fi
}

main()
{

   last_folder=""
   last_file=""

   # Here we goooooo!
   is_server_live $ftp_host
   if [ $? -ne 0 ]; then
      log "[SRC] $ftp_host is unreachable!!!"
      pid_clear
      exit 1
   fi
   log "[SRC] $ftp_host is reachable"

   mem_get
   log "[SRC] last folder: $last_folder last file: $last_file"

   last_y=$(echo $last_folder | cut -d'Y' -f1)
   last_m=$(echo $last_folder | cut -d'M' -f1 | cut -d'Y' -f2)
   last_d=$(echo $last_folder | cut -d'D' -f1 | cut -d'M' -f2)
   last_h=$(echo $last_folder | cut -d'H' -f1 | cut -d'D' -f2)
   last_i=$(echo $last_file | cut -d'M' -f1)
   last_s=$(echo $last_file | cut -d'S' -f1 | cut -d'M' -f2)
   #echo $last_folder
   #echo $last_file
   #echo "$last_y$last_m$last_d-$last_h:$last_i:$last_s"

   now_h=$(date +"%H")
   now_m=$(date +"%m")
   now_d=$(date +"%d")
   now_y=$(date +"%Y")

   cont_last=1
   is_leap_year last_y
   if [ $? -eq 0 ]; then
      max_d02=29
   fi

   while [ 1 -eq 1 ]; do
      if [ -d "${record_dir}${last_folder}" ]; then
         cd "${record_dir}${last_folder}"
         list_file=$(ls)
         if [ -n "$list_file" ]; then
            log "[FTP] Create ${last_folder}"
            ftp_mkd ${last_folder}
            if [ $cont_last -eq 1 ]; then
               cont_last=0
            else
               last_i="00"
               last_s="00"
            fi

         fi
         for file in $list_file; do
            #log $file
            if [ $(echo $file | grep tmp | wc -l) -gt 0 ]; then
               log "[SRC] Skip tmp file"
               continue
            fi
            this_i=$(echo $file | cut -d'M' -f1)
            this_s=$(echo $file | cut -d'S' -f1 | cut -d'M' -f2)
            if [ "${this_i}${this_s}" -gt "${last_i}${last_s}" ]; then
               log "[FTP] Uploading ${last_folder}/${file}"
               ftp_upload ${record_dir}/${last_folder}/${file} ${last_folder}/${file}
               mem_store ${last_folder} ${file}
               if [ $? -ne 0 ]; then
                  log "[FTP] FAILED"
                  exit 1
               fi
               last_file=$file
            fi
         done
      fi
      if [ $(expr match "$last_h" '0*') -gt 0 ]; then
         last_h=${last_h:1}
      fi
      last_h=$(printf %02d $((last_h + 1)))
      if [ $last_h -gt 23 ]; then
         last_h=00
         if [ $(expr match "$last_d" '0*') -gt 0 ]; then
            last_d=${last_d:1}
         fi
         last_d=$(printf %02d $((last_d + 1)))
      fi
      eval max_d='$max_d'$last_m
      if [ $last_d -gt $max_d ]; then
         last_d=01
         if [ $(expr match "$last_m" '0*') -gt 0 ]; then
            last_m=${last_m:1}
         fi
         last_m=$(printf %02d $((last_m + 1)))
      fi
      if [ $last_m -gt 12 ]; then
         last_m=01
         last_y=$((last_y + 1))
         is_leap_year $last_y
         if [ $? -eq 0 ]; then
            max_d02=29
         else
            max_d02=28
         fi
      fi
      if [ "${last_y}${last_m}${last_d}${last_h}" -gt "${now_y}${now_m}${now_d}${now_h}" ]; then
         #mem_store $last_folder $last_file
         break
      fi
      last_folder="${last_y}Y${last_m}M${last_d}D${last_h}H"
      log "[SRC] Next folder: $last_folder"
   done
   pid_clear
}

info_check()
{
   mess=$1
   echo -en "[....] $mess"
}

info_ok()
{
   echo -e "\r[.OK.]"
}

info_fail()
{
   mess=$1
   reason=$2
   echo -e "\r[FAIL] ${mess}: $reason"
}

setup()
{
   number_keep_day=10
   title="Create mem file. Start upload videos of last $number_keep_day days"
   info_check "$title"
   mem_file_content=$(date -D %s -d $(( $(date +%s) - ((86400 * $number_keep_day)) )) +'%YY%mM%dD00H/00M00S.mp4')
   echo $mem_file_content > "$ftp_mem_file"
   if [ $? -eq 0 ]; then
      info_ok
   else
      info_fail "$title" "Cannot CREATE $ftp_mem_file"
   fi

   title="Create Log dir"
   info_check "$title"
   if [ -r "$ftp_log_dir" ]; then
      info_ok
   else
      mkdir -p "$ftp_log_dir"
      if [ $? -eq 0 ]; then
         info_ok
      else
         info_fail "$title" "Cannot CREATE $ftp_log_dir"
      fi
   fi

   title="Create PID file"
   info_check "$title"
   if [ -r "$pid_file" ]; then
      info_ok
   else
      touch "$pid_file"
      if [ $? -eq 0 ]; then
         info_ok
      else
         info_fail "$title" "Cannot CREATE $pid_file"
      fi
   fi

   title="Create crontabs dir"
   info_check "$title"
   if [ -r "/var/spool/cron/crontabs" ]; then
      info_ok
   else
      mkdir -p "/var/spool/cron/crontabs"
      if [ $? -eq 0 ]; then
         info_ok
      else
         info_fail "$title" "Cannot CREATE /var/spool/cron/crontabs"
      fi
   fi

   title="Create cron job"
   info_check "$title"
   if [ ! -r "/var/spool/cron/crontabs/root" ]; then
      # Empty crontab file
      cat <<EOF > "/var/spool/cron/crontabs/root"
# cat /var/spool/cron/crontabs/root
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

EOF
   fi

   if [ $(crontab -l | grep -e "^#.*upload_to_ftp.sh" | wc -l) -lt 1 ] && [ $(crontab -l | grep "upload_to_ftp.sh" | wc -l) -gt 0 ]; then
      info_ok
   else
      echo "*/7 * * * * $SCRIPT_DIR/upload_to_ftp.sh >/dev/null 2>&1" >> "/var/spool/cron/crontabs/root"
      if [ $? -eq 0 ]; then
         info_ok
      else
         info_fail "$title" "Cannot CREATE cron job. Please do yourself by crontab -e"
      fi
   fi

   title="Start crond daemon"
   info_check "$title"
   if [ $(ps | pgrep crond | wc -l) -gt 0 ]; then
      info_ok
   else
      /usr/sbin/crond -b
      if [ $? -eq 0 ]; then
         info_ok
      else
         info_fail "$title" "Cannot start /usr/sbin/crond -b"
      fi
   fi

   echo '[WARN] Please add command "/usr/sbin/crond -b" into a line upper "led $(get_config LED_WHEN_READY)" in "/tmp/hd1/test/equip_test.sh" by yourself.'
   echo '[INFO] After above done, let use "upload_to_ftp.sh status"'

}

check_status()
{
   title="Check mem file"
   info_check "$title"
   if [ -r "$ftp_mem_file" ]; then
      info_ok
   else
      info_fail "$title" "Cannot READ $ftp_mem_file"
   fi

   title="Check log directory"
   info_check "$title"
   if [ -r "$ftp_log_dir" ]; then
      info_ok
   else
      info_fail "$title" "Cannot FIND $ftp_log_dir. Please mkdir -p $ftp_log_dir"
   fi

   title="Check crontabs directory"
   info_check "$title"
   if [ -d "/var/spool/cron/crontabs" ]; then
      info_ok
   else
      info_fail "$title" "crontabs NOT FOUND. Please: mkdir -p /var/spool/cron/crontabs"
   fi

   title="Check crond daemon"
   info_check "$title"
   if [ $(ps | pgrep crond | wc -l) -gt 0 ]; then
      info_ok
   else
      info_fail "$title" "crond daemon OFFLINE. Please: /usr/sbin/crond -b"
   fi

   title="Check cron job existence"
   info_check "$title"
   if [ $(crontab -l | grep upload_to_ftp.sh | wc -l) -gt 0 ]; then
      info_ok
   else
      info_fail "$title" "Cron job NOT FOUND. Please: crontab -e"
   fi

   title="Check cron job usability"
   info_check "$title"
   if [ $(crontab -l | grep -e "^#.*$SCRIPT_DIR/upload_to_ftp.sh" | wc -l) -lt 1 ]; then
      info_ok
   else
      info_fail "$title" "Cron job DISABLED. Please: crontab -e and remove #"
   fi

   title="Check FTP server $ftp_host"
   info_check "$title"
   is_server_live "$ftp_host"
   if [ $? -eq 0 ]; then
      info_ok
   else
      info_fail "$title" "FTP $ftp_host is UNREACHABLE"
   fi
}

#
# Start the main script
#

# Check and accept 1 parameter only
if [ "$#" -gt 1 ]; then
   echo "[FAIL] Just 1 parameter is supported!"
   echo -e "\n$0\n\nUsage:"
   echo -e "\t setup\tSetup for usage"
   echo -e "\t status\tCheck working status"
   echo -e "\nBefore \"setup\" please edit configuration in the top of $0"
   exit 1
fi

# Process for parameter and stop script
if [ "$1" == "status" ]; then
   check_status
   exit 0
elif [ "$1" == "setup" ]; then
   setup
   exit 0
fi

#
# For non-parameter, the main function is started
#
last_pid=$(pid_get)

if [ -n "$last_pid" ]; then
   is_pid_exist $last_pid
   if [ $? -eq 0 ]; then
      exit 0
   else
      log "[SRC] $last_pid is not existed. Start new"
      pid_clear
   fi
fi

main &

pid_store $!

