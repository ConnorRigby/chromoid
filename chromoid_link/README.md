# Chromoid

## Mix.target() feature matrix

| mix target | description | features |
|:----------:|-------------|:--------:|
| ble_link_rpi0 | device that connects to govee ble devices | ble, picam |
| relay_link_rpi3 | device that can control an external relay via gpio, also has a system that can connect to a UART arduino to control xmas tree | gpio, uart, picam |
| kinect_link_rpi3 | doesn't actually exist irl yet, but use `freenect` to connect it to chromo.id | kinect, usb |
| host | all of those things, but in a hackier way | yes |

## Provisioning

Step 1: On build machine:

```bash
mix nerves_hub.device create $IDENTIFIER
mix nerves_hub.device burn $IDENTIFIER
```

Step 2: configure VintageNet wizard.
Step 3: get a chromo.id token.
Step 4: put chromo.id token in CubDB somehow.
Step 5: it should connect now.

## Deploying

for every active target:

1) `export MIX_TARGET=ble_link_rpi0`
2) `mix firmware`
3) `mix nerves_hub.firmware publish --key devkey`
4) `mix nerves_hub.deployment update $MIX_TARGET firmware $UUID_FROM_LAST_COMMAND`
