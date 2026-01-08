#!/usr/bin/env bash
set -euo pipefail

DNS1="1.1.1.1"
DNS2="8.8.8.8"

# name:subnet:gateway
NETWORKS=(
  "infra_net:10.89.0.0/24:10.89.0.1"
  "arr_net:10.90.0.0/24:10.90.0.1"
)

echo "⚠️  Resetting Podman networks (destructive)"
echo "-----------------------------------------"

echo "🛑 Removing all containers (required to detach networks)"
podman ps -aq | xargs -r podman rm -f

echo "🧹 Removing target networks if they exist"
for entry in "${NETWORKS[@]}"; do
  IFS=":" read -r NAME SUBNET GATEWAY <<< "$entry"
  if podman network exists "$NAME"; then
    echo "❌ podman network rm $NAME"
    podman network rm "$NAME" || true
  fi
done

echo "🧹 Removing lingering podman bridge interfaces (if any)"
# These interfaces commonly persist as podman0, podman1, podman2, ...
# Safe to delete if no podman networks/containers are using them.
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^podman[0-9]*$' || true); do
  echo "❌ ip link delete $iface"
  sudo ip link delete "$iface" 2>/dev/null || true
done

echo "🧪 Checking for conflicting routes using 10.89/10.90/10.91"
ip route | grep -E '10\.(89|90|91)\.' || true

echo "➕ Recreating networks"
for entry in "${NETWORKS[@]}"; do
  IFS=":" read -r NAME SUBNET GATEWAY <<< "$entry"
  echo "  -> $NAME ($SUBNET gw $GATEWAY)"
  podman network create \
    --subnet "$SUBNET" \
    --gateway "$GATEWAY" \
    --dns "$DNS1" \
    --dns "$DNS2" \
    "$NAME"
done

echo "✅ Done. Current podman networks:"
podman network ls
