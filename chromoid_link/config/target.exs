import Config

# Use shoehorn to start the main application. See the shoehorn
# docs for separating out critical OTP applications such as those
# involved with firmware updates.

config :shoehorn,
  init: [:nerves_runtime, :nerves_pack, :vintage_net],
  app: Mix.Project.config()[:app],
  handler: Chromoid.ShoehornHandler

# Nerves Runtime can enumerate hardware devices and send notifications via
# SystemRegistry. This slows down startup and not many programs make use of
# this feature.

config :nerves_runtime, :kernel, use_system_registry: false

# Erlinit can be configured without a rootfs_overlay. See
# https://github.com/nerves-project/erlinit/ for more information on
# configuring erlinit.

config :nerves,
  erlinit: [
    hostname_pattern: "chromoid-link-%s",
    env: "LD_LIBRARY_PATH=/srv/erlang/lib/nfc-0.1.0/priv/lib"
  ],
  provisioning: :nerves_hub_link

# Authorize the device to receive firmware using your public key.
# See https://hexdocs.pm/nerves_firmware_ssh/readme.html for more information
# on configuring nerves_firmware_ssh.

keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtTSUeHLIUtkYAT9Cw8e+lE8iFsVFa20AtKjXovZesQoRg2F347ivuyFXaI+91O1qi067KPn+j3jw42gdlnqX0R4DhyW0qYH69biZTQjQfq8tLT7c7VPyxOsDxXXceORnx9s0dRsy4ZiHB56/Ffz+eAzsbOEfwlwdJDkn1oiSbHSFv5HW1/agzlzV6M+nfD6As6ZIwAysw5PROfF6ikbG+UwcOAgG+d1RZDR2BTzedQrKEwYM5SiFYyqt7bQFj7BHKtkB9T4CsyU+Y1ORptFNoVyluQkaY9bTptTkj/PpWt2sntd8zKfwRHa7ysRTCWzN4XWIUWfOJsbe577ghN6Lh connor@connor-mini-pc",
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDV74EGCzSYUdlChm1ToKWjQptVw49ufQ43UQK7x/tkqo2+b+if9TrUk0RwwDjYfmvKdTAKQCmKpBgbjdVvMBBuPjQ4G3pU3O4vZ8ai3ykJ6KtaMqLu2zju1nTmZyOXgkFigHPuy1F+DyNsEAKfBqjWa9jNbvi6rCLIU9uHpcDsbgHULgCRlxfRYouHUstISSppBNEjCDWV8tDcrk6c3OCfoWbY8zxX11iGtVe9oMIL+PU40RBiul4REEXiB1Mj/8q3W+a4BvqrfPCx+7pNWALvBiImV1n5IFzBEYsLPacT2qf/YjmUoujLErg5IU52K+8TszUGnRUU2I467Lci5Let connor@ConnorLaptop"
]

config :nerves_firmware_ssh,
  authorized_keys: keys

# Configure the network using vintage_net
# See https://github.com/nerves-networking/vintage_net for more information
config :vintage_net,
  regulatory_domain: "US",
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"eth0", %{type: VintageNetEthernet}},
    {"wlan0", %{type: VintageNetWiFi}}
  ]

config :vintage_net_wizard,
  inactivity_timeout: 30

config :mdns_lite,
  # The `host` key specifies what hostnames mdns_lite advertises.  `:hostname`
  # advertises the device's hostname.local. For the official Nerves systems, this
  # is "nerves-<4 digit serial#>.local".  mdns_lite also advertises
  # "chromoid-link" for convenience. If more than one Nerves device is on the
  # network, delete "nerves" from the list.

  host: [:hostname, "chromoid-link"],
  ttl: 120,

  # Advertise the following services over mDNS.
  services: [
    %{
      name: "SSH Remote Login Protocol",
      protocol: "ssh",
      transport: "tcp",
      port: 22
    },
    %{
      name: "Secure File Transfer Protocol over SSH",
      protocol: "sftp-ssh",
      transport: "tcp",
      port: 22
    },
    %{
      name: "Erlang Port Mapper Daemon",
      protocol: "epmd",
      transport: "tcp",
      port: 4369
    }
  ]

config :nerves_hub_link,
  socket: [
    reconnect_interval: 5000
  ],
  fwup_public_keys: [
    "7Qqp8dWwD9K6B4uVRt39IzY0CSJ0xx1OUf07XxW0fC8=",
    "pF9zswWUAblM0JDmGqo+71xGDifrpfOacbkVoPOc/E0="
  ],
  remote_iex: true

config :nerves_hub_cli,
  org: "konnorrigby"

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

import_config "#{Mix.target()}.exs"
