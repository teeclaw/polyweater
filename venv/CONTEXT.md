# venv/ - Python Virtual Environment

## PURPOSE
Isolated Python environment with all required dependencies for local development and testing.

## STATUS
- **LOCAL DEVELOPMENT**: Used for non-Docker development workflows
- **TESTING**: Isolated environment for dependency validation
- **NOT DEPLOYED**: Production uses Docker containers instead

## PYTHON CONFIGURATION
- **Python Version**: 3.11+ (compatible with all dependencies)
- **Package Manager**: pip with requirements.txt
- **Isolation**: Completely separate from system Python

## DEPENDENCY MANAGEMENT
```bash
# Activation
source venv/bin/activate              # Linux/Mac
venv\Scripts\activate.bat             # Windows

# Package installation
pip install -r requirements.txt      # Core dependencies
pip install -r requirements-secure.txt # Security packages

# Development packages
pip install streamlit plotly pandas requests
```

## INCLUDED PACKAGES
- **Streamlit**: Dashboard framework
- **Plotly**: Interactive data visualization  
- **Pandas**: Data analysis and manipulation
- **Requests**: HTTP API client
- **FastAPI**: Backend API framework (if developing locally)
- **PostgreSQL drivers**: Database connectivity

## RELATIONS
- **Alternative to**: Docker containers for local development
- **Synced with**: requirements.txt and Docker image dependencies
- **Used by**: Local testing and development scripts
- **Replaced by**: Docker in production deployment

## LOCAL DEVELOPMENT WORKFLOW
```bash
# Setup
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Development
streamlit run streamlit_dashboard.py  # Local dashboard
python scripts/test-apis.py          # API testing

# Deactivation
deactivate
```

## MAINTENANCE
- **Dependency Updates**: Regular package updates via pip
- **Security Scanning**: Automated vulnerability checks
- **Synchronization**: Keep in sync with Docker requirements

**Local development environment for testing before Docker deployment**