variable "bundle_path" {
  description = "Path used to write the intermediate Cloud Function code bundle."
  type        = string
  default     = "./bundle.zip"
}

variable "name" {
  description = "Arbitrary string used to name created resources."
  type        = string
  default     = "asset-feed"
}

variable "organization_id" {
  description = "Organization id that references existing organization."
  type        = string
}

variable "project_id" {
  description = "Project id that references existing project."
  type        = string
}

variable "region" {
  description = "Compute region used in the example."
  type        = string
  default     = "us-central1"
}

variable "project_create" {
  description = "Create project instead of using an existing one."
  type        = bool
  default     = false
}

variable "source_dir" {
  description = "value of the source dir where the Cloud function folder is"
  type        = string
  default     = "./cf"
}

