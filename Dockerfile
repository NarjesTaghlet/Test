FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libpq-dev libzip-dev zip unzip git \
    default-mysql-client \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install gd pdo pdo_mysql zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html
RUN composer create-project drupal/recommended-project:10.2 . \
    && composer require drush/drush \
    && chown -R www-data:www-data /var/www/html \
    && mkdir -p /var/www/html/web/sites/default/files \
    && chown www-data:www-data /var/www/html/web/sites/default/files \
    && chmod 775 /var/www/html/web/sites/default/files \
    && cp /var/www/html/web/sites/default/default.settings.php /var/www/default.settings.php.template

COPY init.sh /usr/local/bin/init.sh

#COPY DigiCertGlobalRootCA.crt.pem /etc/ssl/certs/
#RUN ls -l /etc/ssl/certs/DigiCertGlobalRootCA.crt.pem || { echo "Certificate not found!"; exit 1; }
RUN chmod +x /usr/local/bin/init.sh

RUN sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/web|' /etc/apache2/sites-available/000-default.conf \
    && a2enmod rewrite \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/init.sh"]
CMD ["apache2-foreground"]
