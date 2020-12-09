import Config

config :nerves,
  firmware: [
    fwup_conf: "config/rpi0/fwup.conf",
    rootfs_overlay: "rootfs_overlay"
  ]

config :chromoid,
  camera_provider: Chromoid.CameraProvider.Picam,
  relay_provider: Chromoid.RelayProvider.NotSupported
