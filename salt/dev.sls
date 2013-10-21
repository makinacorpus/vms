#
# This states contains things that only DEVELOPMENT envs are using
#

#
# Dev env SMTP/POP basic services
#
# All SMTP traffic on this server port 25 and pushed into 
# a vagrant user mailbox on /var/spool/mail
# the vagrant VM is also offering an IMAP server, use it with
# vagrant/vagrant user to read the mails.
# Docker dev hosts should relay all mails to that vagrant vm's 
# smtp server
{% if grains.get('makina.devhost', false) %}
include:
 - makina-states.services.mail.postfix
  {% if not grains.get('makina.devhost-docker', false) %}
 - makina-states.services.mail.dovecot
  {% endif %}
{% endif %}

