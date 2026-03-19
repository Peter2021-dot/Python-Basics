@echo off
echo Starting Image Generator Server Setup...

:: Check if python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Python is not installed or not in PATH.
    pause
    exit /b
)

:: Create virtual environment if it doesn't exist
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
)

:: Activate virtual environment and install requirements
echo Installing dependencies...
call venv\Scripts\activate
pip install -r requirements.txt

:: Run the server
echo Starting Flask server on port 5000...
python app.py

pause
