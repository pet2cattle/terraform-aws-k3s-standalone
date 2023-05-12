#!/bin/bash

set -x

apt-get update

apt-get install jq -y
apt-get install git -y

# install helm
curl -fsSL -o - https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /etc/bashrc 

# manually install k
curl -fsSL -o /usr/local/bin/k https://raw.githubusercontent.com/jordiprats/bash-k/master/k
chmod +x /usr/local/bin/k

# aws cli config
mkdir -p ~/.aws
echo "[default]" > ~/.aws/config
echo "region = ${REGION}" >> ~/.aws/config

# in case we are not the only instance alive, we should wait for the other one to die (release eip)

while [ "$(aws ec2 describe-addresses --allocation-ids ${EIP_ID} | jq -r .Addresses[0].InstanceId)" != "null" ];
do
  sleep 15;
done

aws ec2 associate-address --instance-id "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --allocation-id ${EIP_ID}

sleep 1m

# install k3s

FLANNEL_IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

BASE_OPTS=$(echo  "" \
                  " --token ${K3S_TOKEN}" \
                  " --node-ip $LOCAL_IP" \
                  " --flannel-iface $FLANNEL_IFACE" \
                  ""
            )

MASTER_OPTS=$(echo  "" \
                  " --etcd-s3 " \
                  " --etcd-s3-bucket ${K3S_BUCKET}" \
                  " --etcd-s3-folder ${K3S_BACKUP_PREFIX}" \
                  " --etcd-s3-region ${REGION}" \
                  " --write-kubeconfig-mode=644" \
                  ""
            )


export BASE_OPTS="$BASE_OPTS"

BACKUPS_AVAILABLE=$(aws s3 ls s3://${K3S_BUCKET}/${K3S_BACKUP_PREFIX}/ | wc -l)

if [ $BACKUPS_AVAILABLE -eq 0 ];
then
  # no backups available, install k3s
  echo "Cluster init - master mode"
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --cluster-init $BASE_OPTS $MASTER_OPTS

  if [ "$CLOUD_ENABLED" == "true" ];
  then
    # wait for k3s to be Pending (aws-cloud-controller is needed to get to Running state)
    until kubectl get pods -A | grep Pending > /dev/null; 
    do 
      sleep 30; 
    done
  fi

else
  # backups available, restore k3s
  echo "Restore from backup"

  RESTORE_BACKUP=""
  RESTORE_TS="0"
  for BACKUP in $(aws s3 ls s3://${K3S_BUCKET}/${K3S_BACKUP_PREFIX}/ | awk '{ print $NF }');
  do
    TIMESTAMP=$(echo $BACKUP | rev | cut -d'-' -f1 | rev)
    
    if [ $TIMESTAMP -gt $RESTORE_TS ];
    then
      RESTORE_BACKUP=$BACKUP
      RESTORE_TS=$TIMESTAMP
    fi
  done

  if [ $RESTORE_TS -eq 0 ];
  then
    echo "No backups available"
    exit 1
  fi

  echo "Restore backup $RESTORE_BACKUP - master mode"
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s -  $BASE_OPTS $MASTER_OPTS \
                                                                    --cluster-reset \
                                                                    --cluster-reset-restore-path="$RESTORE_BACKUP"

  # give it some time
  sleep 5m

  journalctl -xe

  # wait restore process to finish
  until journalctl -xe | grep "Managed etcd cluster membership has been reset";
  do
    sleep 5;
  done
  
  sed -e '/--cluster-reset/d' -i /etc/systemd/system/k3s.service

  systemctl daemon-reload

fi

#
# post install master
#

# add cronjob to backup etcd
(crontab -l 2>/dev/null; echo "0 0 * * * k3s etcd-snapshot save --s3 --s3-bucket=${K3S_BUCKET} --etcd-s3-folder=${K3S_BACKUP_PREFIX} --etcd-s3-region=${REGION}"; ) | crontab -
(crontab -l 2>/dev/null; echo "15 0 * * * k3s etcd-snapshot prune --s3 --s3-bucket=${K3S_BUCKET} --etcd-s3-folder=${K3S_BACKUP_PREFIX} --etcd-s3-region=${REGION}"; ) | crontab -

# wait for k3s to have Running pods
until kubectl get pods -A | grep Running > /dev/null; 
do 
  sleep 5; 
done

echo "== restored configmap=="
kubectl get ConfigMap k8s-restored -n kube-system -o yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: k8s-restored
  namespace: kube-system
data:
  date: "$(date)"
  ts: "$(date +%s)"
EOF

echo "== updated configmap=="
kubectl get ConfigMap k8s-restored -n kube-system -o yaml

# initial backup
k3s etcd-snapshot save --s3 --s3-bucket=${K3S_BUCKET} --etcd-s3-folder=${K3S_BACKUP_PREFIX} --etcd-s3-region=${REGION}
