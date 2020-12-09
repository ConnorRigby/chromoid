import Config

config :nerves,
  firmware: [
    rootfs_overlay: "rootfs_overlay"
  ]

config :chromoid,
  camera_provider: Chromoid.CameraProvider.Freenect,
  relay_provider: Chromoid.RelayProvider.NotSupported
