#!/bin/bash -p

# EMBA - EMBEDDED LINUX ANALYZER
#
# Copyright 2022 Siemens AG
# Copyright 2022-2024 Siemens Energy AG
#
# EMBA comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# EMBA is licensed under GPLv3
#
# Author(s): Pascal Eckmann
# Contributor(s): Michael Messner

# Description: Show stats about EMBA run on the bottom of the terminal window

# helper for box drawing
repeat_char(){
  local REP_CHAR="${1:-}"
  local REP_COUNT="${2:-0}"
  local RET=""
  local A=0
  for ((A=1; A<=REP_COUNT; A++)) ; do RET+="${REP_CHAR}"; done
  echo -e "${RET}"
}

draw_box() {
  local BOX_W="${1:-0}"
  local BOX_TITLE="${2:-}"
  BOX_TITLE=" ${BOX_TITLE} "
  local BOX_L="${3:-0}"
  local BOX=""
  BOX+="\e[$((LINES - 4));${BOX_L}f┌\033[1m${BOX_TITLE}\033[0m$(repeat_char "─" "$((BOX_W - "${#BOX_TITLE}" - 2))")┐"
  BOX+="\e[$((LINES - 3));${BOX_L}f│""$(repeat_char " " "$((BOX_W - 2))")""│"
  BOX+="\e[$((LINES - 2));${BOX_L}f│$(repeat_char " " "$((BOX_W - 2))")│"
  BOX+="\e[$((LINES - 1));${BOX_L}f│$(repeat_char " " "$((BOX_W - 2))")│"
  BOX+="\e[${LINES};${BOX_L}f└$(repeat_char "─" "$((BOX_W - 2))")┘"
  echo -e "${BOX}"
}

draw_arrows() {
  local ARROW_L="${1:-0}"
  local ARROWS=""
  ARROWS+="\e[$((LINES - 3));${ARROW_L}f \033[1m>\033[0m"
  ARROWS+="\e[$((LINES - 2));${ARROW_L}f \033[1m>\033[0m"
  ARROWS+="\e[$((LINES - 1));${ARROW_L}f \033[1m>\033[0m"
  echo -e "${ARROWS}"
}

# Helper first box "SYSTEM LOAD"
# we have three lines per box and here we build the string for each line ($2=line)
# Because we have to draw a colored bar, we need the percentage of the cpu load ($1)
system_load_util_str() {
  local PERCENTAGE="${1:-0}"
  local UTIL_TYPE_NO="${2:-0}"
  local UTIL_TYPES=('CPU  ' 'MEM  ' 'DISK ')
  local UTIL_STR="${UTIL_TYPES[${UTIL_TYPE_NO}]}"
  local UTIL_BAR_COLOR=""
  local UTIL_BAR_BLANK=""
  local UTIL_PERCENTAGE=$(("${PERCENTAGE}"/(100/12)))

  local A=0
  local BAR_COUNT=0
  for ((A=1; A<=UTIL_PERCENTAGE; A++)) ; do
    UTIL_BAR_COLOR+="■"
    BAR_COUNT=$((BAR_COUNT + 1))
  done

  local B=0
  local B_LEN=$((12-BAR_COUNT))
  for ((B=1; B<=B_LEN; B++)) ; do
    UTIL_BAR_BLANK+="■"
  done

  if [[ ${BAR_COUNT} -gt 8 ]] ; then
    UTIL_BAR_COLOR="\033[31m${UTIL_BAR_COLOR}\033[0m"
  elif [[ ${BAR_COUNT} -gt 4 ]] ; then
    UTIL_BAR_COLOR="\033[33m${UTIL_BAR_COLOR}\033[0m"
  else
    UTIL_BAR_COLOR="\033[32m${UTIL_BAR_COLOR}\033[0m"
  fi

  PERCENTAGE+=""
  if [[ ${#PERCENTAGE} -gt 2 ]] ; then
    PERCENTAGE="${PERCENTAGE}%"
  elif [[ ${#PERCENTAGE} -gt 1 ]] ; then
    PERCENTAGE=" ${PERCENTAGE}%"
  else
    PERCENTAGE="  ${PERCENTAGE}%"
  fi

  echo -e "${UTIL_STR}${UTIL_BAR_COLOR}${UTIL_BAR_BLANK} ${PERCENTAGE}"
}

# Update first box "SYSTEM LOAD"
# we need to use the tmp file for the cpu load, because it takes about a second to get the information and therefore we
# load this information in the background, write it to the file in a rythm of .2s and when needed, it will be readed from it
update_box_system_load() {
  update_cpu() {
    local CPU_LOG_STR_=""
    CPU_LOG_STR_="$(system_load_util_str "$((100-"$(vmstat 1 2 | tail -1 | awk '{print $15}')"))" 0 2> /dev/null || true)"
    if [[ -f "${STATUS_TMP_PATH}" ]] ; then
      sed -i "2s/.*/${CPU_LOG_STR_}/" "${STATUS_TMP_PATH}" 2> /dev/null || true
    fi
  }

  update_cpu

  local BOX_SIZE=0
  if [[ -f "${STATUS_TMP_PATH}" ]] ; then
    BOX_SIZE="$(sed '1q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
  fi
  while [[ "${BOX_SIZE}" -gt 0 ]]; do
    local MEM_PERCENTAGE_STR=""
    MEM_PERCENTAGE_STR="$(system_load_util_str "$(LANG=en free | grep Mem | awk '{print int($3/$2 * 100)}')" 1)"
    local DISK_PERCENTAGE_STR=""
    DISK_PERCENTAGE_STR="$(system_load_util_str "$(df "${LOG_DIR}" | tail -1 | awk '{print substr($5, 1, length($5)-1)}')" 2)"
    local ACTUAL_CPU=0
    if [[ -f "${STATUS_TMP_PATH}" ]] ; then
      ACTUAL_CPU="$(sed '2q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
    else
      ACTUAL_CPU=0
    fi
    printf '\e[s\e[%s;3f%s\e[%s;3f%s\e[%s;3f%s\e[u' "$(( LINES - 3 ))" "${ACTUAL_CPU}" "$(( LINES - 2 ))" "${MEM_PERCENTAGE_STR}" "$(( LINES - 1 ))" "${DISK_PERCENTAGE_STR}" || true
    update_cpu &
    sleep .2
    if [[ -f "${STATUS_TMP_PATH}" ]] ; then
      BOX_SIZE="$(sed '1q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
    fi
  done
}

# Helper second box "STATUS"
# we have three lines per box and here we build the string for each line ($1=line)
status_util_str() {
  local UTIL_TYPE_NO="${1:-0}"
  local UTIL_TYPES=('RUN' 'LOG_DIR' 'PROCESSES')
  local UTIL_STR="${UTIL_TYPES[${UTIL_TYPE_NO}]}"
  local UTIL_VALUE="${2:-}"
  local UTIL_BAR_BLANK=""

  local UTIL_LEN=$((22-"${#UTIL_STR}"-"${#UTIL_VALUE}"))
  local U=0
  for ((U=1; U<=UTIL_LEN; U++)) ; do
    UTIL_BAR_BLANK+=" "
  done

  echo -e "${UTIL_STR}${UTIL_BAR_BLANK}${UTIL_VALUE}"
}

# Update second box "STATUS"
# we need to use the tmp file for the start time point, because the content of the boxes will be refreshed in the background
update_box_status() {
  local DATE_STR=""
  if [[ -f "${STATUS_TMP_PATH}" ]] ; then
    DATE_STR="$(sed '3q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
  fi
  if [[ "${DATE_STR}" == "" ]] ; then
    DATE_STR="$(date +%s)"
    if [[ -f "${STATUS_TMP_PATH}" ]] ; then
      sed -i "3s/^$/${DATE_STR}/" "${STATUS_TMP_PATH}" 2> /dev/null || true
    fi
  fi

  local LOG_DIR_SIZE=""
  local RUN_EMBA_PROCESSES=0
  local RUN_EMBA_PROCESSES_QUEST=0

  local BOX_SIZE=0
  if [[ -f "${STATUS_TMP_PATH}" ]] ; then
    BOX_SIZE="$(sed '1q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
  fi
  while [[ "${BOX_SIZE}" -gt 0 ]]; do
    local RUNTIME=0
    RUNTIME="$(date -d@"$(( "$(date +%s)" - "${DATE_STR}" ))" -u +%H:%M:%S)"
    LOG_DIR_SIZE="$(du -sh "${LOG_DIR}" 2> /dev/null | cut -d$'\t' -f1 2> /dev/null || true)"
    # if we are running in a docker environment, we can count the processes withing our containers:
    if [[ -n "${MAIN_CONTAINER}" ]]; then
      RUN_EMBA_PROCESSES="$(docker exec "${MAIN_CONTAINER_}" ps 2>/dev/null | wc -l || true)"
      RUN_EMBA_PROCESSES_QUEST="$(docker exec "${QUEST_CONTAINER}" ps 2>/dev/null | wc -l || true)"
      RUN_EMBA_PROCESSES=$((RUN_EMBA_PROCESSES + RUN_EMBA_PROCESSES_QUEST))
    else
      # this is a dirty solution if we have not MAIN_CONTAINER set
      # this happens in dev mode or in non silent mode -> but in both modes
      # the status bar is not supported
      RUN_EMBA_PROCESSES="$(ps -C emba | wc -l || true)"
    fi
    printf '\e[s\e[%s;29f%s\e[%s;29f%s\e[%s;29f%s\e[u' "$(( LINES - 3 ))" "$(status_util_str 0 "${RUNTIME}")" "$(( LINES - 2 ))" "$(status_util_str 1 "${LOG_DIR_SIZE}")" "$(( LINES - 1 ))" "$(status_util_str 2 "${RUN_EMBA_PROCESSES}")" || true
    sleep .5
    if [[ -f "${STATUS_TMP_PATH}" ]] ; then
      BOX_SIZE="$(sed '1q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
    fi
  done
}

# Helper third box "MODULES"
# we have three lines per box and here we build the string for each line ($1=line)
# we also need to show a value: $2
module_util_str() {
  local UTIL_TYPE_NO="${1:-0}"
  local UTIL_TYPES=('RUNNING' 'LAST FINISHED' 'PROGRESS')
  local UTIL_STR="${UTIL_TYPES[${UTIL_TYPE_NO}]}"
  local UTIL_VALUE="${2:-}"
  local UTIL_BAR_BLANK=""

  local UTIL_LEN=$((22-"${#UTIL_STR}"-"${#UTIL_VALUE}"))
  local U=0
  for ((U=1; U<=UTIL_LEN; U++)) ; do
    UTIL_BAR_BLANK+=" "
  done

  echo -e "${UTIL_STR}${UTIL_BAR_BLANK}${UTIL_VALUE}"
}

# Update third box "MODULES"
update_box_modules() {
  local STARTED_MODULE_STR=""
  local FINISHED_MODULE_STR=""
  local LAST_FINISHED_MODULE_STR=""
  local COUNT_MODULES=0
  local MODULES=()
  local MODULES_LOCAL=()
  local MODULES_EMBA=()
  local MODULE_FILE=""

  if [[ -f "${STATUS_TMP_PATH}" ]] ; then
    COUNT_MODULES="$(sed '4q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
  fi
  if [[ ${COUNT_MODULES} -eq 0 || "${COUNT_MODULES}" == "" ]] ; then
    mapfile -t MODULES_EMBA < <(find "${MOD_DIR}" -maxdepth 1 -name "*.sh" 2> /dev/null)
    if [[ -d "${MOD_DIR_LOCAL}" ]]; then
      mapfile -t MODULES_LOCAL < <(find "${MOD_DIR_LOCAL}" -maxdepth 1 -name "*.sh" 2> /dev/null)
    fi
    MODULES=( "${MODULES_EMBA[@]}" "${MODULES_LOCAL[@]}" )
    for MODULE_FILE in "${MODULES[@]}" ; do
      if ( file "${MODULE_FILE}" | grep -q "shell script" ) && ! [[ "${MODULE_FILE}" =~ \ |\' ]] ; then
        (( COUNT_MODULES+=1 ))
      fi
    done
    if [[ -f "${STATUS_TMP_PATH}" ]] ; then
      sed -i "4s/^$/${COUNT_MODULES}/" "${STATUS_TMP_PATH}" 2> /dev/null || true
    fi
  fi

  local BOX_SIZE=0
  if [[ -f "${STATUS_TMP_PATH}" ]] ; then
    BOX_SIZE="$(sed '1q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
  fi
  while [[ "${BOX_SIZE}" -gt 0 ]]; do
    STARTED_MODULE_STR="$(grep -c "starting" "${LOG_DIR}/emba.log" 2> /dev/null || true )"
    FINISHED_MODULE_STR="$(grep "finished" "${LOG_DIR}/emba.log" 2> /dev/null | grep -vc "Quest container finished" || true )"
    LAST_FINISHED_MODULE_STR="$(grep "finished" "${LOG_DIR}/emba.log" 2> /dev/null | grep -v "Quest container finished"| tail -1 | awk '{print $9}' | cut -d"_" -f1 || true )"
    printf '\e[s\e[%s;55f%s\e[%s;55f%s\e[%s;55f%s\e[u' "$(( LINES - 3 ))" "$(module_util_str 0 "$((STARTED_MODULE_STR - FINISHED_MODULE_STR))")" "$(( LINES - 2 ))" "$(module_util_str 1 "${LAST_FINISHED_MODULE_STR}")" "$(( LINES - 1 ))" "$(module_util_str 2 "${FINISHED_MODULE_STR}/${COUNT_MODULES}")" || true
    sleep 1
    if [[ -f "${STATUS_TMP_PATH}" ]] ; then
      BOX_SIZE="$(sed '1q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
    fi
  done
}

# Helper fourth box "STATUS 2"
# we have three lines per box and here we build the string for each line ($1=line)
# we also need to show a value: $2
status_2_util_str() {
  local UTIL_TYPE_NO="${1:-0}"
  local UTIL_TYPES=('PHASE' 'MODE' '')
  local UTIL_STR="${UTIL_TYPES[${UTIL_TYPE_NO}]}"
  local UTIL_VALUE="${2:-}"
  local UTIL_BAR_BLANK=""

  local UTIL_LEN=$((22-"${#UTIL_STR}"-"${#UTIL_VALUE}"))
  local U=0
  for ((U=1; U<=UTIL_LEN; U++)) ; do
    UTIL_BAR_BLANK+=" "
  done

  echo -e "${UTIL_STR}${UTIL_BAR_BLANK}${UTIL_VALUE}"
}

# Update fourth box "STATUS 2"
update_box_status_2() {
  local PHASE_STR=""
  local MODE_STR=""
  if [[ ${USE_DOCKER} -eq 0 && ${IN_DOCKER} -eq 0 ]] ; then
    MODE_STR+="DEV/"
  elif [[ ${STRICT_MODE} -eq 1 ]] ; then
    MODE_STR+="STRICT"
  else
    MODE_STR+="DEFAULT"
  fi
  local ERROR_STR=0
  local BOX_SIZE=0
  if [[ -f "${STATUS_TMP_PATH}" ]] ; then
    BOX_SIZE="$(sed '1q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
  fi
  while [[ "${BOX_SIZE}" -gt 0 ]]; do
    PHASE_STR=$(grep 'phase started' "${LOG_DIR}/emba.log" 2> /dev/null | tail -1 | cut -d"-" -f2 | awk '{print $1}' || true)
    ERROR_STR="/$(grep -c 'Error detected' "${LOG_DIR}/emba_error.log" 2> /dev/null || true )"
    if [[ "${ERROR_STR}" == "/0" || "${ERROR_STR}" == "/" ]] ; then
      ERROR_STR=""
    fi
    printf '\e[s\e[%s;81f%s\e[%s;81f%s\e[%s;81f%s\e[u' "$(( LINES - 3 ))" "$(status_2_util_str 0 "${PHASE_STR}")" "$(( LINES - 2 ))" "$(status_2_util_str 1 "${MODE_STR}${ERROR_STR}")" "$(( LINES - 1 ))" "$(status_2_util_str 2 "")" || true
    sleep .5
    if [[ -f "${STATUS_TMP_PATH}" ]] ; then
      BOX_SIZE="$(sed '1q;d' "${STATUS_TMP_PATH}" 2> /dev/null || true)"
    fi
  done
}

remove_status_bar() {
  if [[ -f "${STATUS_TMP_PATH:-}" ]] ; then
    sed -i "1s/.*/0/" "${STATUS_TMP_PATH}" 2> /dev/null || true
  fi
  sleep 1
  local LINE_POS=""
  LINE_POS="$(( LINES - 6 ))"
  local RM_STR=""
  RM_STR="\e[""${LINE_POS}"";1f\e[0J\e[;r\e[""${LINE_POS}"";1f"
  printf "%b" "${RM_STR}"
}

box_updaters() {
  # start threaded updater
  # echo "PID_SYSTEM_LOAD: ${PID_SYSTEM_LOAD}" >> "${TMP_DIR}"/pids_to_kill.log
  # echo "PID_STATUS: ${PID_STATUS}" >> "${TMP_DIR}"/pids_to_kill.log
  # echo "PID_MDOULES: ${PID_MODULES}" >> "${TMP_DIR}"/pids_to_kill.log
  # echo "PID_STATUS_2: ${PID_STATUS_2}" >> "${TMP_DIR}"/pids_to_kill.log
  if [[ -z "${PID_SYSTEM_LOAD}" && ${STATUS_BAR_BOX_COUNT} -gt 0 ]] ; then
    update_box_system_load &
    export PID_SYSTEM_LOAD="$!"
    echo "${PID_SYSTEM_LOAD}" > "${TMP_DIR}"/PID_SYSTEM_LOAD.log
  elif [[ -n "${PID_SYSTEM_LOAD}" && ${STATUS_BAR_BOX_COUNT} -le 0 ]] ; then
    kill_box_pid "${PID_SYSTEM_LOAD}" &
    export PID_SYSTEM_LOAD=""
    rm "${TMP_DIR}"/PID_SYSTEM_LOAD.log || true
  fi
  if [[ -z "${PID_STATUS}" && ${STATUS_BAR_BOX_COUNT} -gt 1 ]] ; then
    update_box_status &
    export PID_STATUS="$!"
    echo "${PID_STATUS}" > "${TMP_DIR}"/PID_STATUS.log
  elif [[ -n "${PID_STATUS}" && ${STATUS_BAR_BOX_COUNT} -le 1 ]] ; then
    kill_box_pid "${PID_STATUS}" &
    export PID_STATUS=""
    rm "${TMP_DIR}"/PID_STATUS.log || true
  fi
  if [[ -z "${PID_MODULES}" && ${STATUS_BAR_BOX_COUNT} -gt 2 ]] ; then
    update_box_modules &
    export PID_MODULES="$!"
    echo "${PID_MODULES}" > "${TMP_DIR}"/PID_MODULES.log
  elif [[ -n "${PID_MODULES}" && ${STATUS_BAR_BOX_COUNT} -le 2 ]] ; then
    kill_box_pid "${PID_MODULES}" &
    export PID_MODULES=""
    rm "${TMP_DIR}"/PID_MODULES.log || true
  fi
  if [[ -z "${PID_STATUS_2}" && ${STATUS_BAR_BOX_COUNT} -gt 3 ]] ; then
    update_box_status_2 &
    export PID_STATUS_2="$!"
    echo "${PID_STATUS_2}" > "${TMP_DIR}"/PID_STATUS_2.log
  elif [[ -n "${PID_STATUS_2}" && ${STATUS_BAR_BOX_COUNT} -le 3 ]] ; then
    kill_box_pid "${PID_STATUS_2}" &
    export PID_STATUS_2=""
    rm "${TMP_DIR}"/PID_STATUS_2.log || true
  fi
}

kill_box_pid() {
  local PID="${1:-}"
  # echo "$PID" >> "${TMP_DIR}"/pids_to_kill.txt
  if ! [[ -e /proc/"${PID}" ]]; then
    return
  fi
  while [[ -e /proc/"${PID}" ]]; do
    # print_output "[*] wait pid protection - running pid: $PID"
    kill -9 "${PID}" 2>/dev/null || true
  done
}

initial_status_bar() {
  # PID for box updater threads
  export PID_SYSTEM_LOAD=""
  [[ -f "${TMP_DIR}"/PID_SYSTEM_LOAD.log ]] && export PID_SYSTEM_LOAD="$(cat "${TMP_DIR}"/PID_SYSTEM_LOAD.log)"
  export PID_STATUS=""
  [[ -f "${TMP_DIR}"/PID_STATUS.log ]] && export PID_STATUS="$(cat "${TMP_DIR}"/PID_STATUS.log)"
  export PID_MODULES=""
  [[ -f "${TMP_DIR}"/PID_MODULES.log ]] && export PID_MODULES="$(cat "${TMP_DIR}"/PID_MODULES.log)"
  export PID_STATUS_2=""
  [[ -f "${TMP_DIR}"/PID_STATUS_2.log ]] && export PID_STATUS_2="$(cat "${TMP_DIR}"/PID_STATUS_2.log)"

  # Path to status tmp file
  # each line is dedicated to a specific function
  # 1: Count of boxes visible
  # 2: CPU load string (needs to be cached, because it takes about a second to get the information)
  # 3: Start time of status bar - not exactly the same as the EMBA timer, but near enough to get an idea
  # 4: Count modules
  export STATUS_TMP_PATH=""

  # overwrites $LINES and "${COLUMNS}" with the actual values of the window
  # shopt -s checkwinsize; (:;:)
  shopt -s checkwinsize
  # echo "LINES: $LINES" >> "${TMP_DIR}"/shopts.log
  # echo "COLUMNS: $COLUMNS" >> "${TMP_DIR}"/shopts.log

  local LINE_POS="$(( LINES - 6 ))"
  printf "\e[%s;1f\e[0J\e[%s;1f" "${LINE_POS}" "${LINE_POS}"

  # we need to restart our foreground logging:
  pkill -f "tail.*-f ${LOG_DIR}/emba.log" 2>/dev/null || true
  if ! [[ -f "${LOG_DIR}"/emba.log ]]; then
    touch "${LOG_DIR}"/emba.log
  fi
  reset && clear
  tail -n 500 -f "${LOG_DIR}"/emba.log &
  local TAIL_PID="$!"
  disown "${TAIL_PID}" 2> /dev/null || true

  # create new tmp file with empty lines
  STATUS_TMP_PATH="${TMP_DIR}/status"
  if [[ ! -f "${STATUS_TMP_PATH}" && -d "${TMP_DIR}" ]] ; then
    echo -e "\\n\\n\\n\\n" > "${STATUS_TMP_PATH}"
  fi
  # calculate boxes fitting and draw them
  local INITIAL_STR=""
  INITIAL_STR="\e[${LINE_POS};1f\e[0J\e[0;${LINE_POS}r\e[${LINE_POS};1f"
  if [[ ${LINES} -gt 10 ]] ; then
    # column has to be increased with 2 characters because of possible arrow column
    local ARROW_POS=0
    STATUS_BAR_BOX_COUNT=0
    if [[ ${COLUMNS} -ge 27 ]] ; then
      INITIAL_STR+="$(draw_box 26 "SYSTEM LOAD" 0)"
      STATUS_BAR_BOX_COUNT=1
      ARROW_POS=27
    fi
    if [[ ${COLUMNS} -ge 54 ]] ; then
      INITIAL_STR+="$(draw_box 26 "STATUS" 27)"
      STATUS_BAR_BOX_COUNT=2
      ARROW_POS=53
    fi
    if [[ ${COLUMNS} -ge 80 ]] ; then
      INITIAL_STR+="$(draw_box 26 "MODULES" 53)"
      STATUS_BAR_BOX_COUNT=3
      ARROW_POS=79
    fi
    if [[ ${COLUMNS} -ge 104 ]] ; then
      INITIAL_STR+="$(draw_box 26 "STATUS 2" 79)"
      STATUS_BAR_BOX_COUNT=4
    fi

    if [[ ${STATUS_BAR_BOX_COUNT} -lt 4 ]] ; then
      INITIAL_STR+="$(draw_arrows "${ARROW_POS}")"
    fi
  fi
  if [[ -f "${STATUS_TMP_PATH}" ]] ; then
    sed -i "1s/.*/${STATUS_BAR_BOX_COUNT}/" "${STATUS_TMP_PATH}" 2> /dev/null || true
  fi
  INITIAL_STR+="\e[H"
  # set cursor and boxes
  printf "%b" "${INITIAL_STR}"
  box_updaters
}
