#!/bin/bash

echo "Starting init-drupal.sh..."

# Environment variables
DB_HOST=${DRUPAL_DB_HOST}
DB_NAME=${DRUPAL_DB_NAME}
DB_USER=${DRUPAL_DB_USER}
DB_PASS=${DRUPAL_DB_PASSWORD}
ADMIN_USER=${DRUPAL_ADMIN_USERNAME}
ADMIN_PASS=${DRUPAL_ADMIN_PASSWORD}
SITE_NAME=${DRUPAL_SITE_NAME}
DB_PREFIX=${DRUPAL_DB_PREFIX}

echo "DB_HOST=$DB_HOST, DB_NAME=$DB_NAME, DB_USER=$DB_USER, DB_PREFIX=$DB_PREFIX"

# Ensure permissions
echo "Setting permissions for /var/www/html/sites/default..."
chown -R www-data:www-data /var/www/html/sites/default
chmod -R 775 /var/www/html/sites/default

# Check volume mount
echo "Checking volume mount before installation..."
ls -la /var/www/html/sites/default || echo "Volume mount check failed!"

# Wait for database
echo "Checking database connection..."
until mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" > /dev/null 2>&1; do
  echo "Waiting for database connection..."
  sleep 5
done
echo "Database connected!"

# Check if Drupal is installed
TABLE_COUNT=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SHOW TABLES;" | wc -l)
echo "Table count: $TABLE_COUNT"
if [ "$TABLE_COUNT" -le 1 ]; then
  echo "Installing Drupal..."
  /var/www/html/vendor/bin/drush site-install standard \
    --db-url="mysql://$DB_USER:$DB_PASS@$DB_HOST/$DB_NAME" \
    --account-name="$ADMIN_USER" \
    --account-pass="$ADMIN_PASS" \
    --site-name="$SITE_NAME" \
    --db-prefix="$DB_PREFIX" \
    -y || { echo "Drush site-install failed!"; exit 1; }
  echo "Drupal installation completed."
else
  echo "Drupal already installed, skipping installation."
fi

# Verify settings.php
echo "Verifying settings.php..."
if [ -f /var/www/html/sites/default/settings.php ]; then
  echo "settings.php exists. Contents:"
  cat /var/www/html/sites/default/settings.php
else
  echo "Error: settings.php not found!"
  exit 1
fi

# Start Apache
echo "Starting Apache..."
exec "$@"
