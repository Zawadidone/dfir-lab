#terraform {
  # Use local state storage by default. For production environments please
  # consider  using a more robust backend.
  #backend "local" {
  #  path = "terraform.tfstate"
  #}

  # Use Google Cloud Storage for robust, collaborative state storage.
  # Note: The bucket name need to be globally unique.
  #backend "gcs" {
  #  bucket = "GLOBALLY UNIQ BUCKET NAME"
  #}
#}

module "velociraptor" {
  source           = "./modules/velociraptor"
  project_name     = var.project_name
  gcp_project      = var.gcp_project
  gcp_region       = var.gcp_region
  gcp_zone         = var.gcp_zone
  gcp_machine_type = var.gcp_velociraptor_machine_type
  gcp_network          = google_compute_network.network.id
  gcp_lb_ip_address = google_compute_global_address.velociraptor.id
  domain_name      = "velociraptor.${var.domain_name}"
  velociraptor_version = var.velociraptor_version
  velociraptor_file_store_size = var.velociraptor_file_store_size
}


module "timesketch" {
  source               = "./modules/timesketch"
  project_name     = var.project_name
  gcp_project          = var.gcp_project
  gcp_region           = var.gcp_region
  gcp_zone             = var.gcp_zone
  gcp_network          = google_compute_network.network.id
  gcp_lb_ip_address       = google_compute_global_address.timesketch.id
  domain_name      = "timesketch.${var.domain_name}"
  elastic_cloud_api_key = var.elastic_cloud_api_key
  gcp_machine_type_web = var.gcp_timesketch_machine_type_web
  gcp_machine_type_worker = var.gcp_timesketch_machine_type_worker
  timesketch_version = "master" 
}

resource "google_compute_network" "network" {
  name = var.project_name
  description = "The network for Velociraptor and Timesketch"
  routing_mode = "REGIONAL"
  #delete_default_routes_on_create = true 
}

resource "google_compute_global_address" "velociraptor" {
  name         = "${var.project_name}-velociraptor"
  description  = "The IP address used by the load balancers of Velociraptor"
  address_type = "EXTERNAL"
}

resource "google_compute_global_address" "timesketch" {
  name         = "${var.project_name}-timesketch"
  description  = "The IP address used by the load balancers of Timesketch"
  address_type = "EXTERNAL"
}

resource "google_compute_router" "router" {
  name    = "${var.project_name}"
  network = google_compute_network.network.id
}

resource "google_compute_router_nat" "nat" {
  name    = "${var.project_name}"
  router                             = google_compute_router.router.name
  region  = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
