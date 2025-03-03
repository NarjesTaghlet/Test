#!/bin/bash

echo "Initial delay to allow MySQL startup..."
sleep 60

if [ -z "$DRUPAL_DB_HOST" ] || [ -z "$DRUPAL_DB_NAME" ] || [ -z "$DRUPAL_DB_USER" ] || [ -z "$DRUPAL_DB_PASSWORD" ]; then
  echo "Error: Missing required environment variables"
  exit 1
fi

echo "DB_HOST: $DRUPAL_DB_HOST"
echo "DB_NAME: $DRUPAL_DB_NAME"
echo "DB_USER: $DRUPAL_DB_USER"
echo "DB_PASSWORD: $DRUPAL_DB_PASSWORD"

# Créer ~/.my.cnf pour forcer SSL
#mkdir -p /root
#cat <<EOL > /root/.my.cnf
#[client]
#host=$DRUPAL_DB_HOST
#ssl-ca=/etc/ssl/certs/DigiCertGlobalRootCA.crt.pem
#EOL

#chmod 600 /root/.my.cnf

MAX_ATTEMPTS=60
ATTEMPT=1
until mysql -u"$DRUPAL_DB_USER" -p"$DRUPAL_DB_PASSWORD" "$DRUPAL_DB_NAME" --port=3306 -e "SELECT 1" 2>/tmp/mysql_error.log; do
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for database connection..."
  cat /tmp/mysql_error.log
  sleep 2
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    echo "Error: Database connection failed after $MAX_ATTEMPTS attempts."
    exit 1
  fi
done

echo "Database connection successful!"

if [ ! -f /var/www/html/web/sites/default/settings.php ]; then
  echo "Installing Drupal..."
  cp /var/www/html/web/sites/default/default.settings.php /var/www/html/web/sites/default/settings.php || { echo "Failed to copy settings.php"; exit 1; }
  chmod 664 /var/www/html/web/sites/default/settings.php || { echo "Failed to chmod settings.php"; exit 1; }

  # Configurer settings.php avec SSL (pour runtime)
  cat <<EOL >> /var/www/html/web/sites/default/settings.php
\$databases['default']['default'] = [
  'driver' => 'mysql',
  'host' => '$DRUPAL_DB_HOST',
  'database' => '$DRUPAL_DB_NAME',
  'username' => '$DRUPAL_DB_USER',
  'password' => '$DRUPAL_DB_PASSWORD',
  'prefix' => '',
  'port' => 3306,
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
];
EOL

  cd /var/www/html
  composer require drush/drush --prefer-dist || { echo "Failed to install Drush"; exit 1; }
  # Installer Drupal avec ~/.my.cnf
  vendor/bin/drush site:install standard \
    --account-name="${DRUPAL_ADMIN_USERNAME:-admin}" \
    --account-pass="${DRUPAL_ADMIN_PASSWORD:-admin}" \
    --site-name="${DRUPAL_SITE_NAME:-Drupal 10 Site}" \
    --no-interaction \
    -y || { echo "Drush install failed"; exit 1; }

  # Ajouter les paramètres SSL à settings.php après installation pour runtime
  #echo "\$databases['default']['default']['pdo'] = [
   # PDO::MYSQL_ATTR_SSL_CA => '/etc/ssl/certs/DigiCertGlobalRootCA.crt.pem',
    #PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false,
  #];" >> /var/www/html/web/sites/default/settings.php

  chmod 444 /var/www/html/web/sites/default/settings.php || { echo "Failed to chmod settings.php post-install"; exit 1; }
  chown -R www-data:www-data /var/www/html/web/sites/default/files || { echo "Failed to chown files directory"; exit 1; }
  chmod -R 775 /var/www/html/web/sites/default/files || { echo "Failed to chmod files directory"; exit 1; }
  echo "Drupal installation completed!"
else
  echo "Drupal already installed."
fi

echo "Starting Apache..."
exec apache2-foreground
