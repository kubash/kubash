#!/bin/sh -eux

# Disable Predictable Network Interface names and use eth0.
# The GRUB kernel args are the mechanism that works on every
# boot and any hardware; the config-file edits below just
# keep each network stack in sync with the name the kernel
# is about to assign.
sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 \1"/g' /etc/default/grub;
update-grub;

# ifupdown (Debian): rename in /etc/network/interfaces.
if [ -f /etc/network/interfaces ]; then
  sed -i 's/en[[:alnum:]]*/eth0/g' /etc/network/interfaces
  # Adding a 2 sec delay to the interface up, to make the dhclient happy
  echo "pre-up sleep 2" >> /etc/network/interfaces
fi

# Netplan (Ubuntu): the installer's config is keyed by the
# predictable name; re-key it to eth0 or the renamed
# interface comes up unconfigured on the next boot.
if [ -d /etc/netplan ]; then
  PRIMARY_IFACE=$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')
  if [ -n "$PRIMARY_IFACE" ] && [ "$PRIMARY_IFACE" != "eth0" ]; then
    sed -i "s/^\( *\)$PRIMARY_IFACE:/\1eth0:/" /etc/netplan/*.yaml
  fi
fi
