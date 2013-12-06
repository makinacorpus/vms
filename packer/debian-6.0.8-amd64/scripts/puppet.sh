# Install Puppet
wget http://apt.puppetlabs.com/puppetlabs-release-squeeze.deb
dpkg -i puppetlabs-release-squeeze.deb
apt-get update
apt-get -y --force-yes install puppet
