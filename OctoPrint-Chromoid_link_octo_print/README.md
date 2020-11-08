# install

```
cd ~/chromoid/OctoPrint-Chromoid_link_octo_print
rm ../.tool_versions
mix deps.get
mix release
cp _build/dev/rel/bakeware/chromoid_link_octo_print ~/oprint/bin/
~/oprint/bin/pip3 install .
sudo systemctl start octoprint
```
