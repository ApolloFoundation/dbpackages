#!/bin/bash
echo_error()   { echo $'\E[1m\E[31m' "Error: " $'\E[22m\E[39m'$@ ; }
exit_error()   { echo_error $@ ; exit 1; }
print_help(){
cat <<__ENDHELP__
Usage: $0 [OPTIONS]
Apollo Foundation. Install mariadb package.

  --apl-basedir path   The path to the ApolloWallet installation directory.
  --apl-db-dir path    The path to the Apollo data base directory.

  -u|--user user_name  The login username to use for running mariadbd or system user by default.
  -p|--port port       The MariaDb daemon port. The default port is 3366.
  -h|--help            Show help message.

example:

./install-mariadb.sh --apl-db-dir /home/user/.apl-blockchain/apl-blockchain-db

__ENDHELP__
}

# "linux-gnu"*  - Linux 
# "cygwin"      - POSIX compatibility layer and Linux environment emulation for Windows
# "msys"        - Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
# "win32"
# "freebsd"*
if [[ "$OSTYPE" == "darwin"* ]]; then
# Mac OSX
  BASE_DIR=$(cd "`dirname "$0"`"; pwd -P)
  sed_i_opt="-i '.bak'"
else
  BASE_DIR=$(dirname $(readlink -e "$0"))
  sed_i_opt="-i"
fi

cmd_params=$@
#if [[ $# -lt 2 ]]; then
#  echo "Wrong parameters count."
#  print_help
#  exit 1
#fi

db_port="3366"
db_user=${USER}
apl_base_dir_param=""
apl_db_dir_param=""

while [ -n "$1" ]; do
    case $1 in
        --apl-basedir)
            shift
            apl_base_dir_param=$1
        ;;
        --apl-db-dir)
            shift
            apl_db_dir_param=$1
        ;;
        -p|--port)
            shift
            db_port=$1
        ;;
        -u|--user)
            shift
            db_user=$1
        ;;
        -h|--help)
            print_help
            exit 1
        ;;
        *)
            print_help
            exit 1
        ;;
    esac
    shift
done


#check parameters
if [[ -n ${apl_base_dir_param} ]]; then
  apl_base_dir=${apl_base_dir_param}
else
  apl_base_dir=${BASE_DIR%/*}
fi

if [[ -n ${apl_db_dir_param} ]]; then
  apl_db_dir=${apl_db_dir_param}
else
  apl_db_dir="${apl_base_dir}/apl-blockchain-db"
fi

apl_mariadb_pkg_dir="${apl_base_dir}/apollo-mariadb"
db_tmp_dir="${apl_db_dir}/tmp"
db_data_dir="${apl_db_dir}/data"
apl_mariadb_cnf_template_file="${apl_mariadb_pkg_dir}/conf/my-apl.cnf.template"
apl_mariadb_cnf_file="${apl_mariadb_pkg_dir}/conf/my-apl.cnf"
mariadb_install_script="${apl_mariadb_pkg_dir}/scripts/mariadb-install-db"
mariadb_create_user_sql="${apl_mariadb_pkg_dir}/scripts/create_user.sql"
#Get property value
#$1 properties file
#$2 property name
get_property_value() {
local properties_file=$1
local property=$2
  cat $properties_file | grep -o "$property\ *=[^ ]*"|sed 's/\"//g'|cut -d= -f2
}

check_mariadb_pkg() {
  [ ! -x ${mariadb_install_script} ] && exit_error "Executable script not found: ${mariadb_install_script}."
  [ ! -f ${apl_mariadb_cnf_template_file} ] && exit_error "Cnf template not found: ${apl_mariadb_cnf_template_file}."
}

#Patch the MariaDB configuration file
patch_mariadb_cnf() {
  local pattern

  cp ${apl_mariadb_cnf_template_file} ${apl_mariadb_cnf_file}

  sed ${sed_i_opt} -e "s/port=(.+)/port=${db_port}/g" ${apl_mariadb_cnf_file}

  pattern='${apl_db_dir}'
  sed ${sed_i_opt} -e "s|${pattern}|${apl_db_dir}|g" ${apl_mariadb_cnf_file}

  pattern='${db_data_dir}'
  sed ${sed_i_opt} -e "s|${pattern}|${db_data_dir}|g" ${apl_mariadb_cnf_file}

#  pattern='${db_tmp_dir}'
#  sed ${sed_i_opt} -e "s|${pattern}|${db_tmp_dir}|g" ${apl_mariadb_cnf_file}
#
  pattern='${apl_mariadb_pkg_dir}'
  sed ${sed_i_opt} -e "s|${pattern}|${apl_mariadb_pkg_dir}|g" ${apl_mariadb_cnf_file}

}

#Wait until service starting
#$1 service name
#
wait_dbserver_to_start() {
local servicename=$1
local count=0
local kwait=5

  while ! ${apl_mariadb_pkg_dir}/bin/mariadb --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} -s --skip-column-names -e 'select 1;' &> /dev/null; do
    sleep 1
    (( ++count > kwait )) && break
  done

  ${apl_mariadb_pkg_dir}/bin/mariadb --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} -s --skip-column-names -e 'select 1;' &> /dev/null
  [ ! $? -eq 0 ] && exit_error "MariaDB server not started."

}

#Kill service by name
#$1 service name
#
kill_service() {
local servicename=$1
local count=0
local attempts=10

  while pgrep -f "$servicename" &> /dev/null; do
    pkill -9 -f "$servicename"
    (( ++count > attempts )) && break
  done

}

check_root_execution() {
    local myuuid=$(id -un)
	[ "${myuuid}" == "root" ] && exit_error "This script should be run without root privileges"
}

create_dir() {
    [[ ! -d $db_tmp_dir ]] && mkdir -p "$db_tmp_dir"
    [[ ! -d $db_data_dir ]] && mkdir -p "$db_data_dir"
}

#Return log filename
#
logfile() {
    local lc=$1
    [ "$lc" != "" ] || lc="common"
    echo "$BASE_DIR/${lc}-$(date +%Y%m%d).log"
}

#Write message from stdin into log file and console at the same time
#Arguments.
#  $1 -  component name, base $0 for default.
#  $2 -  option, -l = don't write message to console.
#
writelog() {
    local comp=$(basename $0)
    local ml=""
    local lfile=""
    local p=$1

	if [[ ! $p = '-'* ]] ; then
		comp=$p
		shift
	fi

	ml=$1

    [ "$comp" = "" ] && comp=$(basename $0)

	lfile=$(logfile ${comp%.*})

    while read str ; do
		if [ "$ml" != "-l" ] ; then
	    	echo "$(date +%x_%X) :[$comp] - $str" | tee -a $lfile
   		else
			echo "$(date +%x_%X) :[$comp] - $str" >> $lfile
		fi
    done
}


##
## MAIN Entry point
##
check_root_execution

#stop the suspicious mariadbd pocess
kill_service "${apl_mariadb_cnf_file}"

echo "Script started at "`date "+%Y-%m-%d %H:%M:%S"` | writelog
echo "cmd: $0 $cmd_params" | writelog
echo "---" | writelog
echo "apl_base_dir=${apl_base_dir}" | writelog
echo "apl_db_dir=${apl_db_dir}" | writelog
echo "apl_conf_dir=${apl_conf_dir}" | writelog
echo "db_tmp_dir=${db_tmp_dir}" | writelog
echo "db_data_dir=${db_data_dir}" | writelog
echo "apl_mariadb_cnf_file=${apl_mariadb_cnf_file}" | writelog
echo "db_port=${db_port}" | writelog
echo "db_user=${db_user}" | writelog
echo "db_password=${db_user}" | writelog

echo "---" | writelog

check_mariadb_pkg

all_steps=8
curr_step=1

echo "$curr_step/$all_steps. Create directories"  | writelog
create_dir | writelog
curr_step=$((curr_step+1))

echo "$curr_step/$all_steps. Patch my-apl.cnf file"  | writelog
patch_mariadb_cnf | writelog
cat ${apl_mariadb_cnf_file}
curr_step=$((curr_step+1))

echo "$curr_step/$all_steps. Run mariadb-install-db script"  | writelog
echo "cmd: ${mariadb_install_script} --defaults-file=${apl_mariadb_cnf_file} --basedir=${apl_mariadb_pkg_dir} --verbose" | writelog
${mariadb_install_script} --defaults-file=${apl_mariadb_cnf_file} --basedir=${apl_mariadb_pkg_dir} --verbose | writelog
[ ! $? -eq 0 ] && exit_error "Execution error."
curr_step=$((curr_step+1))

echo "$curr_step/$all_steps. Start mariadb server"  | writelog
echo "cmd: ${apl_mariadb_pkg_dir}/bin/mariadbd --defaults-file=${apl_mariadb_cnf_file} --verbose &" | writelog
${apl_mariadb_pkg_dir}/bin/mariadbd --defaults-file=${apl_mariadb_cnf_file} --verbose &
[ ! $? -eq 0 ] && exit_error "Execution error."
curr_step=$((curr_step+1))

#wait until the DB server starting 
wait_dbserver_to_start

echo "$curr_step/$all_steps. Create new db user: apl"  | writelog
echo "cmd: ${apl_mariadb_pkg_dir}/bin/mariadb --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} -s < ${mariadb_create_user_sql}"  | writelog
${apl_mariadb_pkg_dir}/bin/mariadb --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} -s < ${mariadb_create_user_sql}
[ ! $? -eq 0 ] && exit_error "Execution error."
curr_step=$((curr_step+1))

echo "$curr_step/$all_steps. Check user privileges"  | writelog
echo "cmd: ${apl_mariadb_pkg_dir}/bin/mariadb --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} -s -e \"SHOW GRANTS FOR 'apl'@localhost;\" --skip-column-names mysql" | writelog
privileges=`${apl_mariadb_pkg_dir}/bin/mariadb --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} -s -e "SHOW GRANTS FOR 'apl'@localhost;" --skip-column-names mysql|grep 'GRANT ALL PRIVILEGES ON \*.\* TO \`apl\`@\`localhost\`'`
[ ! $? -eq 0 ] && exit_error "Execution error."
[ "X$privileges" == "X" ] && exit_error "Privileges wasn't set correctly for user: apl@localhost"
curr_step=$((curr_step+1))

echo "$curr_step/$all_steps. Change user password"  | writelog
echo "cmd: ${apl_mariadb_pkg_dir}/bin/mariadb-admin --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} password ${db_user}" | writelog
${apl_mariadb_pkg_dir}/bin/mariadb-admin --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} password ${db_user}
[ ! $? -eq 0 ] && exit_error "Execution error."
curr_step=$((curr_step+1))

echo "$curr_step/$all_steps. Check updated password"  | writelog
echo "cmd: ${apl_mariadb_pkg_dir}/bin/mariadb --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} -s -e \"select password from user where user=\"${db_user}\";\" --skip-column-names mysql" | writelog
password=`${apl_mariadb_pkg_dir}/bin/mariadb --defaults-file=${apl_mariadb_cnf_file} -u ${db_user} -s -e "select password from user where user=\"${db_user}\";" --skip-column-names mysql`
[ ! $? -eq 0 ] && exit_error "Execution error."
[ -z $password ] && exit_error "Unknown db user: ${db_user}"
[ "X$password" == "Xinvalid" ] && exit_error "Password wasn't set."
#echo "PASSWORD=$password"
curr_step=$((curr_step+1))

echo "Script done at "`date "+%Y-%m-%d %H:%M:%S"` | writelog

