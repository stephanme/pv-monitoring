# Open WebUI

- http://open-webui.fritz.box (plain http, kept for LAN clients)
- https://open-webui.stephanme.de (TLS, sign in with Pocket ID)
- [Helm chart values](https://github.com/open-webui/helm-charts/blob/main/charts/open-webui/values.yaml)
- [Pocket ID guide](https://pocket-id.org/docs/client-examples/open-webui)

## Installation

k3s `HelmChart` CR in [open-webui.yaml](./open-webui.yaml), applied by [deploy.sh](./deploy.sh).
All ingress config (both hostnames, the http->https redirect and the Certificate) lives in
[ingress.yaml](./ingress.yaml); the chart's own ingress is disabled.

`secrets.yaml` is gitignored but referenced by `deploy.sh`, so copy
`secrets.yaml.template` and fill in the Pocket ID client values before the first deploy —
until the `open-webui-secrets` Secret exists the pod stays in `CreateContainerConfigError`.

## Single sign-on (Pocket ID)

One-time setup in Pocket ID (<https://pocketid.stephanme.de>):

1. Administration -> User Groups: create the groups `family` and `admins` (the names must
   match `OAUTH_ALLOWED_ROLES` / `OAUTH_ADMIN_ROLES`). Group creation in Open WebUI is
   disabled, so every group it should use has to exist here first.
2. Administration -> OIDC Clients -> Add OIDC Client, confidential client, callback URL
   `https://open-webui.stephanme.de/oauth/oidc/callback`. Copy the client ID and secret
   into `secrets.yaml` (the secret is only shown once).
3. Client's Access tab: allow the groups whose members may sign in.

Notes:

- `OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true` links an OIDC login to an existing local account
  with the same e-mail address, so accounts created before SSO keep their settings.
- `ENABLE_LOGIN_FORM=true` keeps password login as break-glass access; Pocket ID being down
  must not lock everyone out. The docs recommend keeping one local admin account without SSO.
- Sign-in via `http://open-webui.fritz.box` cannot use Pocket ID: Pocket ID runs with
  `ALLOW_INSECURE_CALLBACK_URLS=false`, so only the https origin can be a callback URL.
- `WEBUI_SECRET_KEY` must stay in the Secret: without it Open WebUI writes a random key to
  `/app/backend/.webui_secret_key` (container filesystem, not the PVC) at every start and
  invalidates all sessions of all users on each deploy.
- `ENABLE_LOCAL_WEB_FETCH=true` is only needed so the Pocket ID profile picture can be
  downloaded (Pocket ID resolves to the Traefik VIP, an RFC1918 address the fetch guard
  rejects). It also lets logged-in users reach internal addresses via RAG "from website";
  drop it together with `OAUTH_UPDATE_PICTURE_ON_LOGIN` if that is not acceptable.
- Groups listed in the Pocket ID claim are only used if they already exist in Open WebUI
  (`ENABLE_OAUTH_GROUP_CREATION=false`), otherwise they would all be mirrored here.
