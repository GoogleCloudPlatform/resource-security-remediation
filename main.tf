/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


module "asset-feed-project" {
  source         = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/project"
  name           = var.project_id
  project_create = var.project_create # Optional only if project_create is true. Set this to false to use an existing project
  billing_account = var.billing_account_id # Optional only if project_create is true. Remove this parameter from the module if project_create is false
  parent = "folders/${var.folder_id}" # Optional only if project_create is true. Remove this parameter from the module if project_create is false
  services = [
    "cloudasset.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "compute.googleapis.com",
    "appengine.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudbilling.googleapis.com",
    "securitycenter.googleapis.com"
  ]
}

 #Create the SCC Finding Source

 resource "google_scc_source" "app_engine_iap_finding_source" {
  display_name = "app_engine_iap_finding_source" #DO NOT CHANGE
  organization = var.organization_id
  description  = "This is an App Engine IaP source that checks if IaP is not enabled for the App Engine service"
  depends_on = [ module.asset-feed-project ]
}

module "asset-feed-cf-service-account" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account"
  project_id = var.project_id
  name       = "${var.name}-cf"
  depends_on = [ module.asset-feed-project ]
}

module "sandbox-folder-iam" {
  source  = "terraform-google-modules/iam/google//modules/folders_iam"
  folders = ["folders/${var.folder_id}"]

  mode = "additive"

  bindings = {
    "roles/appengine.appAdmin" = [
      "serviceAccount:${module.asset-feed-cf-service-account.email}",
    ],
    "roles/pubsub.publisher" = [
        "serviceAccount:${module.asset-feed-project.service_accounts.robots.cloudasset}", # Esnure this is the quota project, as Terraform using a quota project to use the service account permissions to subscribe the topic to Pub/Sub.
    ]
    "roles/cloudasset.serviceAgent" = [
        "serviceAccount:${module.asset-feed-project.service_accounts.robots.cloudasset}", # Esnure this is the quota project, as Terraform using a quota project to use the service account permissions to subscribe the topic to Pub/Sub.
    ]
  }
  depends_on = [ module.asset-feed-cf-service-account ]
}

module "organization-iam-bindings" {
  source        = "terraform-google-modules/iam/google//modules/organizations_iam"
  organizations = [var.organization_id]
  mode          = "additive"

  bindings = {
    "roles/securitycenter.findingsEditor" = [
      "serviceAccount:${module.asset-feed-cf-service-account.email}",
    ]
  }
  depends_on = [module.sandbox-folder-iam]
}

module "asset-feed-pubsub" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/pubsub"
  project_id = var.project_id
  name       = var.name
  subscriptions = {
    "${var.name}-default" = {}
  }
  iam = {
    "roles/pubsub.publisher" = [
        "serviceAccount:${module.asset-feed-project.service_accounts.robots.cloudasset}",
    ]
    "roles/cloudasset.serviceAgent" = [
        "serviceAccount:${module.asset-feed-project.service_accounts.robots.cloudasset}",
    ]
  }
  depends_on = [ module.sandbox-folder-iam ]
}

# Create a feed that sends notifications about instance  updates.
resource "google_cloud_asset_folder_feed" "app_engine_feed" {
  billing_project     = var.project_id
  folder       = var.folder_id
  feed_id      = var.name
  content_type = "RESOURCE"
  asset_types  = ["appengine.googleapis.com/Application","appengine.googleapis.com/Service"]

  feed_output_config {
    pubsub_destination {
      topic = module.asset-feed-pubsub.topic.id
    }
  }
  depends_on = [ module.asset-feed-pubsub ]
}

resource "random_pet" "random" {
  length = 1
  depends_on = [ google_cloud_asset_folder_feed.app_engine_feed ]
}

module "asset-feed-cf" {
  source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-function-v1"
  project_id  = var.project_id
  region      = var.region
  name        = var.name
  bucket_name = "${var.name}-${random_pet.random.id}"
  bucket_config = {
    location = var.region
  }
  bundle_config = {
    source_dir  = "./cf"
    output_path = var.bundle_path
  }
  service_account = module.asset-feed-cf-service-account.email
  trigger_config = {
    event    = "google.pubsub.topic.publish"
    resource = module.asset-feed-pubsub.topic.id
  }
  depends_on = [ random_pet.random ]
}

