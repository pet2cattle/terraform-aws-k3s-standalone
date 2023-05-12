data "aws_caller_identity" "current" {}

locals {
  template_vars = { 
                    K3S_TOKEN           = var.k3s_token, 
                    K3S_CLUSTERNAME     = var.k3s_cluster_name
                    REGION              = var.region
                    K3S_BUCKET          = var.s3_bucket_name
                    K3S_BACKUP_PREFIX   = "${var.s3_backup_prefix}/${var.k3s_cluster_name}"
                    MAIN_VPC_CIDR_BLOCK = var.main_vpc_cidr_block
                    ACCOUNT_ID          = data.aws_caller_identity.current.account_id
                    IAM_ROLE            = var.iam_role_arn
                  }
}

data "template_cloudinit_config" "k3s_master_ud" {
  for_each = var.k3s_master_instances

  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/userdata/init.cfg", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/userdata/install_k3s.sh",  merge(local.template_vars, {
                                                                                                        EIP_ID = aws_eip.public[each.key].id
                                                                                                      })
                                                                                              ) 
  }
}
