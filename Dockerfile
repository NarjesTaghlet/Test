FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libpq-dev libzip-dev zip unzip git \
    default-mysql-client \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install gd pdo pdo_mysql zip

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html
RUN composer create-project drupal/recommended-project:10.x . \
    && chown -R www-data:www-data /var/www/html

COPY init-drupal.sh /usr/local/bin/init-drupal.sh

#COPY DigiCertGlobalRootCA.crt.pem /etc/ssl/certs/
#RUN ls -l /etc/ssl/certs/DigiCertGlobalRootCA.crt.pem || { echo "Certificate not found!"; exit 1; }
RUN chmod +x /usr/local/bin/init-drupal.sh

RUN sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/web|' /etc/apache2/sites-available/000-default.conf \
    && a2enmod rewrite \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

CMD ["/usr/local/bin/init-drupal.sh"]
