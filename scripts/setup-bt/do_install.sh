#!/bin/bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

install_path=/www/server/panel/plugin/oryx
SRS_HOME=/usr/local/oryx
DATA_HOME=/data

# Update sysctl.conf and add if not exists. For example:
#   update_sysctl net.ipv4.ip_forward 1 0 "# Controls IP packet forwarding"
function update_sysctl() {
    SYSCTL_KEY=$1 && SYSCTL_VALUE=$2 && SYSCTL_EMPTY_LINE=$3 && SYSCTL_COMMENTS=$4
    echo "Update with sysctl $SYSCTL_KEY=$SYSCTL_VALUE, empty-line=$SYSCTL_EMPTY_LINE, comment=$SYSCTL_COMMENTS"

    grep -q "^${SYSCTL_KEY}[ ]*=" /etc/sysctl.conf
    if [[ $? == 0 ]]; then
      sed -i "s/^${SYSCTL_KEY}[ ]*=.*$/${SYSCTL_KEY} = ${SYSCTL_VALUE}/g" /etc/sysctl.conf
    else
      if [[ $SYSCTL_EMPTY_LINE == 1 ]]; then echo '' >> /etc/sysctl.conf; fi &&
      if [[ $SYSCTL_COMMENTS != '' ]]; then echo "$SYSCTL_COMMENTS" >> /etc/sysctl.conf; fi &&
      echo "${SYSCTL_KEY} = ${SYSCTL_VALUE}" >> /etc/sysctl.conf
    fi
    if [[ $? -ne 0 ]]; then echo "Failed to sysctl $SYSCTL_KEY = $SYSCTL_VALUE $SYSCTL_COMMENTS"; exit 1; fi

    RESULT=$(grep "^${SYSCTL_KEY}[ ]*=" /etc/sysctl.conf)
    echo "Update done: ${RESULT}"
}

Install() {
  echo "Installing to $install_path, pwd: $(pwd)"

  source do_os.sh
  if [[ $? -ne 0 ]]; then echo "Setup OS failed"; exit 1; fi

  chmod +x $install_path/mgmt/bootstrap
  if [[ $? -ne 0 ]]; then echo "Set mgmt bootstrap permission failed"; exit 1; fi

  # Move oryx to its home.
  echo "Link oryx to $SRS_HOME"
  rm -rf $SRS_HOME && mkdir $SRS_HOME &&
  ln -sf $install_path/mgmt $SRS_HOME/mgmt &&
  ln -sf $install_path/usr $SRS_HOME/usr
  if [[ $? -ne 0 ]]; then echo "Link oryx failed"; exit 1; fi

  # Create global data directory.
  echo "Create data and config file"
  mkdir -p ${DATA_HOME}/config && touch ${DATA_HOME}/config/.env &&
  touch ${DATA_HOME}/config/nginx.http.conf ${DATA_HOME}/config/nginx.server.conf
  if [[ $? -ne 0 ]]; then echo "Create /data/config failed"; exit 1; fi

  # Allow network forwarding, required by docker.
  # See https://stackoverflow.com/a/41453306/17679565
  echo "Controls IP packet forwarding"
  update_sysctl net.ipv4.ip_forward 1 1 "# Controls IP packet forwarding"

  # Setup the UDP buffer for WebRTC and SRT.
  # See https://www.jianshu.com/p/6d4a89359352
  echo "Setup kernel UDP buffer"
  update_sysctl net.core.rmem_max 16777216 1 "# For RTC/SRT over UDP"
  update_sysctl net.core.rmem_default 16777216
  update_sysctl net.core.wmem_max 16777216
  update_sysctl net.core.wmem_default 16777216

  # Now, we're ready to install by BT.
  echo 'Wait for oryx plugin ready...'; sleep 1.3;
  touch ${install_path}/.bt_ready

  echo 'Install OK'
}

Uninstall() {
  if [[ -f /etc/init.d/oryx ]]; then /etc/init.d/oryx stop; fi
  echo "Stop oryx service ok"

  INIT_D=/etc/init.d/oryx && rm -f $INIT_D
  echo "Remove init.d script $INIT_D ok"

  if [[ -f /usr/lib/systemd/system/oryx.service ]]; then
    systemctl disable oryx
    rm -f /usr/lib/systemd/system/oryx.service
    systemctl daemon-reload
    systemctl reset-failed
  fi
  echo "Remove oryx.service ok"

  INSTALL_HOME=/usr/local/oryx
  rm -rf $INSTALL_HOME
  echo "Remove install $INSTALL_HOME ok"

  rm -f ~/credentials.txt
  echo "Remove credentials.txt"

  rmdir /usr/local/lighthouse/softwares 2>/dev/null
  rmdir /usr/local/lighthouse 2>/dev/null
  echo "Remove empty lighthouse directory"

  rm -rf $install_path/* ${install_path}/.bt_ready
  rmdir $install_path 2>/dev/null
  echo "Remove plugin path $install_path ok"

  LOGS=$(ls /tmp/oryx_install.* 2>/dev/null)
  if [[ ! -z $LOGS ]]; then rm -f $LOGS; fi
  echo "Remove install flag files $LOGS ok"
}

if [ "${1}" == 'install' ];then
	Install
elif [ "${1}" == 'uninstall' ];then
	Uninstall
else
	echo 'Error!'; exit 1;
fi

