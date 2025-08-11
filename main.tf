# 1. vpc
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "eks_vpc"
  }
}

# 2. Subnets
resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_customer_owned_ip_on_launch = true
  tags = {
    Name = "sunet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_customer_owned_ip_on_launch = true
  tags = {
    Name = "subnet2"
  }
}

# 3.Internet gateway + Route table
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource "aws_route_table_association" "a2" {
  subnet_id = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

# 4.EkS Cluster IAM role
data "aws_iam_policy_document" "eks_assume_role" {
  statement{
    actions = ["sts:AssumeRole"]
    principals{
      type = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRole"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# 5.Security Group
resource "aws_security_group" "eks_sg" {
  name = "eks-cluster-sg"
  vpc_id = aws_vpc.eks_vpc.id
  description = "Eks cluster security group."
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6.Eks cluster
resource "aws_eks_cluster" "my_cluster" {
  name = "my_cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = [aws_subnet.subnet1.id,aws_subnet.subnet2.id]
    security_group_ids = [aws_security_group.eks_sg.id]
  }
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# 7.Node group IAM role
data "aws_iam_policy_document" "node_assume_role" {
  statement{
    actions = ["sts:AssumeRole"]
    principals{
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "eks_node_role" {
  name = "eksnoderole"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_CNI" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Node group
resource "aws_eks_node_group" "eks_nodes" {
  cluster_name = aws_eks_cluster.my_cluster.name
  node_group_name = "my-node-group"
  node_role_arn = aws_iam_role.eks_node_role.arn
  subnet_ids = [aws_subnet.subnet1.id,aws_subnet.subnet2.id]
  scaling_config {
    desired_size = 2
    max_size = 2
    min_size = 1
  }
  instance_types = ["t3.micro"]
  depends_on = [ 
  aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
  aws_iam_role_policy_attachment.node_CNI,
  aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly 
  ]
}
