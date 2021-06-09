# pv-monitoring
Monitoring of a photovoltaic system

- 7 kW peak solar power system
- [KOSTAL PLENTICORE plus](https://www.kostal-solar-electric.com/en-gb/products/hybrid-inverter/plenticore-plus) inverter
- [go-eCharger HOMEfix 11kW](https://go-e.co/products/go-echarger-home/?lang=en) wallbox
- Monitoring with [Prometheus](https://prometheus.io) running on a [k3s](https://k3s.io) Kubernetes cluster
  - standard Prometheus instance with 7d data retention and 30s scrape interval
  - long-term Prometheus instance with infinite data data retention and 15min scrape interval connected to the first instance using federation
  - inverter and wall box connected using [modbus_exporter](https://github.com/RichiH/modbus_exporter)
- [k3s](https://k3s.io) lightweight Kubernetes cluster
  - k3s server (using sqlite) running on a nasbox: Celeron G3900 (2 core), 4G RAM, 128G SSD, 3T raid1 disks
  - k3s agent running on Raspberry 4 8G RAM
- WIP: PV control for controlling electric car charger
  - [pv-control](https://github.com/stephanme/pv-control)
  - 1 and 3 phase charging to get a wide control range starting at 1.3 kW up to (theoretical) 11kW

## Deploy

Software versions including helm chart versions are maintained in deploy.sh and yaml files.

```
helm list -n monitoring
helm repo update

./deploy.sh
```

## k3s Installation

Standard installation as described in https://rancher.com/docs/k3s/latest/en/quick-start/

Server on nasbox:
```
curl -sfL https://get.k3s.io | sh -
```

Agent on Reaspberry Pi:
```
curl -sfL http://get.k3s.io | K3S_URL=https://192.168.178.10:6443 \
K3S_TOKEN=<join_token> sh -
```

Automatic k3s updates: https://rancher.com/docs/k3s/latest/en/upgrades/automated/
```
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.6.2/system-upgrade-controller.yaml
```

Maintain k3s version in upgrade plans: `./k3s-upgrade/k3s-upgrade.yaml`