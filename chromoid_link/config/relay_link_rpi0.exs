import Config

config :nerves,
  firmware: [
    fwup_conf: "config/rpi0/fwup.conf",
    rootfs_overlay: "rootfs_overlay"
  ]
