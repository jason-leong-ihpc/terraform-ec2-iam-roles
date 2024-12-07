### CREATE KEY PAIR AND RETRIEVE PRIVATE KEY ###

### AVOID GENERATING KEYS IN TERRAFORM AS PRIVATE/PUBLIC KEYS WILL APPEAR IN TFSTATE FILES ###

# resource "tls_private_key" "tlsauth" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "aws_key_pair" "auth" {
#   key_name   = "${var.name_prefix}-key"
#     public_key = tls_private_key.tlsauth.public_key_openssh
#   tags = {
#     Name = "${var.name_prefix}-key"
#   }
# provisioner "local-exec" { 
#     command = "echo '${tls_private_key.tlsauth.private_key_pem}' > '../keys/${var.name_prefix}-key.pem' && chmod 400 '../keys/${var.name_prefix}-key.pem'"
#   }
# }

### CREATE DYNAMODB TABLE FOR BOOK INVENTORY ###

resource "aws_dynamodb_table" "book_inventory" {
  name         = "${var.name_prefix}-bookinventory"
  billing_mode = "PAY_PER_REQUEST" # Use on-demand billing mode for flexibility
  hash_key     = "ISBN"            # Partition Key
  range_key    = "Genre"           # Sort Key

  attribute {
    name = "ISBN"
    type = "S"                     # String type
  }

  attribute {
    name = "Genre"
    type = "S"                     # String type
  }

  tags = {
    Name        = "BookInventoryTable"
    Environment = "Production"
  }
}

### CREATE IAM POLICY ###

data "aws_iam_policy_document" "dynamodb_policy" {
  statement {
    sid     = "VisualEditor0"
    effect  = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeImport",
      "dynamodb:ConditionCheckItem",
      "dynamodb:DescribeContributorInsights",
      "dynamodb:Scan",
      "dynamodb:ListTagsOfResource",
      "dynamodb:Query",
      "dynamodb:DescribeStream",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:DescribeGlobalTableSettings",
      "dynamodb:PartiQLSelect",
      "dynamodb:DescribeTable",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeGlobalTable",
      "dynamodb:GetItem",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeExport",
      "dynamodb:GetResourcePolicy",
      "dynamodb:DescribeKinesisStreamingDestination",
      "dynamodb:DescribeBackup",
      "dynamodb:GetRecords",
      "dynamodb:DescribeTableReplicaAutoScaling"
    ]

    resources = [
      aws_dynamodb_table.book_inventory.arn
    ]
  }

  statement {
    sid     = "VisualEditor1"
    effect  = "Allow"
    actions = [
      "dynamodb:ListContributorInsights",
      "dynamodb:DescribeReservedCapacityOfferings",
      "dynamodb:ListGlobalTables",
      "dynamodb:ListTables",
      "dynamodb:DescribeReservedCapacity",
      "dynamodb:ListBackups",
      "dynamodb:GetAbacStatus",
      "dynamodb:ListImports",
      "dynamodb:DescribeLimits",
      "dynamodb:DescribeEndpoints",
      "dynamodb:ListExports",
      "dynamodb:ListStreams"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "dynamodb_policy" {
  name   = "${var.name_prefix}-dynamodb-read"
  policy = data.aws_iam_policy_document.dynamodb_policy.json
}

### CREATE IAM ROLE AND ATTACH POLICY ###

resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-dynamodb-read-role"

  assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "sts:AssumeRole"
                ],
                "Principal": {
                    "Service": [
                        "ec2.amazonaws.com"
                    ]
                }
            }
        ]
    })
}



### ATTACH THE DYNAMODB POLICY TO THE IAM ROLE ###

resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

### ATTACH ROLE TO INSTANCE PROFILE ###

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

### CREATE EC2 AND ATTACH ROLE ###


# choose subnet based on whether public or private subnet required
locals {
 selected_subnet_ids = var.public_subnet ? data.aws_subnets.public.ids : data.aws_subnets.private.ids
}


resource "aws_instance" "ec2_db_reader" {


 ami                    = "ami-04c913012f8977029"
 instance_type          = var.instance_type
 subnet_id = local.selected_subnet_ids[0] # just use first private/public subnet in the vpc 
 vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
 key_name                = "${var.name_prefix}-key" # use pre-created key
# key_name = aws_key_pair.auth.key_name # use this if key is created in tf code
iam_instance_profile = aws_iam_instance_profile.instance_profile.name

 associate_public_ip_address = var.public_subnet
 tags = {
   Name = "${var.name_prefix}-dynamodb-reader"
 }
}

resource "aws_security_group" "ec2_security_group" {
 name_prefix = "${var.name_prefix}-dynamodb-reader"
 description = "Allow traffic to webapp"
 vpc_id      = data.aws_vpc.selected.id


 ingress {
   from_port        = 22
   to_port          = 22
   protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
 }

 ingress {
   from_port        = -1
   to_port          = -1
   protocol         = "icmp"
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
 }


 egress {
   from_port        = 443
   to_port          = 443
   protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
#    ipv6_cidr_blocks = ["::/0"]
 }


 lifecycle {
   create_before_destroy = true
 }
}

