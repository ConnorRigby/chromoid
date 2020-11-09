import Config
config :logger, backends: [RingLogger]

config :chromoid_link_octo_print,
  base_url: "http://192.168.1.124",
  api_key: "4CD9A2E4815241E198CF3C0F8605A1DF",
  user: "connor",
  pass: "9Zo7uWy&V6Z2f",
  socket: [
    reconnect_interval: 5000
  ]
