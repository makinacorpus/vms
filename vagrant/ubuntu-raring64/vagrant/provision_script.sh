#!/usr/bin/env bash
output() { echo "$@" >&2; }
die_if_error() {
    if [[ "$?" != "0" ]];then
        output "There were errors"
        exit 1
    fi
}
ready_to_run() {
    output " [*] VM is now ready for vagrant ssh or other usages..."
    output " 'You can upgrade all your projects with \"salt '*' state.highstate\""
    output " 'You can upgrade the base salt infrastructure with \"salt '*' state.sls setup\""
}
output " [*] STARTING MAKINA VAGRANT PROVISION SCRIPT: $0"
output " [*] You can safely relaunch this script from within the vm"
# source a maybe existing settings file
SETTINGS="${SETTINGS:-"/root/vagrant_provision_settings.sh"}"
if [ -f $SETTINGS ];then
    output " [*] Loading custom settings in $SETTINGS"
    . $SETTINGS
fi
PREFIX="${PREFIX:-"/srv"}"
VPREFIX="${PREFIX:-"$PREFIX/vagrant"}"
# Markers must not be on a shared folder for a new VM to be reprovisionned correctly
MARKERS="${MARKERS:-"/root/vagrant/markers"}"
DNS_SERVER="${DNS_SERVER:-"8.8.8.8"}"
PREVIOUS_OFFICIAL_MIRROR="${PREVIOUS_OFFICIAL_MIRROR:-"http://archive.ubuntu.com/ubuntu"}"
PREVIOUS_LOCAL_MIRROR="${PREVIOUS_LOCAL_MIRROR:-"http://fr.archive.ubuntu.com/ubuntu"}"
OFFICIAL_MIRROR="${OFFICIAL_MIRROR:-"http://archive.ubuntu.com/ubuntu"}"
LOCAL_MIRROR="${LOCAL_MIRROR:-"http://fr.archive.ubuntu.com/ubuntu"}"
UBUNTU_RELEASE="${UBUNTU_RELEASE:-"raring"}"
UBUNTU_NEXT_RELEASE="${UBUNTU_NEXT_RELEASE:-"saucy"}"
CHRONO="$(date "+%F_%H-%M-%S")"
# order is important
LXC_PKGS="lxc apparmor apparmor-profiles"
KERNEL_PKGS="linux-source linux-image-generic linux-headers-generic linux-image-extra-virtual"
VB_PKGS="virtualbox virtualbox-dkms virtualbox-source virtualbox-qt"
VB_PKGS="$VB_PKGS virtualbox-guest-additions-iso virtualbox-guest-dkms virtualbox-guest-source"
VB_PKGS="$VB_PKGS virtualbox-guest-utils virtualbox-guest-x11 virtualbox-guest-dkms"
kernel_marker="$MARKERS/provision_step_kernel${UBUNTU_NEXT_RELEASE}_done"
lxc_marker="$MARKERS/vbox_lxc_from_${UBUNTU_NEXT_RELEASE}.ok"
vbox_marker="$MARKERS/vbox_vbox_from_${UBUNTU_NEXT_RELEASE}.ok"
mirror_marker="$MARKERS/vbox_pkg_2_init_repos_${OFFICIAL_MIRROR//\//-}_${LOCAL_MIRROR//\//-}_${PREVIOUS_LOCAL_MIRROR//\//-}"
NEED_RESTART=""
export DEBIAN_FRONTEND="noninteractive"
# escape to 5 "antislash"
# http://www./#foo -> http:\/\/www\./\#foo
RE_PREVIOUS_OFFICIAL_MIRROR="$(echo "${PREVIOUS_OFFICIAL_MIRROR}" | sed -re "s/([.#/])/\\\\\1/g")"
RE_PREVIOUS_LOCAL_MIRROR="$(echo "${PREVIOUS_LOCAL_MIRROR}"       | sed -re "s/([.#/])/\\\\\1/g")"
RE_OFFICIAL_MIRROR="$(echo "${OFFICIAL_MIRROR}"                   | sed -re "s/([.#/])/\\\\\1/g")"
RE_LOCAL_MIRROR="$(echo "${LOCAL_MIRROR}"                         | sed -re "s/([.#/])/\\\\\1/g")"
RE_UBUNTU_RELEASE="$(echo "${UBUNTU_RELEASE}"                     | sed -re "s/([.#/])/\\\\\1/g")"
src_l="/etc/apt/sources.list"
# DNS TMP OVERRIDE
cat > /etc/resolv.conf << DNSEOF
nameserver ${DNS_SERVER}
nameserver 8.8.8.8
nameserver 4.4.4.4
DNSEOF
# cleanup old failed provisions
if [[ "$(grep "$UBUNTU_NEXT_RELEASE" ${src_l} | wc -l)" != "0" ]];then
    output " [*] Deactivating next-release($UBUNTU_NEXT_RELEASE) repos"
    sed -re "s/$UBUNTU_NEXT_RELEASE/$UBUNTU_RELEASE/g" -i ${src_l}
    apt-get update -qq
fi
for p in "$PREFIX" "$MARKERS";do
    if [[ ! -e $PREFIX ]];then
        mkdir -pv "$p"
    fi
done
if [ ! -e "$mirror_marker" ];then
    if [ ! -e "$MARKERS/vbox_pkg_1_initial_update" ];then
        # generate a proper commented /etc/apt/source.list
        output " [*] Initial upgrade"
        /usr/bin/cloud-init init
        /usr/bin/cloud-init modules --mode=config
        /usr/bin/cloud-init modules --mode=final
        cp "${src_l}" "${src_l}.${CHRONO}.sav" || die_if_error
        touch "$MARKERS/vbox_pkg_1_initial_update"
    fi
    output " [*] Activating some repos"
    sed -re "s/(.*deb(-src)?\s+)(${RE_PREVIOUS_OFFICIAL_MIRROR}|${RE_PREVIOUS_LOCAL_MIRROR}|${RE_OFFICIAL_MIRROR})(.*)/\1${RE_LOCAL_MIRROR}\4/g" -i ${src_l}
    sed -re "s/^(#|\s)*(deb(-src)?\s+[^ ]+\s+(precise|raring|${UBUNTU_NEXT_RELEASE}|${UBUNTU_RELEASE})(-(updates|backports|security))?)\s+(.*)/\2 \7/g" -i ${src_l}
    for rel in $UBUNTU_RELEASE ${UBUNTU_RELEASE}-updates;do
        for i in partner restricted universe multiverse main;do
            ADD_DEB=1
            ADD_DEBSRC=1
            if [[ "$i" == "partner" ]];then
                ADD_DEBSRC=""
                if [[ "$rel" != "$UBUNTU_RELEASE" ]];then
                    ADD_DEB=""
                fi
            fi
            if [[ ! "$(egrep "^deb\s+.*\s${rel}\s*$i" ${src_l}|wc -l)" == "0" ]];then
                ADD_DEB=""
            fi
            if [[ ! "$(egrep "^deb-src\s+.*\s${rel}\s*$i" ${src_l}|wc -l)" == "0" ]];then
                ADD_DEBSRC=""
            fi
            if [[ -n "$ADD_DEB" ]];then
                output " [*] Adding ${i}@${rel} to repos"
                echo "deb ${LOCAL_MIRROR} ${rel} $i" >> ${src_l}
            fi
            if [[ -n "$ADD_DEBSRC" ]];then
                output " [*] Adding ${i}(src)@${rel} to repos"
                echo "deb-src ${LOCAL_MIRROR} ${rel} $i" >> ${src_l}
            fi
        done
    done
    apt-get update -qq
    die_if_error
    touch "$mirror_marker"
fi
if [ ! -e "$MARKERS/vbox_init_global_upgrade" ];then
    output " [*] Upgrading base image"
    apt-get update -qq && apt-get upgrade -y && apt-get dist-upgrade -y
    die_if_error
    touch "$MARKERS/vbox_init_global_upgrade"
fi
if [ ! -e "$lxc_marker" ];then
    output " [*] Backporting Saucy LXC packages"
    sed -re "s/(precise|${UBUNTU_RELEASE})/${UBUNTU_NEXT_RELEASE}/g" -i "${src_l}" && \
    apt-get update -qq && \
    apt-get install -y --force-yes ${LXC_PKGS}
    die_if_error
    sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i "${src_l}" && apt-get update -qq
    die_if_error
    output " [*] The first time, you need to reload the new kernel and reprovision."
    output " [*] For that, issue now 'vagrant reload'"
    touch "$lxc_marker"
    NEED_RESTART=1
fi
if [ ! -e "$vbox_marker" ];then
    output " [*] Backporting Saucy Virtualbox packages"
    output " [*]   $VB_PKGS"
    sed -re "s/(precise|${UBUNTU_RELEASE})/${UBUNTU_NEXT_RELEASE}/g" -i ${src_l} &&\
    apt-get update -qq && apt-get install -y --force-yes $VB_PKGS
    die_if_error
    sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i ${src_l} && apt-get update -qq
    die_if_error
    output " [*] The first time, you need to reload the new kernel and reprovision."
    output " [*] For that, issue now 'vagrant reload'"
    touch "$vbox_marker"
    NEED_RESTART=1
fi
if [ ! -e "${kernel_marker}" ]; then
    output " [*] Backporting Saucy kernel ($KERNEL_PKGS)"
    sed -re "s/(precise|${UBUNTU_RELEASE})/${UBUNTU_NEXT_RELEASE}/g" -i ${src_l} &&\
    apt-get update -qq && apt-get install -y --force-yes $KERNEL_PKGS
    die_if_error
    sed -re "s/${UBUNTU_NEXT_RELEASE}/${UBUNTU_RELEASE}/g" -i ${src_l} && apt-get update -qq
    die_if_error
    output " [*] The first time, you need to reload the new kernel and reprovision."
    output " [*] For that, issue now 'vagrant reload'"
    touch "$kernel_marker"
    NEED_RESTART=1
fi
if [[ -n $NEED_RESTART ]];then
    exit $NEED_RESTART
fi
if [[ ! -e "$kernel_marker" ]];then
  output " [*] The first time, you need to reload the new kernel and reprovision."
  output " [*] For that, issue now 'vagrant reload'"
  exit 1
else
  if [ ! -e $MARKERS/provision_step_nfs_done ]; then
    output " [*] Install nfs support on guest"
    apt-get install -q -y --force-yes nfs-common portmap || die_if_error
    touch $MARKERS/provision_step_nfs_done
  fi
  if [ ! -e $MARKERS/provision_step_lxc_done ]; then
    output " [*] Install lxc-docker support"
    # Add lxc-docker package
    wget -c -q -O - https://get.docker.io/gpg | apt-key add -
    echo deb http://get.docker.io/ubuntu docker main > ${src_l}.d/docker.list
    apt-get update -qq || die_if_error
    apt-get install -q -y --force-yes lxc-docker || die_if_error
    # autorestart dockers on boot
    sed -re "s/docker -d/docker -r -d/g" -e /etc/init/docker.conf
    service docker restart
    die_if_error
    touch $MARKERS/provision_step_lxc_done
    NEED_RESTART=1
  fi
  if [ ! -e $MARKERS/provision_step_lang_done ]; then
    output " [*] Fix French language"
    apt-get install -q -y --force-yes language-pack-fr
    echo>/etc/locale.gen
    echo "en_US.UTF-8 UTF-8">>/etc/locale.gen
    echo "en_US ISO-8859-1">>/etc/locale.gen
    echo "de_DE.UTF-8 UTF-8">>/etc/locale.gen
    echo "de_DE ISO-8859-1">>/etc/locale.gen
    echo "de_DE@euro ISO-8859-15">>/etc/locale.gen
    echo "fr_FR.UTF-8 UTF-8">>/etc/locale.gen
    echo "fr_FR ISO-8859-1">>/etc/locale.gen
    echo "fr_FR@euro ISO-8859-15">>/etc/locale.gen
    echo 'LANG="fr_FR.utf8"'>/etc/default/locale
    M
    echo "export LANG=\${LANG:-fr_FR.UTF-8}">>/etc/profile.d/0_lang.sh
    /usr/sbin/locale-gen || die_if_error
    update-locale LANG=fr_FR.utf8 || die_if_error
    if [ "0" == "$?" ];then touch $MARKERS/provision_step_lang_done; fi;
  fi
  if [[ ! -e $MARKERS/salt_bootstrap_done ]];then
    output " [ * ] Bootstrap Salt-Stack env..."
    export SALT_BOOT='server'
    if [ -e /src/salt/makina-states/src/salt ];then
      sed -re "s/filemode = true/filemode = false/g" -i /src/salt/makina-states/src/*/.git/config
    fi
    wget http://raw.github.com/makinacorpus/makina-states/master/_scripts/boot-salt.sh -O - | bash
    die_if_error
    . /etc/profile
    touch $MARKERS/salt_bootstrap_done
  fi
  if [[ ! -e /srv/salt/setup.sls ]];then
      SALT_BOOT='server' /srv/salt/makina-states/_sscripts/boot-salt.sh
  fi
fi
if [[ -n $NEED_RESTART ]];then
    output "You need to reboot, issue 'vagrant reload'"
    exit $NEED_RESTART
fi
# cleanup archives to preserve vm SPACE
if [[ $(find /var/cache/apt/archives/ -name *deb|wc -l) != "0" ]];then
    rm -rf /var/cache/apt/archives/*deb
fi
# Always start salt and docker AFTER /srv has been mounted on the VM
output " [*] Manage Basic daemons using /srv"
output " [*] /srv is mounted quite late so we must start some daemons later"
# kill salt that may be running
ps aux|egrep "salt-(master|minion|syndic)"|awk '{print $2}'|xargs kill -9 &> /dev/null
service salt-master start
#rm -rf /etc/salt/pki/minion/minion_master.pub
service salt-minion start
service docker stop
service docker start
output " [*] allow routing of traffic comingfrom dev host going to docker net"
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.all.log_martians=1
ready_to_run
# vim:set et sts=4 ts=4 tw=0:
