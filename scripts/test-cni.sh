#!/bin/sh

CNI_SPEC_TEMPLATE=$(cat << 'EOF'
{
      "name": "k8s-pod-network",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "ptp",
          "mtu": 1460,
          "ipam": {
              "type": "host-local",
              "ranges": [
              @ipv4Subnet@ipv6SubnetOptional
              ],
              "routes": [
                {"dst": "0.0.0.0/0"}@ipv6RouteOptional
              ]
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          },
          "noSnat": true
        }
      ]
    }
EOF
                 )

CNI_CALICO_SPEC_TEMPLATE=$(cat << 'EOF'
{
  "name": "k8s-pod-network",
  "cniVersion": "0.3.0",
  "plugins": [
    {
    "type": "calico",
    "log_level": "debug",
    "datastore_type": "kubernetes",
    "nodename": "__KUBERNETES_NODE_NAME__",
    "ipam": {
      "type": "host-local",
      "ranges": [
      [ { "subnet": "usePodCidr" } ]@ipv6SubnetOptional
      ],
      "routes": [
        {"dst": "0.0.0.0/0"}@ipv6RouteOptional
      ]
    },
    "policy": {
      "type": "k8s",
      "k8s_auth_token": "__SERVICEACCOUNT_TOKEN__"
    },
    "kubernetes": {
      "k8s_api_root": "https://__KUBERNETES_SERVICE_HOST__:__KUBERNETES_SERVICE_PORT__",
      "kubeconfig": "__KUBECONFIG_FILEPATH__"
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      },
      "snat": true
    }
  ]
}
EOF
                           )



cni_spec=${CNI_CALICO_SPEC_TEMPLATE:-}
echo "Template is $cni_spec"
ipv4_subnet='"192.168.1.0/24"'
node_ipv6_addr="2600:aa:bb:cc::"

ENABLE_PRIVATE_IPV6_ACCESS=true
ENABLE_CALICO_NETWORK_POLICY=true
if [ "${ENABLE_CALICO_NETWORK_POLICY}" == "true" ]; then
  echo "Calico Network Policy is enabled by ENABLE_CALICO_NETWORK_POLICY. Generating Calico spec."
  cni_spec=${CNI_CALICO_SPEC_TEMPLATE}
else
  cni_spec=${CNI_SPEC_TEMPLATE}
fi

node_url="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/api/v1/nodes/${HOSTNAME}"
if [ -z "${ipv4_subnet:-}" ]; then
  echo "Failed to fetch PodCIDR from K8s API server. Exiting with an error (1) ..."
  exit 1
fi

echo "Adding IPV4 subnet range ${ipv4_subnet:-}."
cni_spec=$(echo ${cni_spec:-} | sed -e "s#@ipv4Subnet#[{\"subnet\": ${ipv4_subnet:-}}]#g")

if [ "$ENABLE_PRIVATE_IPV6_ACCESS" == "true" ]; then

  if [ -n "${node_ipv6_addr:-}" ] && [ "${node_ipv6_addr}" != "null" ]; then
    echo "Found IPV6 address assignment ${node_ipv6_addr:-}."
    cni_spec=$(echo ${cni_spec:-} | sed -e \
      "s#@ipv6SubnetOptional#, [{\"subnet\": \"${node_ipv6_addr:-}/112\"}]#g;
       s#@ipv6RouteOptional#, {\"dst\": \"::/0\"}#g")
  else
    echo "Found empty IPV6 address assignment. Skipping IPV6 subnet and range configuration."
    cni_spec=$(echo ${cni_spec:-} | \
      sed -e "s#@ipv6SubnetOptional##g; s#@ipv6RouteOptional##g")
  fi
else
  echo "Disabling IPV6 subnet and range configuration. Set ENABLE_PRIVATE_IPV6_ACCESS=true to configure IPV6."
  cni_spec=$(echo ${cni_spec:-} | \
    sed -e "s#@ipv6SubnetOptional##g; s#@ipv6RouteOptional##g")
fi

echo ${cni_spec:-}

