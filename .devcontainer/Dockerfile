FROM wordpress:php8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    zip \
    unzip \
    rsync \
    openssh-client \
    mysql-client \
    less \
    nano \
    vim \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.8.1/utils/wp-cli-installer.sh \
    && chmod +x wp-cli-installer.sh \
    && ./wp-cli-installer.sh \
    && mv wp-cli.phar /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp \
    && rm wp-cli-installer.sh

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Create wp-content directories
RUN mkdir -p /var/www/html/wp-content/themes \
    && mkdir -p /var/www/html/wp-content/plugins \
    && mkdir -p /var/www/html/wp-content/uploads

# Set up permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Add www-data user to sudoers for development
RUN echo "www-data ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Configure Apache for multisite
RUN a2enmod rewrite \
    && a2enmod ssl \
    && a2enmod headers

# Copy custom Apache configuration
COPY apache-config.conf /etc/apache2/sites-available/000-default.conf

# Set working directory
WORKDIR /var/www/html

# Switch to www-data user
USER www-data