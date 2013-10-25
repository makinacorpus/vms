#
# Ubuntu with a debuggable upstart
#
FROM makinacorpus/ubuntu
MAINTAINER Mathieu Le Marec Pasquet <kiorky@cryptelium.net>
ENV prefix /testing
RUN apt-get install -y --force-yes autopoint gdb strace build-essential m4 libtool pkg-config autoconf gettext bzip2 groff man-db automake libsigc++-2.0-dev tcl8.5 git bzr lxc;\
    apt-get build-dep -y --force-yes upstart libnih1 &&\
    mkdir $prefix ;\
    sed -re "s/precise/raring/g" -i /etc/apt/sources.list && apt-get update && \
    apt-get install -y --force-yes libjson0-dev procenv &&\
    sed -re "s/raring/precise/g" -i /etc/apt/sources.list && apt-get update
RUN cd $prefix && if [ ! -d libnih ];then bzr branch lp:libnih;fi
RUN cd $prefix && if [ ! -d upstart ];then bzr branch lp:upstart;fi
RUN export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig:$PKG_CONFIG_PATH" &&\
    export ACDIR="${prefix}/share/aclocal:$ACDIR" &&\
    export CFLAGS="-g -fstack-protector --param=ssp-buffer-size=4 -Wformat  -Werror=format-security -ggdb3 -fno-inline" &&\
    export LDFLAGS="-L/usr/local/lib -Wl,-rpath,/usr/local/lib" &&\
    cd $prefix/libnih && autoreconf -ifv && ./configure --disable-silent-rules --enable-compiler-warnings \
        --disable-compiler-optimisations --disable-linker-optimisations \
        --enable-compiler-coverage && make && make install
RUN export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig:$PKG_CONFIG_PATH" &&\
    export ACDIR="${prefix}/share/aclocal:$ACDIR" &&\
    export CFLAGS="-g -fstack-protector --param=ssp-buffer-size=4 -Wformat  -Werror=format-security -ggdb3 -fno-inline" &&\
    export LDFLAGS="-L/usr/local/lib -Wl,-rpath,/usr/local/lib" &&\
    cd $prefix/upstart && autoreconf -ifv && ./configure --disable-silent-rules --enable-compiler-warnings \
        --disable-compiler-optimisations --disable-linker-optimisations \
        --enable-compiler-coverage && make && make install

#   sed -re "s/(char \*\*args.*)$/\1printf(\"Waiting for gdb to attach 30 sec\\\n\");sleep(30);/g" -i $prefix/upstart/init/main.c &&\
#   echo "What we have done to wait:" &&\
#   grep -C4 sleep $prefix/upstart/init/main.c &&\

CMD ["/sbin/init"]
