#!/usr/bin/env bash
echo "Are you really sure ? (controlc to abort)"
read
vagrant halt -f
vagrant destroy
rm -rf .vb_name .vagrant salt
vagrant up
# vim:set et sts=4 ts=4 tw=80:
