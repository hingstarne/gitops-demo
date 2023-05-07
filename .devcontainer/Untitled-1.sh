curl --silent --location "https://github.com/weaveworks/weave-gitops/releases/download/v0.6.2/gitops-$(uname)-$(uname -m).tar.gz" | tar xz -C /home/vscode/.local/bin

sudo mv /tmp/gitops /usr/local/bin
gitops version