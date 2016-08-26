#!/bin/sh

# ----------------------------
ftp_dir="/path/to/folder/on/ftp"
ftp_host="192.168.1.1"
ftp_port="21"
ftp_login="ftp_username"
ftp_pass="ftp_password"
ftp_mem_file="/tmp/hd1/test/ftp_upload.mem"
ftp_log_file="/tmp/hd1/test/ftp_upload.log"
pid_file="/tmp/hd1/test/ftp_upload.pid"
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
    echo $1 > "$pid_file"
}

pid_get()
{
    cat $pid_file
}

pid_clear()
{
    cat /dev/null > $pid_file
}

log()
{
   echo $2 $1
   echo $2 "$(date +'%Y%m%d.%H%M%S') $1" >> $ftp_log_file
}

mem_store()
{
   last_folder=$1
   last_file=$2
   echo "${last_folder}/${last_file}" > $ftp_mem_file
}

mem_get()
{
   last_folder=$(cat ${ftp_mem_file} | cut -d'/' -f1)
   last_file=$(cat ${ftp_mem_file} | cut -d'/' -f2)
   if [ -z "${last_folder}" ] || [ -z "${last_file}" ]; then
      log "[SCR] Cannot find last folder and file in $ftp_mem_file"
      log "[SRC] The file should content as: 2016Y08M01D13H|23M00S.mp4"
      exit 1
   fi
}

ftp_get_pasv_port()
{
   ret=`(sleep 1
         echo "USER ${ftp_login}"
         sleep 1
         echo "PASS ${ftp_pass}"
         sleep 1
         echo "CWD ${ftp_dir}"
         sleep 1
         echo "PASV"
         sleep 1
         echo "LIST"
         sleep 1
         echo "QUIT"
         sleep 1) | telnet ${ftp_host} ${ftp_port}`
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
   (sleep 1;
    echo "USER ${ftp_login}";
    sleep 1;
    echo "PASS ${ftp_pass}";
    sleep 1;
    echo "MKD ${ftp_dir}/$1";
    sleep 1;
    echo "QUIT";
    sleep 1 ) | telnet ${ftp_host} ${ftp_port} >> $ftp_log_file
}

ftp_upload()
{
   from_f=$1
   to_f=$2
   ftpput -u ${ftp_login} -p ${ftp_pass} -P ${ftp_port} ${ftp_host} \
          ${ftp_dir}/${to_f} ${from_f} >> $ftp_log_file 2>&1
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
            if [ "${this_i}${this_s}" -eq "${last_i}${last_s}" ] || \
               [ "${this_i}${this_s}" -gt "${last_i}${last_s}" ]; then
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

last_pid=$(pid_get)
log "[SRC]--------------------"
log "[SRC] Last PID: $last_pid"

if [ -n "$last_pid" ]; then
   is_pid_exist $last_pid
   if [ $? -eq 0 ]; then
      log "[SRC] $last_pid is running. Stop!"
      exit 0
   else
      log "[SRC] $last_pid is not existed. Start new"
      pid_clear
   fi
fi

main > /dev/null &

pid_store $!

