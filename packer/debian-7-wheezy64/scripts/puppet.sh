# Install Puppet
wget http://apt.puppetlabs.com/puppetlabs-release-wheezy.deb
dpkg -i puppetlabs-release-wheezy.deb
apt-get update
apt-get -y --force-yes install puppet
rm -f puppetlabs-release-wheezy.deb
