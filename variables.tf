variable "gcp_project" {
  description = "The GCP project identifier"
}

variable "gcp_region" {
  description = "The GCP region"
}

variable "gcp_zone" {
  description = "The GCP zone"
}

variable "project_name" {
  description = "The name of the project"
}

variable "domain_name" {
  description = "The wildcard domain name used by the project for example lab.example.com creates velociraptor.lab.example.com and timesketch.lab.example.com"
}

variable "gcp_velociraptor_machine_type" {
  description = "The machine type used by Velociraptor"
  default = "e2-small"
}

variable "velociraptor_version" {
  description = "The used version of Velociraptor" 
  default = "0.6.3"
}

variable "velociraptor_file_store_size" {
  description = "The capacity of the Velociraptor file store in GiB"
  default = "1024"
}

variable "elastic_cloud_api_key" {
  description = "The API key used by the Timesketch module"
}

variable "gcp_timesketch_machine_type_web" {
  description = "The machine type used by Timesketch web"
  default = "e2-small"
}

variable "gcp_timesketch_machine_type_worker" {
  description = "The machine type used by Timesketch workers"
  default = "e2-small"
}
