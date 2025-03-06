FROM drupal:10-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Drush
RUN composer require drush/drush

# Set working directory
WORKDIR /var/www/html

# Pre-create settings.php and files directory
RUN cp /var/www/html/sites/default/default.settings.php /var/www/html/sites/default/settings.php \
    && chown www-data:www-data /var/www/html/sites/default/settings.php \
    && chmod 664 /var/www/html/sites/default/settings.php \
    && mkdir -p /var/www/html/sites/default/files \
    && chown www-data:www-data /var/www/html/sites/default/files \
    && chmod 775 /var/www/html/sites/default/files

# Copy initialization script
COPY init-drupal.sh /init-drupal.sh
RUN chmod +x /init-drupal.sh

EXPOSE 80

ENTRYPOINT ["/init-drupal.sh"]
CMD ["apache2-foreground"]
