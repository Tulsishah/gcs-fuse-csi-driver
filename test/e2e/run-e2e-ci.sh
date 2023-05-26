#!/bin/bash

set -o xtrace
set -o nounset
set -o errexit

readonly PKGDIR=${GOPATH}/src/GoogleCloudPlatform/gcs-fuse-csi-driver
readonly overlay_name="${GCS_FUSE_OVERLAY_NAME:-stable}"
readonly boskos_resource_type="${GCE_PD_BOSKOS_RESOURCE_TYPE:-gke-internal-project}"
readonly gke_cluster_version=${GKE_CLUSTER_VERSION:-latest} 
readonly gke_node_version=${GKE_NODE_VERSION:-}
readonly use_gke_autopilot=${USE_GKE_AUTOPILOT:-false}
readonly gce_region=${GCE_CLUSTER_REGION:-us-central1}
readonly use_gke_managed_driver=${USE_GKE_MANAGED_DRIVER:-false}

# Make e2e-test will initialize ginkgo. We can't use e2e-test to build / install the driver / overlays because the registry depends on the boskos project. 
make -C "${PKGDIR}" init-ginkgo 

make -C "${PKGDIR}" e2e-test-ci

# Note that for all tests:
# - a regional cluster will be created (GCS does not support zonal buckets)
# - run-in-prow true
# - image-type is cos_containerd
# - number-nodes is 3  
base_cmd="${PKGDIR}/bin/e2e-test-ci \
            --run-in-prow=true \
            --image-type=cos_containerd --number-nodes=3 \
            --region=${gce_region} \
            --use-gke-autopilot=${use_gke_autopilot} \
            --gke-cluster-version=${gke_cluster_version} \
            --boskos-resource-type=${boskos_resource_type}"

# do-driver-build must be false when using GKE managed driver. Otherwise, do-driver-build must be true and deploy-overlay-name should be set.
if [ "$use_gke_managed_driver" = true ]; then
  base_cmd="${base_cmd} --do-driver-build=false --use-gke-managed-driver=true" 
else
  base_cmd="${base_cmd} --do-driver-build=true --deploy-overlay-name=${overlay_name}"
fi

eval "$base_cmd"