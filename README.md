# pv-monitoring
Monitoring of a photovoltaic system, car charging and heat pump

- 7 kW peak solar power system
- [KOSTAL PLENTICORE plus](https://www.kostal-solar-electric.com/en-gb/products/hybrid-inverter/plenticore-plus) inverter
- [go-eCharger HOMEfix 11kW](https://go-e.co/products/go-echarger-home/?lang=en) wallbox
- [Nibe VVM310 + S2125-8 heat pump](https://www.nibe.eu/en-eu/products/heat-pumps/air-water-heat-pumps/vvm-310)
- Monitoring with [Prometheus](https://prometheus.io) running on a [k3s](https://k3s.io) Kubernetes cluster
  - standard Prometheus instance with 7d data retention and 30s scrape interval
  - long-term Prometheus instance with infinite data data retention and 15min scrape interval connected to the first instance using federation
  - inverter and wall box connected using [modbus_exporter](https://github.com/RichiH/modbus_exporter)
- [k3s](https://k3s.io) lightweight Kubernetes cluster
  - k3s server (using sqlite) running on a nasbox: Celeron G3900 (2 core), 32G RAM, 128G SSD, 4T raid1 disks
  - k3s agent running on Raspberry 4, 8G RAM, 512G SSD
- [pv-control](https://github.com/stephanme/pv-control) for controlling electric car charger
  - charge car by solar power only
  - 1 and 3 phase charging to get a wide control range starting at 1.3 kW up to (theoretical) 11kW
  - UI for controlling charge modes
- [Home Assistant](https://www.home-assistant.io/) for additional home automation

## Deploy

This repo is structured by namespace and app: `pv-monitoring/<namespace>/<app>`. Every directory contains a `deploy.sh` script which recursively deploys the k8s resources of the directory. 

Software versions including helm chart versions are maintained in deploy.sh and yaml files. Versions are kept up-to-ate by the [renovate bot](https://docs.renovatebot.com/).

Important release notes
- [k3s](https://github.com/k3s-io/k3s/releases)
- [metallb](https://metallb.universe.tf/release-notes/)
- [longhorn](https://github.com/longhorn/longhorn/tree/master/CHANGELOG)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [homeassistant](https://www.home-assistant.io/blog/categories/release-notes/)

## k3s Installation

Standard installation as described in https://rancher.com/docs/k3s/latest/en/quick-start/.

All http and tcp workloads are exposed via [Traefik v2](https://traefik.io/) which is deployed as daemon set on all nodes:
- k3s.fritz.box - via MetalLB
- nasbox.fritz.box, pi1.fritz.box - via node ports
- additional DNS names like homeassistant.fritz.box - translated to node IPs or MetalLB IP via dnsmasq + customized coredns

[MetalLB](https://metallb.universe.tf/) is used as LB for special services that need an own IP. E.g. for [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) which is used as internal DNS server as the Fritzbox doesn't allow to add additional host names.

### k3s Server on nasbox
```
curl -sfL https://get.k3s.io | sh - --disable coredns,servicelb
```

Config file `/etc/rancher/k3s/config.yaml`
```
disable: coredns,servicelb

# https://github.com/k3s-io/k3s/issues/3619#issuecomment-993977516
kube-controller-manager-arg:
- "bind-address=0.0.0.0"
kube-proxy-arg:
- "metrics-bind-address=0.0.0.0"
kube-scheduler-arg:
- "bind-address=0.0.0.0"
```

Others:
- Disable multipath for `sd[a-z0-9]+` devices as described in [Troubleshooting: `MountVolume.SetUp failed for volume` due to multipathd on the node](https://longhorn.io/kb/troubleshooting-volume-with-multipath/)

### k3s Agent on pi1

Agent on Raspberry Pi:
```
# enable cgroups, see https://docs.k3s.io/advanced#raspberry-pi

# needed for longhorn
sudo apt install open-iscsi

curl -sfL http://get.k3s.io | K3S_URL=https://192.168.178.10:6443 \
K3S_TOKEN=<join_token> sh -
```

## k3s Updates

Automatic k3s updates: https://rancher.com/docs/k3s/latest/en/upgrades/automated/

Maintain k3s version in upgrade plans: `./system-upgrade/k3s-upgrade.yaml`