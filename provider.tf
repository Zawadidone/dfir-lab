terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.8.0"
    }
  }
} 

provider "google" {
  project     = var.gcp_project
  region      = var.gcp_region
}
