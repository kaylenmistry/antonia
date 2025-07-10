#!/bin/bash
set -e

# Run migrations
/app/bin/antonia eval "Antonia.Release.migrate()"

# Start the application
exec /app/bin/antonia start
