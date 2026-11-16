# cert-manager with netcup DNS-01 webhook

Automatic Let's Encrypt certificates for `*.stephanme.de` hostnames via
DNS-01 challenges solved through the netcup DNS API
([aellwein/cert-manager-webhook-netcup](https://github.com/aellwein/cert-manager-webhook-netcup)).
Purely internal setup: DNS-01 only needs outbound HTTPS to
`acme-v02.api.letsencrypt.org` and the netcup API — no port forwarding, no
public A records. LAN clients resolve `*.stephanme.de` via dnsmasq.

## One-time manual setup

1. **netcup**: `stephanme.de` must be served by netcup CloudDNS (default for
   netcup-registered domains).
2. Create an **API key** in netcup restricted to domain `stephanme.de` with
   DNS permission. The DNS API can only manage `_acme-challenge*` TXT
   records, nothing else can be touched by cert-manager.
3. Create the secret (see `secrets.yaml.template`; the webhook detects which
   API to use from the keys present):

   ```sh
   cp secrets.yaml.template secrets.yaml   # then edit
   ```
4. Deploy with `deploy.sh` script. First deploy needs some retries until CRDs are installed.

## What gets installed

| Resource | Purpose |
|---|---|
| HelmChart `cert-manager` (charts.jetstack.io) | controller/webhook/cainjector/acmesolver with chart-default images |
| HelmChart `cert-manager-webhook-netcup` (OCI) | DNS-01 solver for netcup |
| ClusterIssuer `letsencrypt-staging` | test issuer (LE staging CA, no rate limits) |
| ClusterIssuer `letsencrypt-prod` | production issuer |

## Using a certificate in another namespace

TLS secrets are namespace-local and Traefik IngressRoutes can only reference
a secret in their own namespace, so each consuming namespace declares its
own `Certificate` (exact dnsNames; one DNS-01 round per certificate is
normal and cheap):

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: immich-stephanme-de   # in the app's namespace
spec:
  secretName: immich-stephanme-de
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - immich.stephanme.de
```

and reference `secretName` from that namespace's IngressRoute `tls.secretName`.
Start new certificates against `letsencrypt-staging` first, then switch the
issuer to `letsencrypt-prod` to avoid production rate limits while debugging.

## Troubleshooting

```sh
kubectl -n cert-manager-system get pods,apiservice            # webhook up?
kubectl get clusterissuer                                     # both Ready=True?
kubectl -n <app> describe certificate <cert>                  # challenge errors
kubectl -n <app> describe order <order>
kubectl -n cert-manager-system logs deploy/cert-manager-webhook-netcup
# manual check that the webhook can write TXT records:
dig TXT _acme-challenge.<host>.stephanme.de @ns1.netcup.net
```

Common failures: ClusterIssuer not Ready → wrong credentials or wrong API
variant (REST vs CCP) in the secret; stuck challenges → check webhook logs
and that stale `_acme-challenge` records were cleaned up.
