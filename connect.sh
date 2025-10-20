#!/usr/bin/env bash
set -euo pipefail

# Load environment variables from .env file if it exists
if [[ -f /app/.env ]]; then
    set -a  # Export all variables
    source /app/.env
    set +a
fi

# Map WPE env labels to actual env names
ENV_MAP_DEV="${DEV_ENV:-yoursite-dev}"
ENV_MAP_STG="${STG_ENV:-yoursite-stage}"
ENV_MAP_PRD="${PRD_ENV:-yoursite}"

# SSH Configuration
SSH_HOST="${SSH_HOST:-env.ssh.wpengine.net}"
SSH_USER_FMT="${SSH_USER_FMT:-%s@${SSH_HOST}}"  # %s => ENV_NAME
SITE_PATH_FMT="${SITE_PATH_FMT:-/sites/%s}"     # %s => ENV_NAME

# Domain Configuration
PRIMARY_PROD="${PRIMARY_DOMAIN:-https://yoursite.com}"
SECONDARY_PROD="${SECONDARY_DOMAIN:-https://subdomain.yoursite.com}"

PRIMARY_LOCAL_HOST="${PRIMARY_LOCAL:-yoursite.lndo.site}"
SECONDARY_LOCAL_HOST="${SECONDARY_LOCAL:-subdomain.yoursite.lndo.site}"
PRIMARY_LOCAL="https://${PRIMARY_LOCAL_HOST}"
SECONDARY_LOCAL="https://${SECONDARY_LOCAL_HOST}"

# Multisite Configuration
PRIMARY_BLOG_ID="${PRIMARY_BLOG_ID:-1}"
SECONDARY_BLOG_ID="${SECONDARY_BLOG_ID:-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}→${NC} $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

MODE="${1:-}"
if [[ "$MODE" == --mode=* ]]; then MODE="${MODE#--mode=}"; fi
E="${E:-PRD}"

# Check required commands
need() { 
    command -v "$1" >/dev/null 2>&1 || { 
        log_error "Missing required command: $1"
        exit 1
    }
}

log_info "Checking required commands..."
need ssh; need scp; need rsync; need wp
log_success "All required commands found"

# Validate and set environment
case "$E" in
  DEV) ENV_NAME="$ENV_MAP_DEV" ;;
  STG) ENV_NAME="$ENV_MAP_STG" ;;
  PRD) ENV_NAME="$ENV_MAP_PRD" ;;
  *)   
    log_error "Unknown environment: E='$E' (use DEV|STG|PRD)"
    exit 1 
    ;;
esac

SSH_USER=$(printf "$SSH_USER_FMT" "$ENV_NAME")
SITE_PATH=$(printf "$SITE_PATH_FMT" "$ENV_NAME")

log_info "Using environment: $E ($ENV_NAME)"
log_info "SSH User: $SSH_USER"
log_info "Remote Path: $SITE_PATH"

case "$MODE" in
  plDB)
    log_info "Starting database sync from WPE ($E:$ENV_NAME)..."
    
    # Test SSH connection first
    log_info "Testing SSH connection..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER" "echo 'SSH connection successful'"; then
        log_error "SSH connection failed. Check your SSH keys and WP Engine access."
        log_info "Run: ssh -v $SSH_USER to debug"
        exit 1
    fi
    log_success "SSH connection established"

    # Export database on remote
    log_info "Exporting database on WP Engine..."
    if ! ssh "$SSH_USER" "cd '$SITE_PATH' && (wp db export /tmp/wpe_dump.sql --add-drop-table --allow-root || wp db export /tmp/wpe_dump.sql --add-drop-table)"; then
        log_error "Failed to export database from WP Engine"
        exit 1
    fi
    log_success "Database exported on WP Engine"

    # Download database
    log_info "Downloading database..."
    if ! scp "$SSH_USER:/tmp/wpe_dump.sql" /app/wpe_dump.sql; then
        log_error "Failed to download database"
        exit 1
    fi
    log_success "Database downloaded"

    # Cleanup remote file
    ssh "$SSH_USER" "rm -f /tmp/wpe_dump.sql" || log_warning "Could not cleanup remote dump file"

    # Import locally
    log_info "Importing database locally..."
    wp db reset --yes
    if ! wp db import /app/wpe_dump.sql; then
        log_error "Failed to import database"
        exit 1
    fi
    rm -f /app/wpe_dump.sql
    log_success "Database imported"

    # URL replacements
    log_info "Performing URL replacements..."
    wp search-replace "$PRIMARY_PROD" "$PRIMARY_LOCAL" --network --precise --recurse-objects --all-tables || log_warning "Primary domain replacement had issues"
    wp search-replace "$SECONDARY_PROD" "$SECONDARY_LOCAL" --network --precise --recurse-objects --all-tables || log_warning "Secondary domain replacement had issues"
    
    # Handle HTTP versions too
    PRIMARY_HTTP="${PRIMARY_PROD//https:/http:}"
    SECONDARY_HTTP="${SECONDARY_PROD//https:/http:}"
    wp search-replace "$PRIMARY_HTTP" "$PRIMARY_LOCAL" --network --precise --recurse-objects --all-tables || true
    wp search-replace "$SECONDARY_HTTP" "$SECONDARY_LOCAL" --network --precise --recurse-objects --all-tables || true
    log_success "URL replacements completed"

    # Update multisite domains if configured
    if [[ "$PRIMARY_BLOG_ID" != "0" && "$SECONDARY_BLOG_ID" != "0" ]]; then
        log_info "Updating multisite domains..."
        wp db query "UPDATE wp_blogs SET domain = '$PRIMARY_LOCAL_HOST', path = '/' WHERE blog_id = $PRIMARY_BLOG_ID;" || true
        wp db query "UPDATE wp_blogs SET domain = '$SECONDARY_LOCAL_HOST', path = '/' WHERE blog_id = $SECONDARY_BLOG_ID;" || true
        log_success "Multisite domains updated"
    fi

    # Final cleanup
    wp option update blog_public 0 || true
    wp rewrite flush || log_warning "Could not flush rewrite rules"

    log_success "Database sync complete!"
    log_info "Sites available at:"
    log_info "  • $PRIMARY_LOCAL"
    log_info "  • $SECONDARY_LOCAL"
    ;;
    
  plFS)
    log_info "Starting files sync from WPE ($E:$ENV_NAME)..."
    
    # Test SSH connection first
    log_info "Testing SSH connection..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER" "echo 'SSH connection successful'"; then
        log_error "SSH connection failed. Check your SSH keys and WP Engine access."
        exit 1
    fi
    log_success "SSH connection established"

    # Sync files
    log_info "Syncing wp-content from WP Engine..."
    if ! rsync -az --delete --progress -e ssh "$SSH_USER:$SITE_PATH/wp-content/" /app/wp-content/; then
        log_error "Failed to sync files from WP Engine"
        exit 1
    fi
    log_success "Files sync complete!"
    ;;
    
  *)
    log_error "Invalid mode: $MODE"
    echo "Usage: $0 --mode=plDB|plFS (and pass E=DEV|STG|PRD via lando tooling)"
    exit 1 
    ;;
esac