from diagrams import Cluster, Diagram
from diagrams.aws.compute import EC2
from diagrams.aws.general import User
from diagrams.aws.security import IAM
from diagrams.aws.network import VPC, InternetGateway
from diagrams.programming.language import Bash
from diagrams.aws.storage import S3
from diagrams.onprem.client import User as LocalUser

# Define the diagram
with Diagram("AWS-k3s-standalone", show=False):
    # IAM resources
    with Cluster("IAM"):
        policy = IAM("getce IAM Policy")
        user = IAM("awscost IAM User")

        user >> policy
    
    # Instance profile resources
    with Cluster("Instance Profile"):
        instance_profile = IAM("IAM Instance Profile")
        eip_policy = IAM("eip IAM Policy")

        instance_profile >> eip_policy
    
    with Cluster("EC2"):
        cloudinit_config = Bash("CloudInit Config")
        autoscaling_group = EC2("Auto Scaling Group")
        elastic_ip = EC2("Elastic IP")
        launch_template = EC2("Launch Template")

        autoscaling_group >> launch_template >> cloudinit_config

        autoscaling_group >> instance_profile
        eip_policy >> elastic_ip

        cloudinit_config << user


    with Cluster("S3"):
        s3_bucket = S3("backups Bucket")
        bucket_policy = IAM("Bucket Policy")

        s3_bucket >> bucket_policy

        bucket_policy >> instance_profile

    
