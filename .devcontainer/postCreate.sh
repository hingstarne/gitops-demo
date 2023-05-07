#!/usr/bin/env bash

cd "${0%/*}/.."

# this is not set during `postCreateCommand`, it is injected into the environment by extension JS
if [ -z "$CODESPACE_VSCODE_FOLDER" ]; then
  CODESPACE_VSCODE_FOLDER=$(find /workspaces -maxdepth 1 -mindepth 1 -type d -not -path '*/\.*' -print -quit)
  echo "CODESPACE_VSCODE_FOLDER is not defined, using derived folder $CODESPACE_VSCODE_FOLDER"
fi

# find all .tool-versions within the repo, but ignore all hidden directories
/bin/find $CODESPACE_VSCODE_FOLDER -type d -path '*/.*' -prune -o -name '*.tool-version*' -print | while read filePath; do
  echo "asdf setup for $filePath"

  # install all required plugins
  cat $filePath | cut -d' ' -f1 | grep "^[^\#]" | xargs -i asdf plugin add {}

  # install all required versions
  (cd $(dirname $filePath) && asdf install)
done

# automatically startup a docker-compose that exists in the devcontainer folder
if test -f $CODESPACE_VSCODE_FOLDER/.devcontainer/docker-compose.yml; then
  echo "docker-compose found, starting up"
  (cd $CODESPACE_VSCODE_FOLDER/.devcontainer && docker compose up -d)
fi

# Add kind cluster with Ingress
kind delete cluster --name gitpos
cat <<EOF | kind create cluster --name gitops --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
kind get kubeconfig --name gitops > ~/.kube/config
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s