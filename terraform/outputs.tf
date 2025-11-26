output "ec2_public_ip" {
  description = "IP publico da instancia EC2"
  value       = aws_instance.obs_ec2.public_ip
}

output "access_url" {
  description = "URL de acesso ao sistema (HTTPS com autenticacao)"
  value       = "https://${aws_instance.obs_ec2.public_ip}"
}

output "ssh_command" {
  description = "Comando SSH para conectar na instancia"
  value       = "ssh -i ${var.key_name}.pem admin@${aws_instance.obs_ec2.public_ip}"
}

output "credentials" {
  description = "Credenciais de acesso (usuario / senha)"
  value       = "admin / admin2025"
  sensitive   = true  # Oculta no plan/apply sem -json
}
