#!/bin/bash

INSTALLER_URL='https://metascanbucket.s3.amazonaws.com/Metadefender/Core/v4/4.17.0.1-1/centos/ometascan-4.17.0.1-1.x86_64.rpm'
INSTALLER_FILE=$(basename "${INSTALLER_URL}")
BOOT_SCRIPT=/home/ec2-user/metadefender_config.sh
CRON_SCRIPT=/etc/cron.d/metadefender

sudo yum update -y
sudo yum install jq -y
cd /home/ec2-user
wget ${INSTALLER_URL}
sudo yum install -y ${INSTALLER_FILE}

BOOT_SCRIPT_FILE=/home/ec2-user/metadefender_config.sh

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

DEFAULT_USR=admin
DEFAULT_PWD=admin
REST_PORT=8008

until `curl --output /dev/null --silent --head --fail http://localhost:${REST_PORT}`
do 
    sleep 3;
done

INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
SESSION_ID=`curl -s -H "Content-Type: application/json" -X POST -d "{\"user\":\"${DEFAULT_USR}\",\"password\":\"${DEFAULT_PWD}\"}" http://localhost:${REST_PORT}/login | jq .session_id | sed "s/\"//g"`
RESPONSE=`curl -s -H "Content-Type: application/json" -H "apikey: ${SESSION_ID}" -X POST -d "{\"old_password\":\"${DEFAULT_PWD}\",\"new_password\":\"${INSTANCE_ID}\"}" http://localhost:${REST_PORT}/user/changepassword | jq .result | sed "s/\"//g"`

if [[ "${RESPONSE}" == "Successful" ]]; then
    sudo rm -rf /etc/cron.d/metadefender
    sudo rm -rf /home/ec2-user/metadefender_config.sh
    echo "MetaDefender: default password \"${DEFAULT_PWD}\" changed to \"${INSTANCE_ID}\"" >> /home/ec2-user/metadefender-init.log
fi;
EOF

sudo rm -f /home/ec2-user/.ssh/authorized_keys
sudo chmod 555 ${BOOT_SCRIPT_FILE}
