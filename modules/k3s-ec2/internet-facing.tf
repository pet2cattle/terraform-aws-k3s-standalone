resource "aws_eip" "public" {
  for_each = var.k3s_master_instances

  vpc = true

  tags = merge(var.tags, {
    Name        = "k3s-master"
  })
}