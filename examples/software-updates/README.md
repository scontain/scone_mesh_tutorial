# Confidential Software Updates with sconectl

## Before you begin

Specify your image names and CAS namespace.

```bash
# You must have push permissions on the selected registry!
IMAGE_V1="registry/repo/python_hello_user:v1"
# You must have push permissions on the selected registry!
IMAGE_V2="registry/repo/python_hello_user:v2"
CAS_NAMESPACE="python-hello-user-$RANDOM$RANDOM"
```

- Update `v1/service.yaml`: set `build.to` to `$IMAGE_V1`
- Update `v1/mesh.yaml`: set `policy.namespace` to `$CAS_NAMESPACE`
- Update `v2/service.yaml`: set `build.stable` to `$IMAGE_V1`
- Update `v2/service.yaml`: set `build.to` to `$IMAGE_V2`
- Update `v2/mesh.yaml`: set `policy.namespace` to `$CAS_NAMESPACE`

## Running this example

- Build the v1 image of our sample API.

```bash
sconectl apply -f v1/service.yaml
```

- Generate policies and a Helm chart from the Meshfile.

```bash
sconectl apply -f v1/mesh.yaml
```

- Deploy the v1 API to the cluster.

```bash
helm install pythonapp target/helm
```

- Deploy the client to the cluster. The client will keep querying the `/version` endpoint to check which version is currently deployed.

```bash
kubectl create -f client.yaml
```

- On a separate terminal, keep checking the logs of the client.

```bash
kubectl logs client -f
```

- Now, let's build our updated API (v2) from `v2/service.yaml`. The manifest has a new field, `build.stable`, which points to the currently deployed image (v1). This enables rolling updates with zero downtime as we transition from v1 to v2!

```bash
sconectl apply -f v2/service.yaml
```

- Update policies and Helm charts for the new API version.

```bash
sconectl apply -f v2/mesh.yaml
```

- Upgrade the deploy to rollout the new version.

```bash
helm upgrade pythonapp target/helm
```

- Note that the client will smoothly transition from getting `v1` responses to `v2` without any downtime.

```console
$ kubectl logs client -f
v1
v1
v1
v1
v1
v2
v2
v2
v2
v2
```

