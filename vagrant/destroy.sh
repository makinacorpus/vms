#!/usr/bin/env bash
echo "Are you really sure ? (controlc to abort)"
read
vagrant halt -f
vagrant destroy -f
rm -rf .vb_name salt
vagrant up
vagrant reload
# vim:set et sts=4 ts=4 tw=80:
