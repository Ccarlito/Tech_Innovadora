terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================
# IAM - USA EL ROL PREEXISTENTE DE AWS ACADEMY
# ==========================================
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile-v2"    # <- cambia a v2
  role = data.aws_iam_role.lab_role.name
}


# ==========================================
# 1. RED VPC , SUBNETS Y GATEWAY
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-subnet" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ==========================================
# 2. SECURITY GROUPS (REQUISITO DE SEGURIDAD DE LA RÚBRICA)
# ==========================================

# SG para el Frontend (Público a Internet)
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Permite trafico HTTP externo para el Frontend"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH para el pipeline de GitHub Actions
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Acceso Web público
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG para los Backends y la BD (Restringido)
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Solo permite trafico interno desde el Frontend y SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH para el pipeline de GitHub Actions
  }
  ingress {
    from_port   = 8080
    to_port     = 8081
    protocol    = "tcp"
    security_groups = [aws_security_group.frontend.id] # Solo el Front puede consultar los backends
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    self        = true # Permite comunicación interna con MySQL en la misma máquina
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 3. ORIGEN DE DATOS (ECR Y AMIs)
# ==========================================

data "aws_ecr_repository" "frontend" { name = "${var.project_name}-frontend" }
data "aws_ecr_repository" "back_despachos" { name = "${var.project_name}-backend-despachos" }
data "aws_ecr_repository" "back_ventas" { name = "${var.project_name}-backend-ventas" }

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ==========================================
# 4. INSTANCIAS EC2 SEPARADAS (REQUISITO EXPLICITO)
# ==========================================

# Instancia 1: Servidor Web Frontend
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name  # <- ECR access

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker aws-cli
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    # Crear carpeta con permisos correctos desde el inicio
    mkdir -p /home/ec2-user/app
    chown -R ec2-user:ec2-user /home/ec2-user/app
  EOF

  tags = { Name = "${var.project_name}-frontend-server" }
}

# Instancia 2: Servidor de Microservicios Backend y MySQL
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small" # t3.small tiene 2GB de RAM para aguantar los 2 backends + MySQL cómodos
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name  # <- ECR access

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker aws-cli
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    # Docker Compose v2
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    # Crear carpeta con permisos correctos desde el inicio
    mkdir -p /home/ec2-user/app
    chown -R ec2-user:ec2-user /home/ec2-user/app
  EOF

  tags = { Name = "${var.project_name}-backend-server" }
}