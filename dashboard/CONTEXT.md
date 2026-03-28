# dashboard/ - Legacy React Dashboard (DEPRECATED)

## PURPOSE
**⚠️ DEPRECATED**: Original React-based dashboard that was corrupted by malicious JavaScript injection.

## STATUS
- **DO NOT USE**: This directory contains corrupted React code
- **REPLACED BY**: `streamlit_dashboard.py` in project root
- **REASON FOR DEPRECATION**: JavaScript corruption made the dashboard unreliable

## CONTENTS
- Legacy React components, package.json, and Node.js dependencies
- May contain malicious code injections - avoid modification

## RELATIONS
- **Replaced by**: `streamlit_dashboard.py` (bulletproof Python implementation)
- **Referenced in**: Old Docker configurations (no longer used)
- **Migration path**: All functionality moved to Streamlit

## MIGRATION NOTES
- User authentication: Moved to Python backend
- Real-time updates: Implemented via Streamlit auto-refresh
- Trading controls: Pure Python implementation without JavaScript vulnerabilities

**Use `streamlit_dashboard.py` instead - access on Port 3000**