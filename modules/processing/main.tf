locals {
  api_services = [
    "compute.googleapis.com",
    "file.googleapis.com",
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
  ]
}

resource "google_project_service" "api_services" {
  count              = length(local.api_services)
  project            = var.gcp_project
  service            = local.api_services[count.index]
  disable_on_destroy = false
}

resource "google_pubsub_topic" "default" {
  name  = "${var.project_name}-hunt-collections"
  
  depends_on = [google_project_service.api_services] 
}

resource "google_storage_notification" "velociraptor_bucket" {
  bucket         = var.bucket_name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.default.id
  event_types    = ["OBJECT_FINALIZE"]
  
  depends_on = [google_project_service.api_services, google_pubsub_topic_iam_binding.binding]
}

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.default.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
  
  depends_on = [google_project_service.api_services] 
}

resource "google_storage_bucket" "function" {
  name  = "${var.project_name}-function"
  location      = var.gcp_region
  storage_class = "STANDARD"
  force_destroy = true
  
  depends_on = [google_project_service.api_services] 
}

data "archive_file" "function" {
  type        = "zip"
  output_path  = "${path.module}/templates/scripts/cloud-function.zip"

  source {
    content  = file("${path.module}/templates/scripts/cloud-function/main.py")
    filename = "main.py"
  }
  
  source {
    content  = file("${path.module}/templates/scripts/cloud-function/requirements.txt")
    filename = "requirements.txt"
  }
}

resource "google_storage_bucket_object" "function" {
  name  = "${var.project_name}-function-object"
  bucket = google_storage_bucket.function.name
  source = "${path.module}/templates/scripts/cloud-function.zip"
  
  depends_on = [google_project_service.api_services, data.archive_file.function]
}


resource "google_cloudfunctions_function" "default" {
  name  = "${var.project_name}-start-plaso"
  description = "This function creates a compute engine to process a hunt collection with Plaso and upload the timeline to Timesketch using the importer"
  runtime     = "python38" 
  ingress_settings = "ALLOW_INTERNAL_ONLY"
  entry_point           = "run"
  source_archive_bucket = google_storage_bucket.function.name 
  source_archive_object = google_storage_bucket_object.function.name
  region = "europe-west1" # variable
  #max_instances = ""  

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "${google_pubsub_topic.default.name}"
  }

  environment_variables = {
      TEMPLATE_URL = google_compute_instance_template.default.self_link
      PROJECT_ID = var.gcp_project
      ZONE = var.gcp_zone
      STARTUP_SCRIPT = data.template_file.default.rendered
  }
  
  depends_on = [google_project_service.api_services]
}

resource "google_compute_subnetwork" "default" {
  name          = "plaso"
  ip_cidr_range = "10.1.0.0/16" 
  region        = var.gcp_region
  network       = var.gcp_network
  private_ip_google_access = true
}

data "template_file" "default" {
  template = file("${path.module}/templates/scripts/plaso-to-timesketch.sh.tpl")
  vars = {
    TIMESKETCH_VERSION        = var.timesketch_version
    TIMESKETCH_PASSWORD       = var.timesketch_password
    TIMESKETCH_URL      = "http://${var.timesketch_web_internal}:80"
  }
}

resource "google_compute_instance_template" "default" {
  name_prefix  = "${var.project_name}-plaso"
  machine_type = var.gcp_machine_type
  tags         = ["allow-iap"]

  metadata_startup_script = data.template_file.default.rendered

  depends_on = [
    google_project_service.api_services, 
    google_compute_subnetwork.default
  ]

  network_interface {
    subnetwork =  google_compute_subnetwork.default.id
  }

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    disk_size_gb  = "50"
    disk_type = "pd-ssd"
    type = "PERSISTENT"
  }

  lifecycle {
    create_before_destroy = true
  }
  
  # logging driver
  service_account {
    scopes = ["cloud-platform"]
  }
  
}

resource "google_compute_firewall" "iap" {
  name          = "${var.project_name}-plaso-allow-iap"
  direction     = "INGRESS"
  network       = var.gcp_network
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["allow-iap"]
}
