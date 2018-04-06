variable "project" {
  description = "Project ID"
}

variable "region" {
  default     = "europe-west4"
  description = "Region"
}

variable "cluster_name" {
  default     = "cluster"
  description = "Cluster name"
}

variable "zone" {
  default     = "europe-west4-c"
  description = "Zone"
}

variable "initial_node_count" {
  default     = 3
  description = "Initial node count"
}

variable "gke_version" {
  default     = "1.8.8-gke.0"
  description = "GKE version"
}

variable "node_disk_size" {
  default     = 21
  description = "Disk size"
}

variable "node_machine_type" {
  default     = "g1-small"
  description = "Machine type"
}
