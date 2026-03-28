# frontend/ - Legacy Frontend Files (DEPRECATED)

## PURPOSE
**⚠️ DEPRECATED**: Legacy frontend assets and build artifacts from the original React implementation.

## STATUS
- **DO NOT USE**: Contains outdated and potentially corrupted files
- **REPLACED BY**: `streamlit_dashboard.py` in project root
- **SECURITY RISK**: May contain malicious JavaScript injections

## ORIGINAL CONTENTS
- Static HTML/CSS/JavaScript files
- React build artifacts and bundle files  
- Legacy routing and component definitions
- Obsolete API integration code

## WHY DEPRECATED
1. **JavaScript Corruption**: Malicious code injection compromised reliability
2. **Security Vulnerabilities**: Difficult to secure client-side code
3. **Maintenance Overhead**: React complexity vs Python simplicity
4. **Performance Issues**: Bundle size and loading delays

## MIGRATION COMPLETED
- **Authentication**: Moved to Python backend with session management
- **Real-time Updates**: Streamlit auto-refresh eliminates WebSocket complexity
- **Trading Interface**: Pure Python forms with immediate validation
- **Data Visualization**: Plotly integration within Streamlit

## RELATIONS
- **Superseded by**: `streamlit_dashboard.py` (bulletproof Python)
- **Referenced in**: Legacy Docker configurations (unused)
- **Security concern**: Potential JavaScript malware - avoid executing

**Complete migration to Streamlit eliminates all frontend security risks**