output "timesketch_admin_password" {
    value = random_string.timesketch_admin_password.result
}

output "timesketch_url" {
  description = "The domain name used Timesketch"
  value = "https://${var.domain_name}"
}
