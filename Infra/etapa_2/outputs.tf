output "frontend_public_ip" {
  value       = aws_instance.frontend.public_ip
  description = "IP Publica del Servidor Frontend (Usa esto en el navegador)"
}

output "backend_public_ip" {
  value       = aws_instance.backend.public_ip
  description = "IP del Servidor Backend para que GitHub Actions se conecte por SSH"
}