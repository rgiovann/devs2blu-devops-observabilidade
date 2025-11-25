output "ec2_public_ip" {
  value = aws_instance.obs_ec2.public_ip
}

output "grafana_url" {
  value = "http://${aws_instance.obs_ec2.public_ip}:3300"
}

output "prometheus_url" {
  value = "http://${aws_instance.obs_ec2.public_ip}:9090"
}
