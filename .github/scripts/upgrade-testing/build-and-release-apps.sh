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
tag=2.9.2
NEXCLOUD_PATH=/home/nabin/www/stable29
WORKING_DIRECTORY=/home/nabin/www/fork-integrationOpenproject # current working directory simply done by pwd command

if [ ! -d publish ]; then
  mkdir publish
  log_info "Created publish directory."
fi

cd publish

# remove the app directory if it already exists
# Necessary step for next app release
if [ -d integration_openproject ] || [ -f integration_openproject-*.tar.gz ]; then
  rm -rf integration_openproject
  rm -rf integration_openproject-*.tar.gz
  log_info "Removed existing integration_openproject directory and tar.gz files."
fi

git clone https://github.com/nextcloud/integration_openproject.git --depth=1 -b v$tag || { log_error "Failed to clone integration_openproject $tag repository."; exit 1; }
log_success "Cloned integration_openproject $tag repository"

cd integration_openproject || { log_error "Failed to enter integration_openproject directory."; exit 1; }
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
    -subj "/CN=integration_openproject" \
    -addext "basicConstraints=CA:FALSE" \
    -addext "keyUsage=digitalSignature" \
    -addext "extendedKeyUsage=codeSigning" || { log_error "Failed to generate app signing certificate and key."; exit 1; }
    # add new line and add crt in nextcloud
    echo "" >> ${NEXCLOUD_PATH}/resources/codesigning/root.crt
    cat app.crt >> ${NEXCLOUD_PATH}/resources/codesigning/root.crt
    # Sign the app
    sudo chown www-data:$USER app.key
fi

sudo chown www-data:$USER -R integration_openproject

# fix permisions for signing
# need full path for signing
log_info "Signing the app using occ integrity:sign-app command..."
sudo -u www-data ${NEXCLOUD_PATH}/occ integrity:sign-app \
  --privateKey=${WORKING_DIRECTORY}/publish/app.key \
  --certificate=${WORKING_DIRECTORY}/publish/app.crt \
  --path=${WORKING_DIRECTORY}/publish/integration_openproject || { log_error "Failed to sign app."; exit 1; }

# Archive the app
tar -czf integration_openproject-$tag.tar.gz integration_openproject || { log_error "Failed to archive app into tar.gz file."; exit 1; }
log_success "Archived the app into integration_openproject-$tag.tar.gz."

# Sign the archive
sudo openssl dgst -sha512 -sign app.key integration_openproject-$tag.tar.gz | openssl base64 | tee sign.txt || { log_error "Failed to sign archive."; exit 1; }
log_success "Signed the archive and saved the signature in sign.txt."
log_success "App build and release process completed successfully."