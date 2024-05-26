#!/firmadyne/sh

# Copyright (c) 2015 - 2016, Daming Dominic Chen
# Copyright (c) 2017 - 2020, Mingeun Kim, Dongkwan Kim, Eunsoo Kim
# Copyright (c) 2022 - 2024 Siemens Energy AG
#
# This script is based on the original scripts from the firmadyne and firmAE project
# Original firmadyne project can be found here: https://github.com/firmadyne/firmadyne
# Original firmAE project can be found here: https://github.com/pr0v3rbs/FirmAE

BUSYBOX=/firmadyne/busybox

# "${BUSYBOX}" touch /firmadyne/EMBA_service_init_done
ORANGE="\033[0;33m"
NC="\033[0m"

"${BUSYBOX}" echo -e "${ORANGE}[*] Starting services in emulated environment...${NC}"
"${BUSYBOX}" cat /firmadyne/service

if ("${EMBA_ETC}"); then
  # first, the system should do the job by itself
  # after 100sec we jump in with our service helpers
  "${BUSYBOX}" echo -e "${ORANGE}[*] Waiting 60sec before helpers starting services in emulated environment...${NC}"
  "${BUSYBOX}" sleep 60
  # some rules we need to apply for different services:
  if "${BUSYBOX}" grep -q lighttpd /firmadyne/service; then
    # ensure we have the pid file for lighttpd:
    "${BUSYBOX}" echo "[*] Creating pid directory for lighttpd service"
    "${BUSYBOX}" mkdir -p /var/run/lighttpd 2>/dev/null
  fi
  if "${BUSYBOX}" grep -q twonkystarter /firmadyne/service; then
    mkdir -p /var/twonky/twonkyserver 2>/dev/null
  fi

  while (true); do
    while IFS= read -r _BINARY; do
      "${BUSYBOX}" sleep 5
      BINARY_NAME=$("${BUSYBOX}" echo "${_BINARY}" | "${BUSYBOX}" cut -d\  -f1)
      BINARY_NAME=$("${BUSYBOX}" basename "${BINARY_NAME}")
      "${BUSYBOX}" echo -e "${NC}[*] Environment details ..."
      "${BUSYBOX}" echo -e "\tEMBA_ETC: ${EMBA_ETC}"
      "${BUSYBOX}" echo -e "\tEMBA_BOOT: ${EMBA_BOOT}"
      "${BUSYBOX}" echo -e "\tEMBA_NET: ${EMBA_NET}"
      "${BUSYBOX}" echo -e "\tFIRMAE_NVRAM: ${FIRMAE_NVRAM}"
      "${BUSYBOX}" echo -e "\tEMBA_KERNEL: ${EMBA_KERNEL}"
      "${BUSYBOX}" echo -e "\tEMBA_NC: ${EMBA_NC}"
      "${BUSYBOX}" echo -e "\tBINARY_NAME: ${BINARY_NAME}"
      "${BUSYBOX}" echo -e "\tKernel details: $("${BUSYBOX}" uname -a)"
      "${BUSYBOX}" echo -e "\tSystem uptime: $("${BUSYBOX}" uptime)"
      "${BUSYBOX}" echo -e "\tSystem environment: $("${BUSYBOX}" env)"
      "${BUSYBOX}" echo "[*] Netstat output:"
      "${BUSYBOX}" netstat -antu
      "${BUSYBOX}" echo "[*] Network configuration:"
      "${BUSYBOX}" brctl show
      "${BUSYBOX}" ifconfig -a
      "${BUSYBOX}" echo "[*] Running processes:"
      "${BUSYBOX}" ps
      "${BUSYBOX}" echo "[*] /proc filesytem:"
      "${BUSYBOX}" ls /proc

      if ( ! ("${BUSYBOX}" ps | "${BUSYBOX}" grep -v grep | "${BUSYBOX}" grep -sqi "${BINARY_NAME}") ); then
        if [ "${BINARY_NAME}" = "netcat" ] && ! [ "${EMBA_NC}" = "true" ]; then
          "${BUSYBOX}" echo "[*] Netcat starter bypassed ... ${BINARY_NAME}"
          # we only start our netcat listener if we set EMBA_NC_STARTER on startup (see run.sh script)
          # otherwise we move on to the next binary starter
          continue
        fi
        "${BUSYBOX}" echo -e "${NC}[*] Starting ${ORANGE}${BINARY_NAME}${NC} service ..."
        #BINARY variable could be something like: binary parameter parameter ...
        ${_BINARY} &
      else
        "${BUSYBOX}" echo -e "${NC}[*] ${ORANGE}${BINARY_NAME}${NC} already started ..."
      fi
    done < "/firmadyne/service"
  done
fi

