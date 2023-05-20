locals {
  policies = {   
    getce = {
      policy      = file("${path.module}/policies/get-ce.json")
      policy_name = "getce"
    }
  }
}

resource "aws_iam_policy" "policy" {
  for_each = local.policies

  name   = format("k3s_users_%s", local.policies[each.key].policy_name)
  path   = "/k3s/${var.k3s_cluster_name}/users/"
  policy = local.policies[each.key].policy
}



