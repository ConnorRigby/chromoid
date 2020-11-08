import Config
config :logger, backends: [RingLogger]

config :chromoid_link_octo_print,
  socket: [
    reconnect_interval: 5000
  ]
