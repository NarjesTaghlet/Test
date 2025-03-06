FROM drupal:10-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libpq-dev libzip-dev zip unzip git \
    default-mysql-client \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install gd pdo pdo_mysql zip

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
COPY init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 80

ENTRYPOINT ["init.sh"]
CMD ["apache2-foreground"]
