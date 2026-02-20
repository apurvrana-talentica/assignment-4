import os
import sqlite3
import bcrypt
from jose import jwt, JWTError
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import uvicorn
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="User Service API", version="1.0.0")

# Security
security = HTTPBearer(auto_error=False)

# Database configuration
DB_PATH = "/data/users.db"
JWT_SECRET = os.getenv("JWT_SECRET", "fallback-secret-key")
JWT_ALGORITHM = "HS256"

# Pydantic models
class LoginRequest(BaseModel):
    username: str
    password: str

class UserResponse(BaseModel):
    id: int
    username: str
    created_at: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str

class VerifyResponse(BaseModel):
    status: str
    message: str
    user_id: Optional[int] = None
    username: Optional[str] = None

# Database functions
def init_db():
    """Initialize SQLite database with users table and demo user"""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create users table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Create demo user (username: admin, password: admin123)
    demo_password = "admin123"
    password_hash = bcrypt.hashpw(demo_password.encode('utf-8'), bcrypt.gensalt())
    
    try:
        cursor.execute(
            "INSERT INTO users (username, password_hash) VALUES (?, ?)",
            ("admin", password_hash)
        )
        logger.info("Demo user created: admin/admin123")
    except sqlite3.IntegrityError:
        logger.info("Demo user already exists")
    
    conn.commit()
    conn.close()

def get_user_by_username(username: str) -> Optional[Dict[str, Any]]:
    """Get user by username from database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT id, username, password_hash, created_at FROM users WHERE username = ?", (username,))
    row = cursor.fetchone()
    
    conn.close()
    
    if row:
        return {
            "id": row[0],
            "username": row[1],
            "password_hash": row[2],
            "created_at": row[3]
        }
    return None

def get_all_users():
    """Get all users from database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT id, username, created_at FROM users")
    rows = cursor.fetchall()
    
    conn.close()
    
    return [{"id": row[0], "username": row[1], "created_at": row[2]} for row in rows]

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash"""
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password)

def create_jwt_token(user_id: int, username: str) -> str:
    """Create JWT token for user"""
    payload = {
        "sub": str(user_id),
        "username": username,
        "iss": "api-consumer",  # Kong consumer key
        "exp": datetime.utcnow() + timedelta(hours=1),
        "iat": datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def verify_jwt_token(token: str) -> Optional[Dict[str, Any]]:
    """Verify JWT token and return payload"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("Token expired")
        return None
    except JWTError as e:
        logger.warning(f"Token validation failed: {e}")
        return None

# Dependency to get current user from JWT
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """Dependency to extract and validate current user from JWT"""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header missing"
        )
    
    token = credentials.credentials
    payload = verify_jwt_token(token)
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    
    return payload

# API Routes
@app.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    """Authenticate user and return JWT token"""
    user = get_user_by_username(request.username)
    
    if not user or not verify_password(request.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )
    
    token = create_jwt_token(user["id"], user["username"])
    
    logger.info(f"User {request.username} logged in successfully")
    
    return TokenResponse(
        access_token=token,
        token_type="bearer"
    )

@app.get("/verify", response_model=VerifyResponse)
async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify JWT token - public endpoint that works with or without token"""
    if not credentials:
        return VerifyResponse(
            status="no_token",
            message="No authorization token provided"
        )
    
    token = credentials.credentials
    payload = verify_jwt_token(token)
    
    if not payload:
        return VerifyResponse(
            status="invalid_token",
            message="Invalid or expired token"
        )
    
    return VerifyResponse(
        status="valid_token",
        message="Token is valid",
        user_id=int(payload["sub"]),
        username=payload["username"]
    )

@app.get("/users", response_model=list[UserResponse])
async def get_users(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Get all users - requires JWT authentication"""
    logger.info(f"User {current_user['username']} accessed users endpoint")
    
    users = get_all_users()
    return [UserResponse(**user) for user in users]

@app.get("/health")
async def health_check():
    """Health check endpoint - public"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }

# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize database on startup"""
    logger.info("Initializing database...")
    init_db()
    logger.info("Database initialized successfully")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)