# ─── COTURN — WebRTC TURN/STUN relay server ─────────────────────────────────
#
# Why a dedicated EC2 instead of a pod in EKS?
#   - TURN needs a fixed public IP (Elastic IP) so it can be put in DNS
#   - TURN relay ports are 49152-65535 UDP — impossible to expose from K8s
#   - t3.micro handles hundreds of concurrent WebRTC sessions (just relay)
#
# Authentication: COTURN REST API (HMAC-SHA1)
#   - Shared secret is stored here and in AWS Secrets Manager
#   - Backend generates time-limited credentials on the fly (never exposes secret)
#   - Browser gets: {username: "timestamp", credential: HMAC(secret, timestamp)}
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

# Random HMAC secret — generated once, stored in Secrets Manager
resource "random_password" "turn_secret" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "turn_secret" {
  name                    = "${var.name}/turn-secret"
  description             = "COTURN HMAC shared secret for WebRTC TURN auth"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "turn_secret" {
  secret_id     = aws_secretsmanager_secret.turn_secret.id
  secret_string = random_password.turn_secret.result
}

# ─── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "coturn" {
  name        = "${var.name}-coturn"
  description = "COTURN STUN/TURN server"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-coturn" })

  # STUN/TURN signaling
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN UDP"
  }
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN TCP"
  }
  ingress {
    from_port   = 5349
    to_port     = 5349
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURNS TLS"
  }

  # Media relay range (WebRTC RTP)
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN relay ports"
  }

  # SSH (restrict to your IP in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
    description = "SSH admin"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── Elastic IP ──────────────────────────────────────────────────────────────

resource "aws_eip" "coturn" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-coturn" })
}

resource "aws_eip_association" "coturn" {
  instance_id   = aws_instance.coturn.id
  allocation_id = aws_eip.coturn.id
}

# ─── IAM role (to pull secret from Secrets Manager) ─────────────────────────

data "aws_iam_policy_document" "coturn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "coturn" {
  name               = "${var.name}-coturn"
  assume_role_policy = data.aws_iam_policy_document.coturn_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "coturn_secrets" {
  name = "read-turn-secret"
  role = aws_iam_role.coturn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.turn_secret.arn
    }]
  })
}

resource "aws_iam_instance_profile" "coturn" {
  name = "${var.name}-coturn"
  role = aws_iam_role.coturn.name
}

# ─── EC2 Instance ─────────────────────────────────────────────────────────────

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "coturn" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.coturn.id]
  iam_instance_profile   = aws_iam_instance_profile.coturn.name
  key_name               = var.key_pair_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  # aws_eip.coturn has no dependency on aws_instance, so it is created first.
  # Passing its public_ip here means turnserver.conf always gets the correct EIP,
  # not a temporary public IP from IMDS (which changes before EIP association).
  user_data = base64encode(templatefile("${path.module}/coturn-userdata.sh.tpl", {
    turn_secret    = random_password.turn_secret.result
    realm          = var.realm
    region         = var.region
    secret_arn     = aws_secretsmanager_secret.turn_secret.arn
    min_relay_port = 49152
    max_relay_port = 65535
    public_ip      = aws_eip.coturn.public_ip
  }))

  tags = merge(var.tags, { Name = "${var.name}-coturn" })

  lifecycle {
    ignore_changes = [ami]
  }
}
