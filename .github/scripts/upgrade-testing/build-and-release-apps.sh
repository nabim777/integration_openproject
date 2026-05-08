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
# INTEGRATION_OPENPROJECT_PATH => path to the integration_openproject app
# NEXCLOUD_PATH => path to the nextcloud server


if [ -z "$INTEGRATION_OPENPROJECT_PATH" ] || [ -z "$NEXCLOUD_PATH" ]; then
  log_error "INTEGRATION_OPENPROJECT_PATH or NEXCLOUD_PATH environment variable is not set."
  exit 1
fi


# build
make -C ${INTEGRATION_OPENPROJECT_PATH}

# copy required app files
rsync -a \
--exclude=server \
--exclude=dev \
--exclude=.git \
--exclude=appinfo/signature.json \
--exclude='*.swp' \
--exclude=build \
--exclude=.gitignore \
--exclude=.travis.yml \
--exclude=.scrutinizer.yml \
--exclude=CONTRIBUTING.md \
--exclude=composer.phar \
--exclude=js/node_modules \
--exclude=node_modules \
--exclude=src \
--exclude=translationfiles \
--exclude='webpack.*' \
--exclude=stylelint.config.js \
--exclude=.eslintrc.js \
--exclude=.github \
--exclude=.gitlab-ci.yml \
--exclude=crowdin.yml \
--exclude=tools \
--exclude=.tx \
--exclude=.l10nignore \
--exclude=l10n/.tx \
--exclude=l10n/l10n.pl \
--exclude=l10n/templates \
--exclude='l10n/*.sh' \
--exclude='l10n/[a-z][a-z]' \
--exclude='l10n/[a-z][a-z]_[A-Z][A-Z]' \
--exclude=l10n/no-php \
--exclude=makefile \
--exclude=screenshots \
--exclude='phpunit*xml' \
--exclude=tests \
--exclude=ci \
--exclude=vendor/bin \
integration_openproject publish/

cd ${INTEGRATION_OPENPROJECT_PATH}/publish

## https://nextcloudappstore.readthedocs.io/en/latest/developer.html#obtaining-a-certificate

openssl req -x509 -newkey rsa:4096 -sha256 -nodes \
  -keyout app.key \
  -out app.crt \
  -days 3650 \
  -subj "/CN=integration_openproject" \
  -addext "basicConstraints=CA:FALSE" \
  -addext "keyUsage=digitalSignature" \
  -addext "extendedKeyUsage=codeSigning"


# add new line
echo "" >> ${NEXCLOUD_PATH}/resources/codesigning/root.crt
cat app.crt >> ${NEXCLOUD_PATH}/resources/codesigning/root.crt

# Sign the app
sudo chown www-data:$USER app.key
sudo chown www-data:$USER -R integration_openproject

# fix permisions for signing
sudo -u www-data ./occ integrity:sign-app \
  --privateKey=${INTEGRATION_OPENPROJECT_PATH}/publish/app.key \
  --certificate=${INTEGRATION_OPENPROJECT_PATH}/publish/app.crt \
  --path=${INTEGRATION_OPENPROJECT_PATH}/publish/integration_openproject


#4. Archive the app
tar -czf integration_openproject-2.9.2.tar.gz integration_openproject

#5. Sign the archive
openssl dgst -sha512 -sign app.key integration_openproject-2.9.2.tar.gz | openssl base64
