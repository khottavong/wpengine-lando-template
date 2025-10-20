#!/bin/bash
set -e

echo "🚀 Setting up WP Engine development environment..."

# Set proper ownership and permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Make connect.sh executable
chmod +x /var/www/html/connect.sh

# Create wp-config.php if it doesn't exist
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "📝 Creating wp-config.php..."
    wp config create \
        --dbname=wordpress \
        --dbuser=wordpress \
        --dbpass=wordpress \
        --dbhost=mysql:3306 \
        --allow-root
fi

# Download WordPress core if not present
if [ ! -f "/var/www/html/wp-settings.php" ]; then
    echo "📦 Downloading WordPress core..."
    wp core download --allow-root
fi

# Wait for database to be ready
echo "⏳ Waiting for database..."
while ! wp db check --allow-root 2>/dev/null; do
    sleep 2
done

# Install WordPress if not already installed
if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "🔧 Installing WordPress..."
    
    # Get the Codespace URL
    if [ -n "$CODESPACE_NAME" ]; then
        SITE_URL="https://${CODESPACE_NAME}-80.app.github.dev"
    else
        SITE_URL="http://localhost"
    fi
    
    wp core install \
        --url="$SITE_URL" \
        --title="WP Engine Development" \
        --admin_user=admin \
        --admin_password=admin \
        --admin_email=admin@example.com \
        --allow-root
        
    echo "✅ WordPress installed at: $SITE_URL"
    echo "🔑 Admin credentials: admin/admin"
fi

# Create aliases for Lando-like commands
echo "🔗 Creating command aliases..."

cat >> ~/.bashrc << 'EOF'
# WP Engine Lando-like aliases
alias wp-download-db='bash /var/www/html/connect.sh --mode=plDB'
alias wp-download-media='bash /var/www/html/connect.sh --mode=plFS'
alias wp-logs='docker-compose logs -f wordpress'
alias wp-mysql='mysql -h mysql -u wordpress -pwordpress wordpress'
alias wp-info='env | grep -E "(DB_|WORDPRESS_|CODESPACE_)" | sort'
alias wp-reset='wp db reset --yes --allow-root'

# Interactive download functions
wp-db() {
    echo "? Pull DB from which WPE env? (DEV/STG/PRD)"
    read -p "Environment: " env
    E="$env" bash /var/www/html/connect.sh --mode=plDB
}

wp-media() {
    echo "? Pull files from which WPE env? (DEV/STG/PRD)"  
    read -p "Environment: " env
    E="$env" bash /var/www/html/connect.sh --mode=plFS
}
EOF

echo "🎉 Setup complete!"
echo ""
echo "Available commands:"
echo "  wp-db          - Interactive database download"
echo "  wp-media       - Interactive media download"  
echo "  wp-download-db - Direct database download"
echo "  wp-download-media - Direct media download"
echo "  wp-logs        - View WordPress logs"
echo "  wp-mysql       - Connect to MySQL"
echo "  wp-info        - Show environment info"
echo "  wp-reset       - Reset WordPress database"
echo ""

if [ -n "$CODESPACE_NAME" ]; then
    echo "🌐 Your WordPress site: https://${CODESPACE_NAME}-80.app.github.dev"
    echo "🗃️  PhpMyAdmin: https://${CODESPACE_NAME}-8080.app.github.dev"
else
    echo "🌐 Your WordPress site: http://localhost"
    echo "🗃️  PhpMyAdmin: http://localhost:8080"
fi