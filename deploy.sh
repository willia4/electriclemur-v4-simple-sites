#!/usr/bin/env bash
set -e

SSH_KEY_PATH="$1"
SPECIFIC_SITE="$2"

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

SITES=$(cat sites.json | jq -r '.sites | keys | .[]')
if [[ -n "$SPECIFIC_SITE" ]]; then
  SITES=$(echo "$SITES" | grep "$SPECIFIC_SITE")
fi

for SITE in $SITES
do
  VOLUME_DIR="/volumes/simple_sites/${SITE}"
  echo "Creating data directory for $SITE: ${VOLUME_DIR}"
  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "mkdir -p ${VOLUME_DIR}"
  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "chmod -R a+rwx ${VOLUME_DIR}"

  SITE_HOST=$(cat sites.json | jq -r ".sites[\"${SITE}\"].hostname")

  CONTAINER_ID=$(ssh "root@v4.electriclemur.com" -i "$SSH_KEY_PATH" "docker ps -a --filter 'name=site_${SITE}' -q")
  if [[ -n "$CONTAINER_ID" ]]; then
    echo "site_${SITE} container already exists; removing it"
    ssh "root@v4.electriclemur.com" -i "$SSH_KEY_PATH" "docker rm --force site_${SITE}" > /dev/null
  fi

  echo "Creating container for ${SITE_HOST}"

  CMD=""
  CMD+="docker run -d --name site_${SITE} --restart=always "
  CMD+="--label 'traefik.http.routers.${SITE}.entrypoints=websecure' "
  CMD+="--label 'traefik.http.routers.${SITE}.rule=Host(\`${SITE_HOST}\`)' "
  CMD+="--label 'traefik.http.routers.${SITE}.tls=true' "
  CMD+="--label 'traefik.http.routers.${SITE}.tls.certresolver=le' "

  CMD+="--label 'traefik.http.routers.${SITE}_http_redirect.entrypoints=web' "
  CMD+="--label 'traefik.http.routers.${SITE}_http_redirect.rule=(Host(\`${SITE_HOST}\`) || Host(\`www.${SITE_HOST}\`))' "
  CMD+="--label 'traefik.http.routers.${SITE}_http_redirect.middlewares=${SITE}_http_redirect' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_http_redirect.redirectscheme.scheme=https' "

  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.entrypoints=websecure' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.rule=(Host(\`www.${SITE_HOST}\`))' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.tls=true' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.tls.certresolver=le' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.middlewares=${SITE}_www_redirect' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.permanent=true' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.regex=^https?://www\\.(.+)' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.replacement=https://\${1}' "

  CMD+="-v ${VOLUME_DIR}:/var/www "
  CMD+="willia4/nginx_static_php:3.0.1 "

  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "$CMD"
done