#Copyright 2024 Google. This software is provided as-is, without warranty or representation for any use or purpose. 
#Your use of it is subject to your agreement with Google.  

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
  }
}

provider "google" {
  # Configuration options
}

terraform {
  required_providers {
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}

provider "google-beta" {
  # Configuration options
}