FROM kalilinux/kali-rolling

COPY ./installer.sh /
COPY ./installer /installer
COPY ./helpers/helpers_emba_load_strict_settings.sh /installer/

WORKDIR /

# updates system
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install wget kmod procps sudo dialog apt curl git

# install EMBA, disable coredumps and final cleanup
RUN yes | sudo /installer.sh -s -D && \
    ulimit -c 0 && rm -rf /var/lib/apt/lists/*

WORKDIR /emba

# nosemgrep
ENTRYPOINT [ "/bin/bash" ]

