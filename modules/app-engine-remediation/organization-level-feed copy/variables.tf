# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

