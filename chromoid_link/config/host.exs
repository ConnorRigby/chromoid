import Config

config :chromoid,
  camera_provider: Chromoid.CameraProvider.FFMpegJPEG,
  relay_provider: Chromoid.RelayProvider.NotSupported

if chromoid_url = System.get_env("CHROMOID_URL") do
  config :chromoid,
    socket: [
      url: chromoid_url
    ]
end
