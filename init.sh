#!/bin/bash
set -e
exec 1>/dev/stdout
exec 2>/dev/stderr

echo "Starting at $(date)"
echo "DB_HOST=$DRUPAL_DB_HOST DB_NAME=$DRUPAL_DB_NAME DB_USER=$DRUPAL_DB_USER"

# Vérifier le volume
echo "Checking volume..."
ls -la /var/www/html/web/sites/default || { echo "Volume mount failed!"; exit 1; }
echo "Volume contents:"
ls -la /var/www/html/web/sites/default
[ -f "/var/www/html/web/sites/default/settings.php" ] && cat /var/www/html/web/sites/default/settings.php || echo "No settings.php yet (virgin site)"

# Attendre la DB
echo "Waiting for DB..."
until mysql -h "$DRUPAL_DB_HOST" -u "$DRUPAL_DB_USER" -p"$DRUPAL_DB_PASSWORD" "$DRUPAL_DB_NAME" -e "SHOW DATABASES;" 2>/dev/stdout; do
  echo "Waiting 5s..."
  sleep 5
done
echo "DB connected"

# Pas d’installation : site vierge
echo "Drupal ready (configure manually if no settings.php)"

# Permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/html/web/sites/default
chmod -R 775 /var/www/html/web/sites/default

echo "Starting Apache..."
exec apache2-foreground
