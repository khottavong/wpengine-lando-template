# WP Engine Lando Template

A reusable Lando configuration for WP Engine WordPress sites with Pantheon-style interactive commands.

## 🚀 Quick Start

1. **Clone this template:**
   ```bash
   git clone <this-repo> your-project-name
   cd your-project-name
   ```

2. **Configure your site:**
   ```bash
   cp .env.example .env
   # Edit .env with your WP Engine environment names and domains
   ```

3. **Update `.lando.yml`:**
   - Change `name:` to your project name
   - Update `proxy` domains to match your local development URLs

4. **Start Lando:**
   ```bash
   lando start
   ```

5. **Download WordPress and sync data:**
   ```bash
   lando wp core download
   lando download:db    # Interactive prompt for environment
   lando download:media # Interactive prompt for environment
   ```

## 📋 Prerequisites

- [Lando](https://lando.dev/) installed
- SSH keys configured for WP Engine access
- WP Engine environments set up

## 🔧 Configuration

### Environment Variables (.env)

```bash
# WP Engine environment names
DEV_ENV=yoursite-dev
STG_ENV=yoursite-stage  
PRD_ENV=yoursite

# Production domains (for URL replacement)
PRIMARY_DOMAIN=https://yoursite.com
SECONDARY_DOMAIN=https://subdomain.yoursite.com

# Local development domains
PRIMARY_LOCAL=yoursite.lndo.site
SECONDARY_LOCAL=subdomain.yoursite.lndo.site

# Multisite blog IDs (if applicable)
PRIMARY_BLOG_ID=1
SECONDARY_BLOG_ID=2
```

### SSH Key Setup

1. **Generate SSH key for WP Engine:**
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/wpengine
   ```

2. **Add to WP Engine:**
   - Copy public key: `cat ~/.ssh/wpengine.pub`
   - Add to WP Engine User Portal → SSH Keys

3. **Configure SSH (~/.ssh/config):**
   ```
   Host *.ssh.wpengine.net
     User git
     IdentityFile ~/.ssh/wpengine
     IdentitiesOnly yes
   ```

## 🛠️ Available Commands

### Interactive Environment Selection (Pantheon-style)
```bash
lando download:db     # Interactive prompt: DEV, STG, PRD
lando download:media  # Interactive prompt: DEV, STG, PRD  
```

### Direct Environment Specification
```bash
lando download:db -e PRD     # Pull from production
lando download:db -e STG     # Pull from staging
lando download:db -e DEV     # Pull from development
```

### WordPress Management
```bash
lando wp <command>           # Any WP-CLI command
lando wp site list           # List multisite sites
lando wp user list           # List users
lando wp cache flush         # Flush cache
```

### Development Tools
```bash
lando logs                   # View container logs
lando ssh                    # SSH into appserver
lando mysql                  # Access database
lando info                   # View connection info
```

## 🏗️ Project Structure

```
your-project/
├── .lando.yml          # Lando configuration
├── connect.sh          # WP Engine sync script
├── .env.example        # Environment template
├── .env                # Your environment config (gitignored)
├── .gitignore          # Git ignore rules
├── README.md           # This file
└── wp-content/         # WordPress content (after sync)
```

## 🔄 Workflow

### Initial Setup
1. Clone template
2. Configure `.env` and `.lando.yml`
3. `lando start`
4. `lando wp core download`
5. `lando download:db` (choose environment)
6. `lando download:media` (choose environment)

### Daily Development
1. `lando start` (if not running)
2. Work on your site at https://yoursite.lndo.site
3. `lando download:db -e STG` (sync staging when needed)
4. `lando wp <commands>` for WordPress management

### Updating from WP Engine
- **Database:** `lando download:db` → select environment
- **Files:** `lando download:media` → select environment
- **Both:** Run both commands in sequence

## 🔧 Customization

### For Single Sites
- Remove multisite-specific code from `connect.sh`
- Update `.lando.yml` proxy to single domain
- Remove blog ID configurations

### For Different PHP Versions
```yaml
# In .lando.yml
config:
  php: '8.1'  # or '7.4', '8.0', '8.2'
```

### Additional Domains
```yaml
# In .lando.yml
proxy:
  appserver:
    - primary.lndo.site
    - secondary.lndo.site
    - api.lndo.site
```

## 🐛 Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connection
ssh git@yoursite.ssh.wpengine.net

# Debug SSH
ssh -v git@yoursite.ssh.wpengine.net
```

### Database Import Fails
```bash
# Check WP-CLI version
lando wp --version

# Reset database manually
lando wp db reset --yes
lando wp db import your-dump.sql
```

### SSL/Certificate Issues
```bash
# Rebuild Lando
lando rebuild -y

# Check certificate status
lando info
```

## 📚 Resources

- [Lando Documentation](https://docs.lando.dev/)
- [WP Engine SSH Documentation](https://wpengine.com/support/ssh-gateway/)
- [WP-CLI Commands](https://wp-cli.org/commands/)

## 🤝 Contributing

Feel free to submit issues and pull requests to improve this template!

## 📄 License

MIT License - feel free to use for any WP Engine projects.