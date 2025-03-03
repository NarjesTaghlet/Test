#!/bin/bash

echo "Starting container setup..."
sleep 10

if [ -z "$DRUPAL_DB_HOST" ] || [ -z "$DRUPAL_DB_NAME" ] || [ -z "$DRUPAL_DB_USER" ] || [ -z "$DRUPAL_DB_PASSWORD" ]; then
  echo "Error: Missing required environment variables"
  echo "DRUPAL_DB_HOST: $DRUPAL_DB_HOST"
  echo "DRUPAL_DB_NAME: $DRUPAL_DB_NAME"
  echo "DRUPAL_DB_USER: $DRUPAL_DB_USER"
  echo "DRUPAL_DB_PASSWORD: $DRUPAL_DB_PASSWORD"
  exit 1
fi

echo "DB_HOST: $DRUPAL_DB_HOST"
echo "DB_NAME: $DRUPAL_DB_NAME"
echo "DB_USER: $DRUPAL_DB_USER"
echo "DB_PASSWORD: $DRUPAL_DB_PASSWORD"

MAX_ATTEMPTS=120
ATTEMPT=1
until mysql -h "$DRUPAL_DB_HOST" -u "$DRUPAL_DB_USER" -p"$DRUPAL_DB_PASSWORD" -P 3306 "$DRUPAL_DB_NAME" -e "SELECT 1" 2>/tmp/mysql_error.log; do
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for database connection..."
  cat /tmp/mysql_error.log
  sleep 2
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    echo "Error: Database connection failed after $MAX_ATTEMPTS attempts."
    cat /tmp/mysql_error.log
    exit 1
  fi
done

echo "Database connection successful!"

# Installer Drush si nécessaire
if ! command -v drush &> /dev/null; then
  echo "Installing Drush..."
  composer require drush/drush -W --working-dir=/var/www/html || { echo "Failed to install Drush"; exit 1; }
fi

# Vérifier si le site est déjà installé en regardant si settings.php existe et est configuré
if [ ! -f "/var/www/html/web/sites/default/settings.php" ] || ! grep -q "databases" /var/www/html/web/sites/default/settings.php; then
  echo "Installing Drupal site..."
  rm -f /var/www/html/web/sites/default/settings.php
  cp /var/www/html/web/sites/default/default.settings.php /var/www/html/web/sites/default/settings.php || { echo "Failed to copy settings.php"; exit 1; }
  chmod 664 /var/www/html/web/sites/default/settings.php || { echo "Failed to chmod settings.php"; exit 1; }

  # Configurer la base de données dans settings.php
  cat <<EOL >> /var/www/html/web/sites/default/settings.php
\$databases['default']['default'] = [
  'driver' => 'mysql',
  'host' => '$DRUPAL_DB_HOST',
  'database' => '$DRUPAL_DB_NAME',
  'username' => '$DRUPAL_DB_USER',
  'password' => '$DRUPAL_DB_PASSWORD',
  'prefix' => '$DRUPAL_DB_PREFIX',
  'port' => 3306,
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'autoload' => 'core/modules/mysql/src/Driver/Database/mysql/',
];
EOL

  chmod 444 /var/www/html/web/sites/default/settings.php || { echo "Failed to chmod settings.php"; exit 1; }

  # Installer Drupal avec Drush
  cd /var/www/html
  vendor/bin/drush site-install standard \
    --db-url=mysql://$DRUPAL_DB_USER:$DRUPAL_DB_PASSWORD@$DRUPAL_DB_HOST:3306/$DRUPAL_DB_NAME \
    --site-name="$DRUPAL_SITE_NAME" \
    --account-name=$DRUPAL_ADMIN_USERNAME \
    --account-pass=$DRUPAL_ADMIN_PASSWORD \
    -y || { echo "Failed to install Drupal with Drush"; exit 1; }
  echo "Drupal site installed successfully"
else
  echo "Drupal site already installed, skipping installation"
fi

# Créer le répertoire files s'il n'existe pas
if [ ! -d "/var/www/html/web/sites/default/files" ]; then
  mkdir -p /var/www/html/web/sites/default/files || { echo "Failed to create files directory"; exit 1; }
  echo "Created files directory"
fi

chown -R www-data:www-data /var/www/html/web/sites/default/files || { echo "Failed to chown files directory"; exit 1; }
chmod -R 775 /var/www/html/web/sites/default/files || { echo "Failed to chmod files directory"; exit 1; }

echo "Starting Apache..."
apache2-foreground || { echo "Apache failed to start"; exit 1; }
