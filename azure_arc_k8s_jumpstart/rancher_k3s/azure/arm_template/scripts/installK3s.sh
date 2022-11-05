#!/bin/bash
mkdir ~/jumpstart_logs
LOG_FILE=~/jumpstart_logs/installK3s.log
echo ""
tput setaf 6;echo "Script log can be found in `tput sitm`${LOG_FILE}`tput ritm`" | expand | awk 'length($0) > length(longest) { longest = $0 } { lines[NR] = $0 } END { gsub(/./, "=", longest); print "/=" longest "=\\"; n = length(longest); for(i = 1; i <= NR; ++i) { printf("| %s %*s\n", lines[i], n - length(lines[i]) + 1, "|"); } print "\\=" longest "=/" }'
tput sgr0
echo ""

{
  # Script starts
  sudo apt-get update

  # Injecting environment variables
  echo '#!/bin/bash' >> vars.sh
  echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
  echo $appId:$2 | awk '{print substr($1,2); }' >> vars.sh
  echo $password:$3 | awk '{print substr($1,2); }' >> vars.sh
  echo $tenantId:$4 | awk '{print substr($1,2); }' >> vars.sh
  echo $vmName:$5 | awk '{print substr($1,2); }' >> vars.sh
  echo $k3sArcClusterName:$6 | awk '{print substr($1,2); }' >> vars.sh
  echo $location:$7 | awk '{print substr($1,2); }' >> vars.sh
  sed -i '2s/^/export adminUsername=/' vars.sh
  sed -i '3s/^/export appId=/' vars.sh
  sed -i '4s/^/export password=/' vars.sh
  sed -i '5s/^/export tenantId=/' vars.sh
  sed -i '6s/^/export vmName=/' vars.sh
  sed -i '7s/^/export k3sArcClusterName=/' vars.sh
  sed -i '8s/^/export location=/' vars.sh

  chmod +x vars.sh 
  . ./vars.sh

  publicIp=$(curl icanhazip.com)

  # Installing Rancer K3s single master cluster using k3sup
  sudo -u $adminUsername mkdir /home/${adminUsername}/.kube
  curl -sLS https://get.k3sup.dev | sh
  sudo cp k3sup /usr/local/bin/k3sup
  sudo k3sup install --local --context arck3sdemo --ip $publicIp --k3s-version 'v1.24.7+k3s1'
  sudo chmod 644 /etc/rancher/k3s/k3s.yaml
  sudo cp kubeconfig /home/${adminUsername}/.kube/config
  chown -R $adminUsername /home/${adminUsername}/.kube/

  # Installing Helm 3
  sudo snap install helm --classic

  # Installing Azure CLI & Azure Arc Extensions
  sudo apt-get update
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

  sudo -u $adminUsername az extension add --name "connectedk8s"
  sudo -u $adminUsername az extension add --name "k8s-configuration"
  sudo -u $adminUsername az extension add --name "k8s-extension"
  sudo -u $adminUsername az extension add --name "customlocation"

  sudo -u $adminUsername az login --service-principal --username $appId --password $password --tenant $tenantId

  # Onboard the cluster to Azure Arc and enabling Container Insights using Kubernetes extension
  resourceGroup=$(sudo -u $adminUsername az resource list --query "[?name=='$vmName']".[resourceGroup] --resource-type "Microsoft.Compute/virtualMachines" -o tsv)
  sudo -u $adminUsername az connectedk8s connect --name $k3sArcClusterName --resource-group $resourceGroup --location $location --kube-config /home/${adminUsername}/.kube/config --tags 'Project=jumpstart_azure_arc_k8s' --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
  sudo -u $adminUsername az k8s-extension create -n "azuremonitor-containers" --cluster-name $k3sArcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers

  # resourceGroup=$(sudo -u $adminUsername az resource list --query "[?name=='$vmName']".[resourceGroup] --resource-type "Microsoft.Compute/virtualMachines" -o tsv)
  # sudo -u $adminUsername az connectedk8s connect --name $vmName --resource-group $resourceGroup --location $location --kube-config /home/${adminUsername}/.kube/config --tags 'Project=jumpstart_azure_arc_k8s' --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
  # sudo -u $adminUsername az k8s-extension create -n "azuremonitor-containers" --cluster-name $vmName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers

  sudo service sshd restart

# Creating "hello-world" Kubernetes yaml
sudo cat <<EOT >> hello-kubernetes.yaml
# hello-kubernetes.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-kubernetes
spec:
  type: LoadBalancer
  ports:
  - port: 32323
    targetPort: 8080
  selector:
    app: hello-kubernetes
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-kubernetes
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-kubernetes
  template:
    metadata:
      labels:
        app: hello-kubernetes
    spec:
      containers:
      - name: hello-kubernetes
        image: paulbouwer/hello-kubernetes:1.8
        ports:
        - containerPort: 8080
EOT

sudo cp hello-kubernetes.yaml /home/${adminUsername}/hello-kubernetes.yaml

} 2>&1 | tee -a $LOG_FILE # Send terminal output to log file

echo ""
tput setaf 6;echo "To check the deployment log, use the `tput sitm`cat ${LOG_FILE}`tput ritm` command." | expand | awk 'length($0) > length(longest) { longest = $0 } { lines[NR] = $0 } END { gsub(/./, "=", longest); print "/=" longest "=\\"; n = length(longest); for(i = 1; i <= NR; ++i) { printf("| %s %*s\n", lines[i], n - length(lines[i]) + 1, "|"); } print "\\=" longest "=/" }'
echo ""
tput sgr0