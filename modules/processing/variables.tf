variable "project_name" {
  description = "The name of the project"
}

variable "gcp_project" {
  description = "The GCP project identifier"
}

variable "gcp_region" {
  description = "The GCP region"
}

variable "gcp_zone" {
  description = "The GCP zone"
}

variable "gcp_network" {
  description = "The GCP network zone"
}

variable "gcp_machine_type" {
  description = "The machine type used by Timesketch web"
}

variable "timesketch_version" {
  description = ""
}

variable "timesketch_password" {
  description = ""
  sensitive   = true
}

variable "timesketch_web_internal" {
  description = ""
}

variable "bucket_name" {
  description = ""
}

