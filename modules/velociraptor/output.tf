output "velociraptor_url" {
    description = "The URL to access velociraptor"
    value = "${var.domain_name}/gui/app/index.html"
}

output "velociraptor_password" {
    description = "The password used by the Velociraptor admin"
    value = random_password.velociraptor_password.result
}