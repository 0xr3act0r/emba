# Copyright (c) 2015 - 2016, Daming Dominic Chen
# Copyright (c) 2017 - 2020, Mingeun Kim, Dongkwan Kim, Eunsoo Kim
# Copyright (c) 2022 - 2024 Siemens Energy AG

# shellcheck disable=SC2148
BUSYBOX="/busybox"

ORANGE="\033[0;33m"
NC="\033[0m"

# This script is based on the original FirmAE inferFile.sh script 
# This script supports multiple startup services, colored output
# and more services

"${BUSYBOX}" echo "[*] EMBA inferService script starting ..."

"${BUSYBOX}" echo "[*] Service detection running ..."

# The manual starter can be used to write startup scripts manually and help
# EMBA getting into the right direction
# This script must be placed directly into the filesystem as /etc/manual.starter
if [ -e /etc/manual.starter ]; then
  if ! "${BUSYBOX}" grep -q "/etc/manual.starter" /firmadyne/service 2>/dev/null; then
    "${BUSYBOX}" echo -e "[*] Writing EMBA service for ${ORANGE}manual starter service${NC}"
    "${BUSYBOX}" echo -e -n "/etc/manual.starter\n" >> /firmadyne/service
  fi
fi

for SERVICE in $("${BUSYBOX}" find /etc/init.d/ -name "*httpd*"); do
  if [ -e "${SERVICE}" ]; then
    if ! "${BUSYBOX}" grep -q "${SERVICE}" /firmadyne/service 2>/dev/null; then
      "${BUSYBOX}" echo -e "[*] Writing EMBA service for ${ORANGE}${SERVICE} service${NC}"
      "${BUSYBOX}" echo -e -n "${SERVICE} start\n" >> /firmadyne/service
    fi
  fi
done

for SERVICE in $("${BUSYBOX}" find /etc/rc.d/ -name "S*httpd*"); do
  if [ -e "${SERVICE}" ]; then
    if ! "${BUSYBOX}" grep -q "${SERVICE}" /firmadyne/service 2>/dev/null; then
      "${BUSYBOX}" echo -e "[*] Writing EMBA service for ${ORANGE}${SERVICE} service${NC}"
      "${BUSYBOX}" echo -e -n "${SERVICE} start\n" >> /firmadyne/service
    fi
  fi
done

if [ -e /etc/init.d/ftpd ]; then
  if ! "${BUSYBOX}" grep -q ftpd /firmadyne/service 2>/dev/null; then
    "${BUSYBOX}" echo -e "[*] Writing EMBA service for ${ORANGE}ftpd service${NC}"
    "${BUSYBOX}" echo -e -n "/etc/init.d/ftpd start\n" >> /firmadyne/service
  fi
fi

if [ -e /bin/boa ]; then
  if ! "${BUSYBOX}" grep -q boa /firmadyne/service 2>/dev/null; then
    "${BUSYBOX}" echo -e "[*] Writing EMBA service for ${ORANGE}/bin/boa${NC}"
    "${BUSYBOX}" echo -e -n "/bin/boa\n" >> /firmadyne/service
  fi
fi

if [ -e /etc/init.d/miniupnpd ]; then
  if ! "${BUSYBOX}" grep -q "/etc/init.d/miniupnpd" /firmadyne/service 2>/dev/null; then
    "${BUSYBOX}" echo -e "[*] Writing EMBA service for ${ORANGE}miniupnpd service${NC}"
    "${BUSYBOX}" echo -e -n "/etc/init.d/miniupnpd start\n" >> /firmadyne/service
  fi
fi


# Some examples for testing:
# mini_httpd: F9K1119_WW_1.00.01.bin
# twonkystarter: F9K1119_WW_1.00.01.bin

for BINARY in $("${BUSYBOX}" find / -name "lighttpd" -type f -o -name "upnp" -type f -o -name "upnpd" -type f \
  -o -name "telnetd" -type f -o -name "mini_httpd" -type f -o -name "miniupnpd" -type f -o -name "mini_upnpd" -type f \
  -o -name "twonkystarter" -type f -o -name "httpd" -type f -o -name "goahead" -type f -o -name "alphapd" -type f \
  -o -name "uhttpd" -type f -o -name "miniigd" -type f -o -name "ISS.exe" -type f -o -name "ubusd" -type f \
  -o -name "wscd" -type f -o -name "ftpd" -type f -o -name "11N_UDPserver" -type f); do

  if [ -x "${BINARY}" ]; then
    SERVICE_NAME=$("${BUSYBOX}" basename "${BINARY}")
    # entry for lighttpd:
    if [ "$("${BUSYBOX}" echo "${SERVICE_NAME}")" == "lighttpd" ]; then
      # check if this service is already in the service file:
      # if ! "${BUSYBOX}" grep -q "${SERVICE_NAME}" /firmadyne/service 2>/dev/null; then
        # check if we have a configuration available and iterate
        for LIGHT_CONFIG in $("${BUSYBOX}" find / -name "*lighttpd*.conf" -type f); do
          # write the service starter with config file
          "${BUSYBOX}" echo -e "[*] Writing EMBA starter for ${ORANGE}${BINARY} - ${LIGHT_CONFIG}${NC}"
          "${BUSYBOX}" echo -e -n "${BINARY} -f ${LIGHT_CONFIG}\n" >> /firmadyne/service
        done
      # fi
    elif [ "$("${BUSYBOX}" echo "${SERVICE_NAME}")" == "miniupnpd" ]; then
      if ! "${BUSYBOX}" grep -q "${SERVICE_NAME}" /firmadyne/service 2>/dev/null; then
        for MINIUPNPD_CONFIG in $("${BUSYBOX}" find / -name "*miniupnpd*.conf" -type f); do
          "${BUSYBOX}" echo -e "[*] Writing EMBA starter for ${ORANGE}${BINARY} - ${MINIUPNPD_CONFIG}${NC}"
          "${BUSYBOX}" echo -e -n "${BINARY} -f ${MINIUPNPD_CONFIG}\n" >> /firmadyne/service
        done
      fi
    elif [ "$("${BUSYBOX}" echo "${SERVICE_NAME}")" == "wscd" ]; then
      if ! "${BUSYBOX}" grep -q "${SERVICE_NAME}" /firmadyne/service 2>/dev/null; then
        for WSCD_CONFIG in $("${BUSYBOX}" find / -name "*wscd*.conf" -type f); do
          "${BUSYBOX}" echo -e "[*] Writing EMBA starter for ${ORANGE}${BINARY} - ${WSCD_CONFIG}${NC}"
          "${BUSYBOX}" echo -e -n "${BINARY} -c ${WSCD_CONFIG}\n" >> /firmadyne/service
        done
      fi
    elif [ "$("${BUSYBOX}" echo "${SERVICE_NAME}")" == "upnpd" ]; then
      if ! "${BUSYBOX}" grep -q "${SERVICE_NAME}" /firmadyne/service 2>/dev/null; then
        "${BUSYBOX}" echo -e "[*] Writing EMBA starter for ${ORANGE}${BINARY}${NC}"
        "${BUSYBOX}" echo -e -n "${BINARY}\n" >> /firmadyne/service

        # let's try upnpd with a basic configuration:
        "${BUSYBOX}" echo -e "[*] Writing EMBA starter for ${ORANGE}${BINARY} ppp0 eth0${NC}"
        "${BUSYBOX}" echo -e -n "${BINARY} ppp0 eth0\n" >> /firmadyne/service
      fi
    elif [ "$("${BUSYBOX}" echo "${SERVICE_NAME}")" == "ftpd" ]; then
      if ! "${BUSYBOX}" grep -q "${SERVICE_NAME}" /firmadyne/service 2>/dev/null; then
        "${BUSYBOX}" echo -e "[*] Writing EMBA starter for ${ORANGE}${BINARY}${NC}"
        "${BUSYBOX}" echo -e -n "${BINARY} -D\n" >> /firmadyne/service
      fi
    fi
    # this is the default case - without config but only if the service is not already in the service file
    if ! "${BUSYBOX}" grep -q "${SERVICE_NAME}" /firmadyne/service 2>/dev/null; then
      "${BUSYBOX}" echo -e "[*] Writing EMBA starter for ${ORANGE}${BINARY}${NC}"
      "${BUSYBOX}" echo -e -n "${BINARY}\n" >> /firmadyne/service
    fi

    # other rules we need to apply
    if [ "$("${BUSYBOX}" echo "${SERVICE_NAME}")" == "twonkystarter" ]; then
      "${BUSYBOX}" mkdir -p /var/twonky/twonkyserver
    fi
  fi
done

"${BUSYBOX}" sort -u -o /firmadyne/service /firmadyne/service

"${BUSYBOX}" echo "[*] EMBA inferService script finished ..."
