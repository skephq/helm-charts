# Skep Helm charts

Helm charts for [Skep](https://www.skep.observer), the control plane for
OpenTelemetry Collectors.

| Chart | What it installs |
| --- | --- |
| [`skep-collector`](charts/skep-collector) | The Skep Collector (`skep-otelcol`): the OpenTelemetry Collector with Skep's read only observer, as a gateway Deployment or an agent DaemonSet |

Charts are published to GitHub's container registry as OCI artifacts and
signed with cosign:

```sh
helm show values oci://ghcr.io/skephq/charts/skep-collector --version 0.1.0
```

## Install the Skep Collector

You need a Skep account and a **collector key**, which Skep creates for you
when you add a collector. A collector key can only register collectors and
send observations. Skep's install guide prints these commands with your
options filled in.

1. Put the key in a Secret, so it stays out of your values and release
   history:

   ```sh
   kubectl create namespace skep
   kubectl -n skep create secret generic skep-otelcol --from-literal=SKEP_API_KEY=<your collector key>
   ```

2. Install a gateway that your services (or an agent tier) send OTLP to:

   ```sh
   helm upgrade --install skep-otelcol-gateway oci://ghcr.io/skephq/charts/skep-collector \
     --version 0.1.0 --namespace skep \
     --set mode=gateway \
     --set skep.endpoint=https://app.skep.observer \
     --set skep.environment=production
   ```

3. Point your telemetry at `skep-otelcol-gateway.skep.svc:4317` (gRPC) or
   `:4318` (HTTP). By default the collector only observes, and Skep sees the
   shape of your telemetry. To also send it on, set `backend.type` to
   `honeycomb` (with `HONEYCOMB_API_KEY` in the same Secret) or `otlp` (with
   `backend.otlpEndpoint`).

For an agent on every node (host metrics, Kubernetes metadata, optional
system logs), use `--set mode=agent`. To let Skep manage the collector's
configuration through fleets, add `--set opamp.enabled=true --set skep.fleet=<fleet>`.

Every value is described in
[`charts/skep-collector/values.yaml`](charts/skep-collector/values.yaml).

## What leaves your cluster

The collector never changes, drops or delays your telemetry. It sends Skep
summaries of what flows through it (services, attribute names, counts and
sketches), never your telemetry itself. Attribute values are sent only as
your policy in Skep allows. Details: [skep.observer](https://www.skep.observer).

## Verify a chart

```sh
cosign verify ghcr.io/skephq/charts/skep-collector:0.1.0 \
  --certificate-identity-regexp '^https://github.com/skephq/helm-charts/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Contributing

The chart is developed in Skep's main repository and copied here for each
release; please open issues here rather than pull requests against the
chart.
