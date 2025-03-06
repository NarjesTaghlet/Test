FROM php:8.2-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libpq-dev libzip-dev zip unzip git \
    default-mysql-client \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install gd pdo pdo_mysql zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set working directory
WORKDIR /var/www/html

# Install Drupal via Composer
RUN composer create-project drupal/recommended-project:10.2 . \
    && chown -R www-data:www-data /var/www/html \
    && cp /var/www/html/web/sites/default/default.settings.php /var/www/html/web/sites/default/settings.php \
    && chown www-data:www-data /var/www/html/web/sites/default/settings.php \
    && chmod 664 /var/www/html/web/sites/default/settings.php \
    && mkdir -p /var/www/html/web/sites/default/files \
    && chown www-data:www-data /var/www/html/web/sites/default/files \
    && chmod 775 /var/www/html/web/sites/default/files

# Copy initialization script
COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh \
    && ls -la /usr/local/bin/init.sh  # Vérifie que le fichier est bien là

# Configure Apache
RUN sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/web|' /etc/apache2/sites-available/000-default.conf \
    && a2enmod rewrite \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["apache2-foreground"]

ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["apache2-foreground"]
