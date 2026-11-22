# Headlamp

Kubernetes dashboard, deployed with the k3s `HelmChart` CR in [headlamp.yaml](./headlamp.yaml)
applied by [deploy.sh](./deploy.sh).

- https://headlamp.stephanme.de/ - signs in with Pocket ID
- http://headlamp.fritz.box/ - plain http LAN entry point, token login
- [Helm chart values](https://github.com/kubernetes-sigs/headlamp/blob/main/charts/headlamp/values.yaml)
- [Headlamp OIDC docs](https://headlamp.dev/docs/latest/installation/in-cluster/oidc/)

## Installation

`./headlamp/deploy.sh` is `kubectl apply -f <dir>`, so **every** `*.yaml` in this directory is
applied - documentation must not be a `.yaml` file here.

The Headlamp pod needs `Secret/k3s-oidc-client` from the namespace-level [../secrets.yaml](../secrets.yaml.template) (gitignored). On a fresh clone copy the template
and fill in the Pocket ID client values first, otherwise the pod stays in
`CreateContainerConfigError`. Deploy the namespace files with `../deploy.sh` (it applies them
before this directory).

## Single sign-on (Pocket ID)

Headlamp only *refers* to the cluster's OIDC client - the Pocket ID client, the kube-apiserver
flags and the RBAC are documented in [../README.md](../README.md). What is Headlamp specific:

- `HEADLAMP_CONFIG_OIDC_*` environment variables instead of the chart's `config.oidc.*`
  values: the chart path would render the client secret into `valuesContent`, i.e. into git.
  Headlamp reads `HEADLAMP_CONFIG_<FLAG>` as an alternative to every `-oidc-*` flag. If the
  `Sign in with OIDC` button ever disappears, `kubectl -n kube-system get deploy headlamp -o yaml`
  must show the five variables, and `curl -s https://headlamp.stephanme.de/config`
  must contain an `oidc_config` block (without OIDC that endpoint only has `clusters` and
  `"oidcAutoLogin":false`) - if it does not, the chart's `OIDC_*` env names are the fallback.
- `HEADLAMP_CONFIG_OIDC_CALLBACK_URL` has to match the callback URL registered on the Pocket
  ID client byte for byte - `https://headlamp.stephanme.de/oidc-callback`, at the host root
  since Headlamp has no `/headlamp` base URL any more. Traefik sets `X-Forwarded-Proto`, but
  the explicit value removes any guessing.
- `config.oidc.secret.create: false`, so the chart neither generates nor owns a secret.
- `oidc.autoLogin` stays unset - with `-oidc-auto-login` Headlamp redirects straight to Pocket
  ID and the token field disappears. Keeping it is what makes the break-glass login work.
- `unsafeUseServiceAccountToken` stays false: every user gets their own Kubernetes identity
  (`oidc:<username>`, groups from Pocket ID) instead of sharing Headlamp's service account.
- The chart keeps its default `clusterRoleBinding` (`cluster-admin` for the `headlamp`
  service account). Together with the static token Secret in
  [headlamp-token.yaml](./headlamp-token.yaml) that is the break-glass path when Pocket ID is
  down:

  ```bash
  kubectl -n kube-system get secret headlamp-sa-token -o jsonpath='{.data.token}' | base64 -d
  ```

  paste that into the token field on either URL.

## Ingress

Three routes for the same instance defined in [headlamp-ingress.yaml](./headlamp-ingress.yaml):

| URL | Resource | Notes |
| --- | --- | --- |
| `http://headlamp.fritz.box` | `headlamp-http` (entrypoint `web`) | plain http LAN route, never redirected, token login |
| `http://headlamp.stephanme.de` | `headlamp-http-redirect` | 301 to https |
| `https://headlamp.stephanme.de` | `headlamp-tls` | OIDC login, TLS secret `kube-system-stephanme-de` from [../certificate.yaml](../certificate.yaml) |

## Updates

- chart version pinned in [headlamp.yaml](./headlamp.yaml) (`version:`), bumped by renovate.
- After a chart bump, re-check that the `HEADLAMP_CONFIG_OIDC_*` variables are still honoured
  (see the SSO section above) - the chart's own OIDC value plumbing has changed several times
  upstream.
