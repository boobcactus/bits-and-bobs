# I need to make these into a script or at least hold onto them so theyre going here

sudo zpool create -f -o ashift=12 -m /tank tank mirror nvme-SAMSUNG_MZPLJ12THALA-00007_S55LNG0R100109 nvme-SAMSUNG_MZPLJ12THALA-00007_S55LNG0R100113

lxc config device override mongodb root size=6000GB
lxc config set mongodb limits.memory 64GB

lxc exec mongodb -- /bin/bash

lxc config device add mycontainer myport80 proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80

lxc config device add mongodb mongoport proxy listen=tcp:0.0.0.0:27017 connect=tcp:127.0.0.1:27017

export LANG=es_ES.UTF-8
(check for different lang first)
