# .streamlit/ - Streamlit Configuration

## PURPOSE
Configuration directory for Streamlit dashboard settings and behavior customization.

## CONTENTS
- `config.toml` - Main Streamlit configuration with headless mode, port settings, and telemetry controls

## KEY CONFIGURATION
```toml
[server]
headless = true          # Prevents email prompt on GCP
port = 3000             # Standardized port (NOT 8501)
enableCORS = false
```

## RELATIONS
- **Controls**: `streamlit_dashboard.py` behavior and startup
- **Used by**: Docker containers and deployment scripts
- **Critical for**: GCP headless deployment (prevents hanging on email prompt)

## RECENT FIXES
- Fixed email prompt hanging issue with `headless = true`
- Standardized port from 8501 back to 3000 for consistency