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
  description = "The wildcard domain name used by the project for example rotterdam.example.com creates velociraptor.rotterdam.example.com and timesketch.rotterdam.example.com" 
}

variable "gcp_machine_type" {
  description = "The machine type used by Velociraptor"
}

variable "gcp_network" {
  description = "The VPC network used by Velociraptor"
}

variable "gcp_lb_ip_address" {
  description = "The IP-address used by the load balancer"
}

variable "velociraptor_version" {
  description = "The used version of Velociraptor" 
}

variable "velociraptor_network_name" {
  description = "The name of the network used by the Velociraptor master and minions"
  default = "velociraptor.lab"
}

variable "velociraptor_master_ip_address" {
  description = "The IP-address used by the Velociraptor master"
  default = "10.0.0.4"
}

variable "velociraptor_file_store_size" {
  description = "The capacity of the Velociraptor file store in GiB"
}

