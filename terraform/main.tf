resource "aws_security_group" "obs_sg" {
  name        = "observabilidade-sg"
  description = "Acesso SSH, Grafana, Prometheus"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3300
    to_port     = 3300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Ping Exporter"
    from_port   = 9427
    to_port     = 9427
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "obs_ec2" {
  ami = "ami-011e7b514a4f15472"        // debian 12
  instance_type               = "t3.small"
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.obs_sg.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name = "leopoldo-ec2-observabilidade"
  }
}
