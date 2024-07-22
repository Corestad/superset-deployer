#!/bin/bash

echo "update started";
helm repo update;

helm upgrade --install --values ./superset/helm/superset/values.yaml superset superset/superset;

echo "finished updating Superset";
