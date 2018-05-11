#!/bin/bash

INSTALLER_URL='https://s3-us-west-1.amazonaws.com/metascanbucket/Metadefender/Core/v4/4.10.0-1/centos/ometascan-4.10.0-1.x86_64.rpm'
INSTALLER_FILE=$(basename "${INSTALLER_URL}")
BOOT_SCRIPT=${HOME}/metadefender_config.sh
CRON_SCRIPT=/etc/cron.d/metadefender

sudo yum update -y
sudo yum install jq -y
wget ${INSTALLER_URL}
sudo yum install -y ${INSTALLER_FILE}

BOOT_SCRIPT_FILE=${HOME}/metadefender_config.sh

sudo touch ${BOOT_SCRIPT_FILE}
sudo touch ${CRON_SCRIPT}

sudo chmod 707 ${CRON_SCRIPT}
sudo chmod 707 ${BOOT_SCRIPT_FILE}

sudo cat << EOF > ${CRON_SCRIPT}
@reboot ec2-user ${BOOT_SCRIPT_FILE}
EOF
sudo chmod 0644 ${CRON_SCRIPT}

cat << 'EOF' > ${BOOT_SCRIPT_FILE}
#!/bin/bash
LOCKFILE=${HOME}/.pwd-ch
DEFAULT_USR=admin
DEFAULT_PWD=admin
REST_PORT=8008
if [ ! -f "${LOCKFILE}" ]; then
    while ! nc -z localhost ${REST_PORT} </dev/null;
        do sleep 10;
    done
    INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
    SESSION_ID=`curl -s -H "Content-Type: application/json" -X POST -d "{\"user\":\"${DEFAULT_USR}\",\"password\":\"${DEFAULT_PWD}\"}" http://localhost:${REST_PORT}/login | jq .session_id | sed "s/\"//g"`
    RESPONSE=`curl -s -H "Content-Type: application/json" -H "apikey: ${SESSION_ID}" -X POST -d "{\"old_password\":\"${DEFAULT_PWD}\",\"new_password\":\"${INSTANCE_ID}\"}" http://localhost:${REST_PORT}/user/changepassword | jq .result | sed "s/\"//g"`

    if [[ "${RESPONSE}" == "Successful" ]]; then
        touch ${LOCKFILE}
    fi;
else
    exit 0
fi;
EOF

sudo chmod 555 ${BOOT_SCRIPT_FILE}
