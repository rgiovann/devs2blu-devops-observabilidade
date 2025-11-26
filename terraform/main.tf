resource "aws_security_group" "obs_sg" {
  name        = "observabilidade-sg"
  description = "Acesso SSH e HTTPS (Nginx com autenticacao)"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (Nginx reverse proxy)"
    from_port   = 443
    to_port     = 443
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

  tags = {
    Name = "observabilidade-sg"
  }
}

resource "aws_instance" "obs_ec2" {
  ami                         = "ami-011e7b514a4f15472"  # Debian 12
  instance_type               = "t3.small"
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.obs_sg.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/user-data.sh")

  root_block_device {
    volume_size = 20  # GB (ajuste se necessário)
    volume_type = "gp3"
  }

  tags = {
    Name    = "leopoldo-ec2-observabilidade"
    Project = "devs2blu-observabilidade"
  }
}
