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

  echo "Connecting with key at $SSH_KEY_PATH"

  SITE="crowglass_com"
  SITE_HOST="crowglass.com"

  CONTAINER_ID=$(ssh "root@v4.electriclemur.com" -i "$SSH_KEY_PATH" "docker ps --filter 'name=redirect_${SITE}' -q")
  if [[ -n "$CONTAINER_ID" ]]; then
    echo "redirect_${SITE} container already exists; removing it"
    ssh "root@v4.electriclemur.com" -i "$SSH_KEY_PATH" "docker rm --force redirect_${SITE}" > /dev/null
  fi

  CMD=""
  CMD+="docker run -d --name redirect_${SITE} "
  CMD+="--label 'traefik.http.routers.${SITE}.entrypoints=websecure' "
  CMD+="--label 'traefik.http.routers.${SITE}.rule=Host(\`${SITE_HOST}\`)' "
  CMD+="--label 'traefik.http.routers.${SITE}.tls=true' "
  CMD+="--label 'traefik.http.routers.${SITE}.tls.certresolver=le' "

  CMD+="--label 'traefik.http.routers.${SITE}_redirect.entrypoints=web' "
  CMD+="--label 'traefik.http.routers.${SITE}_redirect.rule=Host(\`${SITE_HOST}\`)' "
  CMD+="--label 'traefik.http.routers.${SITE}_redirect.middlewares=${SITE}_redirect' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_redirect.redirectscheme.scheme=https' "
  
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.entrypoints=websecure' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.rule=(Host(\`www.${SITE_HOST}\`))' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.tls=true' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.tls.certresolver=le' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.middlewares=${SITE}_www_redirect' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.permanent=true' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.regex=^https?://www\\.(.+)' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.replacement=https://\${1}' "

  CMD+="-e REDIRECT_TARGET=crowglassdesign.com "
  CMD+="willia4/docker-web-redirect:0.0.1 "

  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "$CMD"