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

variable "gcp_lb_ip_address" {
  description = "The IP address used by the load balancer" 
}

variable "gcp_machine_type_web" {
  description = "The machine type used by Timesketch web"
}

variable "gcp_machine_type_worker" {
  description = "The machine type used by Timesketch workers"
}

variable "domain_name" {
  description = "The domain name used Timesketch"
}

variable "elastic_cloud_api_key" {
  description = ""
}

variable "timesketch_version" {
  description = ""
}

variable "web_target_size" {
  description = ""
}

variable "worker_target_size" {
  description = ""
}

variable "file_store_size" {
  description = "The capacity of the file store in GiB"
}