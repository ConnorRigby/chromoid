# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

config :chromoid, target: Mix.target() || :host

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1600265789"

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [:console, RingLogger, BlueHeron.HCIDump.Logger]
# config :logger, handle_otp_reports: true, handle_sasl_reports: true

config :logger, :console,
  format: "\n$time $metadata[$level] $levelpad$message\n",
  metadata: [:ble_address]

config :chromoid, :socket, reconnect_interval: 5000

if Mix.target() != :host do
  import_config "target.exs"
else
  import_config "host.exs"
end
