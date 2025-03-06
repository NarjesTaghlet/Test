#!/bin/bash

# Environment variables from ACI
DB_HOST=${DRUPAL_DB_HOST}
DB_NAME=${DRUPAL_DB_NAME}
DB_USER=${DRUPAL_DB_USER}
DB_PASS=${DRUPAL_DB_PASSWORD}
ADMIN_USER=${DRUPAL_ADMIN_USERNAME}
ADMIN_PASS=${DRUPAL_ADMIN_PASSWORD}
SITE_NAME=${DRUPAL_SITE_NAME}
DB_PREFIX=${DRUPAL_DB_PREFIX}

# Ensure permissions for the mounted directory
echo "Setting permissions for /var/www/html/sites/default..."
chown -R www-data:www-data /var/www/html/sites/default
chmod -R 775 /var/www/html/sites/default

# Wait for database
until mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" > /dev/null 2>&1; do
  echo "Waiting for database connection..."
  sleep 5
done

# Check if Drupal is installed by querying the database
TABLE_COUNT=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SHOW TABLES;" | wc -l)
if [ "$TABLE_COUNT" -le 1 ]; then
  echo "Installing Drupal..."
  # Copy default settings if not present
  if [ ! -f /var/www/html/sites/default/settings.php ]; then
    cp /var/www/html/sites/default/default.settings.php /var/www/html/sites/default/settings.php
    chown www-data:www-data /var/www/html/sites/default/settings.php
    chmod 664 /var/www/html/sites/default/settings.php
  fi
  /var/www/html/vendor/bin/drush site-install standard \
    --db-url="mysql://$DB_USER:$DB_PASS@$DB_HOST/$DB_NAME" \
    --account-name="$ADMIN_USER" \
    --account-pass="$ADMIN_PASS" \
    --site-name="$SITE_NAME" \
    --db-prefix="$DB_PREFIX" \
    -y
else
  echo "Drupal already installed in database, skipping installation."
fi

# Verify settings.php exists
if [ ! -f /var/www/html/sites/default/settings.php ]; then
  echo "Error: settings.php not created!"
  exit 1
fi

# Start Apache
exec "$@"
