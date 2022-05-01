#!/usr/bin/env bash
set -e

SSH_KEY_PATH="$1"

if [[ -z "$SSH_KEY_PATH" ]]; then
  >&2 echo "SSH Key Path is required"
  exit 1
fi

SSH_KEY_PATH=$(realpath -s "$SSH_KEY_PATH")
if [[ ! -f "$SSH_KEY_PATH" ]]; then
  >&2 echo "${SSH_KEY_PATH} does not seem to exist"
  exit 2
fi

echo "Connecting with key at $SSH_KEY_PATH: $(cat $SSH_KEY_PATH | sha256sum)"

for SITE in $(cat sites.json | jq -r '.sites | keys | .[]')
do
  VOLUME_DIR="/volumes/simple_sites/${SITE}"
  echo "Creating data directory for $SITE: ${VOLUME_DIR}"
  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "mkdir -p ${VOLUME_DIR}"
  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "chmod -R a+rwx ${VOLUME_DIR}"

  SITE_HOST=$(cat sites.json | jq -r ".sites[\"${SITE}\"].hostname")

  CONTAINER_ID=$(ssh "root@v4.electriclemur.com" -i "$SSH_KEY_PATH" "docker ps --filter 'name=site_${SITE}' -q")
  if [[ -n "$CONTAINER_ID" ]]; then
    echo "site_${SITE} container already exists; removing it"
    ssh "root@v4.electriclemur.com" -i "$SSH_KEY_PATH" "docker rm --force site_${SITE}" > /dev/null
  fi

  echo "Creating container for ${SITE_HOST}"

  CMD=""
  CMD+="docker run -d --name site_${SITE} "
  CMD+="--label 'traefik.http.routers.${SITE}.entrypoints=websecure' "
  CMD+="--label 'traefik.http.routers.${SITE}.rule=Host(\`${SITE_HOST}\`)' "
  #CMD+="--label 'traefik.http.routers.${SITE}.tls=true' "
  #CMD+="--label 'traefik.http.routers.${SITE}.tls.certresolver=le' "

  CMD+="--label 'traefik.http.routers.${SITE}_redirect.entrypoints=web' "
  CMD+="--label 'traefik.http.routers.${SITE}_redirect.rule=Host(\`${SITE_HOST}\`)' "
  #CMD+="--label 'traefik.http.routers.${SITE}_redirect.middlewares=${SITE}_redirect' "
  #CMD+="--label 'traefik.http.middlewares.${SITE}_redirect.redirectscheme.scheme=https' "
  
  CMD+="-v ${VOLUME_DIR}:/var/www "
  CMD+="willia4/nginx_static_php:3.0.1 "

  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "$CMD"
done