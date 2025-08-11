output "cluster_name" {
  value = aws_eks_cluster.my_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.my_cluster.endpoint
}

output "kubeconfig_command" {
  value = "aws eks --regin ${var.region} update-kubeconfig --name ${aws_eks_cluster.my_cluster.name}"
}
