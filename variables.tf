# variables.tf - Variable Definitions

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources"
  type        = string
}

variable "zone" {
  description = "The GCP zone to deploy resources"
  type        = string
}

variable "credentials_file" {
  description = "Path to the GCP service account key file"
  type        = string
  default     = "" # Empty default means we'll use gcloud auth if not specified
}

variable "instance_name" {
  description = "Name of the VM instance"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the VM instance"
  type        = string
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
}

variable "ssh_username" {
  description = "Username for SSH access"
  type        = string
}

variable "ssh_pub_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "network_tags" {
  description = "Network tags to assign to the instance"
  type        = list(string)
  default     = ["ssh", "http-server", "https-server"]
}

variable "source_ranges" {
  description = "Source IP ranges for firewall rules"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Allow from anywhere (consider restricting this)
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}