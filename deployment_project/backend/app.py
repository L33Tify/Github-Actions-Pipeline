from flask import Flask, jsonify, request
from flask_cors import CORS
import json
import os
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime
import sys

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes to allow frontend access


# Configure logging
def setup_logging():
    """Configure logging with rotation and stdout output"""
    # Create formatter
    log_format = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Configure root logger
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Clear existing handlers
    logger.handlers.clear()
    
    # Console handler (stdout) - for kubectl logs
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(log_format)
    logger.addHandler(console_handler)
    
    # File handler with rotation (optional - for persistent logs)
    # Max 10MB per file, keep 5 backup files
    try:
        log_dir = '/tmp/logs'
        os.makedirs(log_dir, exist_ok=True)
        file_handler = RotatingFileHandler(
            f'{log_dir}/backend.log',
            maxBytes=10*1024*1024,  # 10MB
            backupCount=5
        )
        file_handler.setLevel(logging.INFO)
        file_handler.setFormatter(log_format)
        logger.addHandler(file_handler)
    except Exception as e:
        logger.warning(f"Could not setup file logging: {e}")
    
    return logger


# Setup logging
logger = setup_logging()
logger.info("Backend application starting up...")


# Load user data from JSON file
def load_users():
    """Load users from the JSON file"""
    try:
        users_file_path = os.path.join(os.path.dirname(__file__), "users.json")
        with open(users_file_path, "r") as file:
            data = json.load(file)
            logger.info(f"Successfully loaded {len(data)} users from users.json")
            return data
    except FileNotFoundError:
        logger.error("users.json file not found. Using empty user list.")
        return []
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in users.json file: {e}. Using empty user list.")
        return []


# Load users on application startup
users = load_users()


@app.route("/api/users", methods=["GET"])
def get_all_users():
    """Get all users"""
    client_ip = request.remote_addr
    logger.info(f"GET /api/users - All users requested by {client_ip}")
    return jsonify({"success": True, "data": users, "count": len(users)})


@app.route("/api/users/<int:user_id>", methods=["GET"])
def get_user_by_id(user_id):
    """Get a specific user by ID"""
    client_ip = request.remote_addr
    timestamp = datetime.now().isoformat()
    
    logger.info(f"GET /api/users/{user_id} - User ID {user_id} searched by {client_ip} at {timestamp}")
    
    user = next((u for u in users if u["id"] == user_id), None)

    if user:
        logger.info(f"User ID {user_id} found - Name: {user.get('name', 'Unknown')}")
        return jsonify({"success": True, "data": user})
    else:
        logger.warning(f"User ID {user_id} not found - Requested by {client_ip}")
        return jsonify(
            {"success": False, "message": f"User with ID {user_id} not found"}
        ), 404


@app.route("/api/health", methods=["GET"])
def health_check():
    """Health check endpoint"""
    logger.debug("Health check requested")
    return jsonify({"success": True, "message": "Backend is running successfully"})


@app.errorhandler(404)
def not_found(error):
    logger.warning(f"404 Error - Endpoint not found: {request.path}")
    return jsonify({"success": False, "message": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    logger.error(f"500 Error - Internal server error: {error}")
    return jsonify({"success": False, "message": "Internal server error"}), 500


if __name__ == "__main__":
    logger.info("Starting Flask application on 0.0.0.0:5000")
    app.run(debug=False, host="0.0.0.0", port=5000)
