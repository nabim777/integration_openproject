# SPDX-FileCopyrightText: 2023-2024 Jankari Tech Pvt. Ltd.
# SPDX-FileCopyrightText: 2023 Bundesministerium des Innern und für Heimat, PG ZenDiS "Projektgruppe für Aufbau ZenDiS"
# SPDX-FileCopyrightText: 2023 Nextcloud GmbH
# SPDX-License-Identifier: AGPL-3.0-only
#!/usr/bin/env bash

# This bash script is to register and publish the apps in self-hosted appstore.
# To run this script the self-hosted appstore instances must be up and running

set -e

# helper functions
log_error() {
  echo -e "\e[31m$1\e[0m"
}

log_info() {
  echo -e "\e[37m$1\e[0m"
}

log_success() {
  echo -e "\e[32m$1\e[0m"
}

# env required
# TAG=2.9.2
# NEXCLOUD_PATH=/home/nabin/www/stable29
# WORKING_DIRECTORY=/home/nabin/www/fork-integrationOpenproject # current working directory simply done by pwd command
# APP_ID=integration_openproject

if [ ! -d publish ]; then
  mkdir publish
  log_info "Created publish directory."
fi

cd publish

# remove the app directory if it already exists
# Necessary step for next app release
if [ -d "$APP_ID" ] || [ -f "$APP_ID-*.tar.gz" ]; then
  rm -rf "$APP_ID"
  rm -rf "$APP_ID-*.tar.gz"
  log_info "Removed existing $APP_ID directory and tar.gz files."
fi

git clone https://github.com/nextcloud/$APP_ID.git --depth=1 -b v$TAG || { log_error "Failed to clone $APP_ID $TAG repository."; exit 1; }
log_success "Cloned $APP_ID $TAG repository"

cd $APP_ID || { log_error "Failed to enter $APP_ID directory."; exit 1; }
make || { log_error "Failed to build the app. Check make configuration."; exit 1; }
log_success "Built the app."

# copy required app files
rm -rf server \
  dev \
  git \
  appinfo/signature.json \
  '*.swp' \
  build \
  .gitignore \
  .travis.yml \
  .scrutinizer.yml \
  CONTRIBUTING.md \
  composer.phar \
  js/node_modules \
  node_modules \
  src \
  translationfiles \
  'webpack.*' \
  stylelint.config.js \
  .eslintrc.js \
  .github \
  .gitlab-ci.yml \
  crowdin.yml \
  tools \
  .tx \
  .l10nignore \
  l10n/.tx \
  l10n/l10n.pl \
  l10n/templates \
  'l10n/*.sh' \
  'l10n/[a-z][a-z]' \
  'l10n/[a-z][a-z]_[A-Z][A-Z]' \
  l10n/no-php \
  makefile \
  screenshots \
  'phpunit*xml' \
  tests \
  ci \
  vendor/bin
log_info "Removed unnecessary files and directories."
cd ..

# https://nextcloudappstore.readthedocs.io/en/latest/developer.html#obtaining-a-certificate
if [ -f "app.key" ] || [ -f "app.crt" ]; then
  log_info "app.key or app.crt already exists."
else
  log_info "Generating app.key and app.crt..."
  sudo openssl req -x509 -newkey rsa:4096 -sha256 -nodes \
    -keyout app.key \
    -out app.crt \
    -days 3650 \
    -subj "/CN=$APP_ID" \
    -addext "basicConstraints=CA:FALSE" \
    -addext "keyUsage=digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" || { log_error "Failed to generate app signing certificate and key."; exit 1; }
    # add new line and add crt in nextcloud
    echo "" >> ${NEXCLOUD_PATH}/resources/codesigning/root.crt
    cat app.crt >> ${NEXCLOUD_PATH}/resources/codesigning/root.crt
    # Sign the app
    sudo chown www-data:$USER app.key
fi

sudo chown www-data:$USER -R $APP_ID

# fix permisions for signing
# need full path for signing
log_info "Signing the app using occ integrity:sign-app command..."
php ${NEXCLOUD_PATH}/occ integrity:sign-app \
  --privateKey=${WORKING_DIRECTORY}/publish/app.key \
  --certificate=${WORKING_DIRECTORY}/publish/app.crt \
  --path=${WORKING_DIRECTORY}/publish/$APP_ID || { log_error "Failed to sign app."; exit 1; }


# php /home/runner/html/nextcloud/occ integrity:sign-app \
#   --privateKey=/home/runner/work/integration_openproject/integration_openproject/publish/app.key \
#   --certificate=/home/runner/work/integration_openproject/integration_openproject/publish/app.crt \
#   --path=/home/runner/work/integration_openproject/integration_openproject/publish/integration_openprojectpublish 


# Archive the app
tar -czf $APP_ID-$TAG.tar.gz $APP_ID || { log_error "Failed to archive app into tar.gz file."; exit 1; }
log_success "Archived the app into $APP_ID-$TAG.tar.gz."

# Sign the archive
sudo openssl dgst -sha512 -sign app.key $APP_ID-$TAG.tar.gz | openssl base64 | tee sign.txt

# check sign.txt is empty
if [ ! -s sign.txt ]; then
  log_error "Failed to sign the archive. Signature file is empty."
  exit 1
fi

log_success "Signed the archive and saved the signature in sign.txt."
log_success "App build and release process completed successfully."