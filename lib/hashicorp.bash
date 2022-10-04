#!/usr/bin/env bash

do_hashicorp () {
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo update
}
