# kube-system shared resources

Resources for the cluster infrastructure: MetalLB, Traefik, dnsmasq,
node-feature-discovery, descheduler, [Headlamp](./headlamp/README.md) - and the OIDC
client the kube-apiserver uses to accept **Pocket ID logins**.

`deploy.sh` applies the files in this directory first (Secret, Certificate, RBAC), then the
sub-directory scripts. There is no `namespace.yaml` here (and none for `default/`): kube-system
is created by k3s itself, so every namespaced manifest in this directory states
`namespace: kube-system` explicitly instead.

## Pocket ID login for the Kubernetes API

One Pocket ID OIDC client serves the whole Kubernetes API. Headlamp only *refers* to it to
get tokens; the kube-apiserver decides who is who. That means one place to change
(`/etc/rancher/k3s/config.yaml`) if another consumer shows up later (kubectl/kubelogin,
a second dashboard, ...).

```
browser -> Headlamp -> Pocket ID (passkey) -> id_token
                                                 |
   Headlamp proxies the id_token to kube-apiserver -> iss + aud + claims checked
                                                 |
                       RBAC: Group "oidc:admins" -> ClusterRole cluster-admin
```

Because OIDC is only *added* to the authentication chain, nothing else changes:

- **kubeconfig keeps working.** The client certificates in `/etc/rancher/k3s/k3s.yaml`
  (and every copy of it on a workstation) are still accepted verbatim. OIDC never replaces
  client-certificate or service-account authentication.
- **Headlamp keeps the "paste token" field** (we deliberately do not enable
  `oidc-auto-login`), so the break-glass login with
  `kubectl -n kube-system get secret headlamp-sa-token -o jsonpath='{.data.token}' | base64 -d`
  still works when Pocket ID is down. That service account is cluster-admin
  (`headlamp-admin` ClusterRoleBinding).
- **The plain-http URL stays**: http://headlamp.fritz.box (see
  [headlamp/README.md](./headlamp/README.md)).

### Rollout order

1. Create the Pocket ID client (below) and put its id/secret in `secrets.yaml`.
2. `./kube-system/deploy.sh` - Secret + Certificate + RBAC first, then the apps including
   [Headlamp](./headlamp/README.md). Wait until the Certificate is Ready (~5 min DNS-01).
   Headlamp already shows the OIDC sign-in button now, but the cluster still rejects the
   token - that is expected until step 3.
3. The `kube-apiserver-arg` flags on the nodes, one server at a time (below).
4. Verify: OIDC login in Headlamp, `kubectl get nodes` with the kubeconfig, and the
   `headlamp-sa-token` break-glass login.
5. Then the Pocket ID outage test (below) on one node.

Rollback at any point: delete the `oidc-*` lines on the nodes and/or revert the Headlamp
`env:` block. Neither the kubeconfig nor the service-account break-glass login is ever
affected.

### Pocket ID setup (one time, https://pocketid.stephanme.de)

1. **User Groups**: the group `admins` is used for cluster-admin, other groups get
   no cluster access at all.
2. **OIDC Clients -> Add OIDC Client**, name `Kubernetes API (k3s)`:
   - confidential client (Headlamp sends a client secret),
   - callback URL, exactly: `https://headlamp.stephanme.de/oidc-callback`
     (https only - Pocket ID runs with `ALLOW_INSECURE_CALLBACK_URLS=false`),
   - **Access tab: allow the group `admins` only**, so nobody else can even get a code,
   - copy client id + secret (shown once) into `secrets.yaml`
     (gitignored, copy `secrets.yaml.template`).
3. Scopes/PKCE stay at the Pocket ID defaults; Headlamp asks for `openid profile email
   groups` (Pocket ID only puts the `groups` claim in the token if the `groups` scope is
   requested).

### kube-apiserver flags

Append to `/etc/rancher/k3s/config.yaml` on **each of the three server nodes** (merge into
an existing `kube-apiserver-arg:` list if there is one):

```yaml
kube-apiserver-arg:
  - "oidc-issuer-url=https://pocketid.stephanme.de"
  - "oidc-client-id=<client id from secrets.yaml>"
  - "oidc-username-claim=preferred_username"
  - "oidc-username-prefix=oidc:"
  - "oidc-groups-claim=groups"
  - "oidc-groups-prefix=oidc:"
```

- `preferred_username` instead of `email`: with `oidc-username-claim=email` the API server
  rejects every token that is not flagged `email_verified` in Pocket ID. The prefix is
  needed because claims other than `email` are prefixed with `<issuer>#` by default.
- The issuer URL must be exactly Pocket ID's `APP_URL` (no trailing slash), and
  `oidc-client-id` must be the client Headlamp uses, otherwise the API server rejects the
  forwarded token because of the audience.
- Pocket ID has RS256 keys and a public-CA certificate, so `oidc-signing-algs` and
  `oidc-ca-file` stay at their defaults.

Before touching a node, check that the API server can actually reach the issuer from it
(the API server fetches the discovery document itself):

```bash
ssh <server> curl -fsS https://pocketid.stephanme.de/.well-known/openid-configuration
```

If that fails, add `192.168.178.230 pocketid.stephanme.de` to the node's `/etc/hosts` so
it does not depend on dnsmasq (which itself runs in the cluster).

### Node rollout

Roll one server node at a time, waiting for `kubectl get nodes` to show it Ready and the
control plane healthy before continuing; do the agent-less servers first and `nasbox`
(storage/Samba host) last. Do not combine this with a scheduled k3s upgrade.

*Attention:* Migrate zot away from the node before draining/restarting. Otherwise image pull
will be slow or even fail.

```bash
ssh <server> systemctl restart k3s
```

Rollback per node: delete the six `oidc-*` lines from `/etc/rancher/k3s/config.yaml`,
`systemctl restart k3s`. The kubeconfig keeps working the whole time.

### Failure modes

- **Pocket ID down**: the UI still loads, kubeconfig and service-account-token logins keep
  working, only *new* OIDC logins fail. Tokens that were already issued stay valid until
  they expire (the API server caches the signing keys).
- **Cold start**: some Kubernetes versions refuse to start kube-apiserver when the OIDC
  discovery endpoint is unreachable, i.e. a reboot with Pocket ID broken would be painful.
  After enabling the flags, test it on one node with
  `kubectl -n pocketid scale deploy/pocket-id --replicas=0` followed by
  `systemctl restart k3s` on that node (and restore `--replicas=1`). If the API server does
  not come back: remove the `oidc-*` lines on that node, restart k3s, restore Pocket ID,
  then re-add the lines node by node.
- **Sessions**: Headlamp forwards the (short-lived) ID token, so an idle browser has to
  sign in again when the token expires. Refresh tokens/`offline_access` are not configured.
- Users without the `admins` group have no OIDC groups and therefore no access.

### Future work (nothing in the API server has to change for these)

- **kubectl via Pocket ID**: add a loopback callback to the same client - Pocket ID accepts
  `http://localhost/callback` even with insecure callbacks disabled, and a loopback URL
  without a port matches any port - then add a `kubelogin` `exec` user to the kubeconfig
  next to the existing certificate user.
- **Traefik dashboard SSO**: add `traefik.stephanme.de` to the dnsNames of
  `certificate.yaml` (one DNS-01 re-issue, the Secret stays the same) and protect it with a
  client of its own (Traefik's own forward-auth/OAuth support, not this OIDC client).
- A second OIDC client with a different audience would need `--oidc-client-id` to list both
  audiences, or a structured `--authentication-config`.
