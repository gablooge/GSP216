#!/bin/bash

while [[ -z "$(gcloud config get-value core/account)" ]]; 
do echo "waiting login" && sleep 2; 
done

while [[ -z "$(gcloud config get-value project)" ]]; 
do echo "waiting project" && sleep 2; 
done


gcloud compute firewall-rules create "app-allow-http" --network=my-internal-app --target-tags=lb-backend --allow=tcp:80 --source-ranges="0.0.0.0/0" --description="app-allow-http"

gcloud compute firewall-rules create "app-allow-health-check" --target-tags=lb-backend --allow=tcp --source-ranges="130.211.0.0/22,35.191.0.0/16" --description="app-allow-health-check"

export PROJECT_ID=$(gcloud info --format='value(config.project)')

gcloud beta compute instance-templates create instance-template-1 --subnet=projects/$PROJECT_ID/regions/us-central1/subnetworks/subnet-a --metadata=startup-script-url=gs://cloud-training/gcpnet/ilb/startup.sh --region=us-central1 --tags=lb-backend 


gcloud compute instance-groups managed create instance-group-1 --base-instance-name=instance-group-1 --template=instance-template-1 --size=1 --zone=us-central1-a

gcloud beta compute instance-groups managed set-autoscaling "instance-group-1" --zone "us-central1-a" --cool-down-period "45" --max-num-replicas "5" --min-num-replicas "1" --target-cpu-utilization "0.8" --mode "on"


gcloud beta compute instance-templates create instance-template-2 --subnet=projects/$PROJECT_ID/regions/us-central1/subnetworks/subnet-b --metadata=startup-script-url=gs://cloud-training/gcpnet/ilb/startup.sh --region=us-central1 --tags=lb-backend 

gcloud compute instance-groups managed create instance-group-2 --base-instance-name=instance-group-2 --template=instance-template-2 --size=1 --zone=us-central1-b

gcloud beta compute instance-groups managed set-autoscaling "instance-group-2" --zone "us-central1-b" --cool-down-period "45" --max-num-replicas "5" --min-num-replicas "1" --target-cpu-utilization "0.8" --mode "on"

gcloud beta compute instances create utility-vm --zone=us-central1-f --machine-type=f1-micro --subnet=subnet-a --private-network-ip=10.10.20.50 





gcloud beta compute health-checks create tcp my-ilb-health-check --region=us-central1 --port=80 --proxy-header=NONE --no-enable-logging --check-interval=5 --timeout=5 --unhealthy-threshold=2 --healthy-threshold=2
gcloud beta compute health-checks create tcp my-ilb-health-check --port=80 --proxy-header=NONE --no-enable-logging --check-interval=5 --timeout=5 --unhealthy-threshold=2 --healthy-threshold=2

gcloud compute backend-services create my-ilb \
    --load-balancing-scheme=internal \
    --protocol=tcp \
    --region=us-central1 \
    --health-checks=my-ilb-health-check \
    --health-checks-region=us-central1

gcloud compute backend-services add-backend my-ilb \
    --region=us-central1 \
    --instance-group=instance-group-1 \
    --instance-group-zone=us-central1-a
gcloud compute backend-services add-backend my-ilb \
    --region=us-central1 \
    --instance-group=instance-group-2 \
    --instance-group-zone=us-central1-b

gcloud compute addresses create my-ilb-ip \
    --region us-central1 --subnet subnet-b --addresses 10.10.30.5

gcloud compute forwarding-rules create front-ilb \
    --region=us-central1 \
    --load-balancing-scheme=internal \
    --network=my-internal-app \
    --subnet=subnet-b \
    --address=my-ilb-ip \
    --ip-protocol=TCP \
    --ports=80 \
    --backend-service=my-ilb \
    --backend-service-region=us-central1

