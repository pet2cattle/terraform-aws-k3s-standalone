resource "aws_iam_user" "ak" {
  for_each = var.users

  name = each.key
  path = try(each.value.iam_path+var.k3s_cluster_name+"/", "/system/")

  tags = var.tags
}

resource "aws_iam_access_key" "ak" {
  for_each = var.users

  user = aws_iam_user.ak[each.key].name
}

resource "aws_iam_user_policy_attachment" "attachment" {
  for_each = var.users

  user       = aws_iam_user.ak[each.key].name
  policy_arn = aws_iam_policy.policy[each.value.policy].arn
}

output "secrets" {
  value = aws_iam_access_key.ak
}

output "users" {
  value = aws_iam_user.ak
}