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

  echo "removing redirect_${SITE} container if it exists"
  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "docker rm -f redirect_${SITE} 2> /dev/null 1> /dev/null"
  
  echo "Creating container redirect_${SITE} for ${SITE_HOST}"

  CMD=""
  CMD+="docker run -d --name redirect_${SITE} --restart=always "
  CMD+="--label 'traefik.http.routers.${SITE}.entrypoints=websecure' "
  CMD+="--label 'traefik.http.routers.${SITE}.rule=Host(\`${SITE_HOST}\`)' "
  CMD+="--label 'traefik.http.routers.${SITE}.tls=true' "
  CMD+="--label 'traefik.http.routers.${SITE}.tls.certresolver=le' "

  CMD+="--label 'traefik.http.routers.${SITE}_redirect.entrypoints=web' "
  CMD+="--label 'traefik.http.routers.${SITE}_redirect.rule=Host(\`${SITE_HOST}\`)' "
  CMD+="--label 'traefik.http.routers.${SITE}_redirect.middlewares=${SITE}_redirect' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_redirect.redirectscheme.scheme=https' "
  
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.entrypoints=web' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.rule=(Host(\`www.${SITE_HOST}\`))' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.tls=false' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.tls.certresolver=le' "
  CMD+="--label 'traefik.http.routers.${SITE}_www_redirect.middlewares=${SITE}_www_redirect' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.permanent=true' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.regex=^http://www\\.(.+)' "
  CMD+="--label 'traefik.http.middlewares.${SITE}_www_redirect.redirectregex.replacement=https://\${1}' "

  CMD+="-e REDIRECT_TARGET=crowglassdesign.com "
  CMD+="willia4/docker-web-redirect:0.0.1 "

  ssh root@v4.electriclemur.com -i "$SSH_KEY_PATH" "$CMD"