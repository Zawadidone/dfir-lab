output "gcp_project" {
  description = "The GCP project id"
  value       = var.gcp_project
}

output "external_ip_address_velociraptor" {
  value = google_compute_global_address.velociraptor.address
}

output "velociraptor_url" {
  description = "The URL to access velociraptor"
  value       = "https://${module.velociraptor.velociraptor_url}"
}

output "velociraptor_password" {
  description = "The Velociraptor admin password"
  value       = module.velociraptor.velociraptor_password
  sensitive   = true
}

output "velociraptor_bucket_name" {
  description = "The bucket used by Velociraptor"
  value       = "${var.project_name}-velociraptor"
}

output "external_ip_address_timesketch" {
  value = google_compute_global_address.timesketch.address
}

output "timesketch_url" {
  description = "The URL to access Timesketch"
  value       = module.timesketch.timesketch_url
}

output "timesketch_password" {
  description = "The Timesketch admin password"
  value       = random_string.timesketch_admin_password.result
  sensitive   = true
}