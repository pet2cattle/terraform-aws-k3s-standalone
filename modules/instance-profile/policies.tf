
locals {
  policies = {   
    eip = {
      policy      = file("${path.module}/policies/eip.json")
      policy_name = "eip-management"
    }
  }
}

resource "aws_iam_policy" "policy" {
  for_each = local.policies

  name   = format("k3s_%s", local.policies[each.key].policy_name)
  path   = "/k3s/${var.k3s_cluster_name}/"
  policy = local.policies[each.key].policy
}

resource "aws_iam_role_policy_attachment" "attachment" {
  for_each = local.policies

  role       = aws_iam_role.aws_ec2_custom_role.name
  policy_arn = aws_iam_policy.policy[each.key].arn
}

