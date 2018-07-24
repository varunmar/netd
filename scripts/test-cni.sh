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

echo "Template is $CNI_SPEC_TEMPLATE"
echo "Adding IPV4 subnet range ${ipv4_subnet:-}."
cni_spec=$(echo ${CNI_SPEC_TEMPLATE:-} | sed -e "s#@ipv4Subnet#[{\"subnet\": ${ipv4_subnet:-}}]#g")
echo $cni_spec

ENABLE_PRIVATE_IPV6_ACCESS=true
if [ "$ENABLE_PRIVATE_IPV6_ACCESS" = true ]; then
  node_ipv6_addr="fe80::"

  if [ -n "${node_ipv6_addr:-}" ]; then
    echo "Found IPV6 address assignment ${node_ipv6_addr:-}."
    cni_spec=$(echo ${cni_spec:-} | sed -e \
               "s#@ipv6SubnetOptional#, [{\"subnet\": \"${node_ipv6_addr:-}/112\"}]#g; 
                 s#@ipv6RouteOptional#, {\"dst\": \"::/0\"}]#g")
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

echo $cni_spec
