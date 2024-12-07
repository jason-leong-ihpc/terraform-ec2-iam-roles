# data "aws_vpc" "selected" {
#  id = var.vpc_id
# }

data "aws_vpc" "selected" {
 filter {
   name = "tag:Name"
   values = ["shared-vpc"]
 }
}

data "aws_subnets" "public" {
 filter {
   name   = "vpc-id"
#    values = [var.vpc_id]
   values = [data.aws_vpc.selected.id]
 }
 filter {
   name   = "tag:Name"
   values = ["*public*"]
 }
}

data "aws_subnets" "private" {
 filter {
   name   = "vpc-id"
#    values = [var.vpc_id]
   values = [data.aws_vpc.selected.id]
 }
 filter {
   name   = "tag:Name"
   values = ["*private*"]
 }
}