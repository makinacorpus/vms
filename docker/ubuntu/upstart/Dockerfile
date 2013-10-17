#
# Ubuntu with a debuggable upstart
#
FROM makinacorpus/ubuntu
ENV prefix /testing
ADD postinst.sh /postinst.sh
RUN apt-get install -y --force-yes gdb strace build-essential m4 libtool pkg-config autoconf gettext bzip2 groff man-db automake libsigc++-2.0-dev tcl8.5 git bzr;\
    apt-get build-dep upstart libnih1 &&\
    mkdir $prefix
RUN sed -re "s/precise/raring/g" -i /etc/apt/sources.list && apt-get update && apt-get install libjson0-dev &&\
    sed -re "s/raring/precise/g" -i /etc/apt/sources.list && apt-get update
RUN cd $prefix && bzr branch lp:libnih && bzr branch lp:upstart
RUN export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig:$PKG_CONFIG_PATH" &&\
    export ACDIR="${prefix}/share/aclocal:$ACDIR" &&\
    export CFLAGS="-g -fstack-protector --param=ssp-buffer-size=4 -Wformat  -Werror=format-security -ggdb3 -fno-inline" &&\
    cd libnih && ./configure --disable-silent-rules --enable-compiler-warnings \
        --disable-compiler-optimisations --disable-linker-optimisations \
        --enable-compiler-coverage && make && make install
RUN export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig:$PKG_CONFIG_PATH" &&\
    export ACDIR="${prefix}/share/aclocal:$ACDIR" &&\
    export CFLAGS="-g -fstack-protector --param=ssp-buffer-size=4 -Wformat  -Werror=format-security -ggdb3 -fno-inline" &&\
    cd upstart && ./configure --disable-silent-rules --enable-compiler-warnings \
        --disable-compiler-optimisations --disable-linker-optimisations \
        --enable-compiler-coverage && make && make install
CMD ["/sbin/init"]
