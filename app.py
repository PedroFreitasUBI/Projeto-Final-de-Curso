from flask import Flask, request, jsonify, session
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import hashlib
import jwt
from datetime import datetime, timedelta
from functools import wraps
import secrets

app = Flask(__name__)
app.secret_key = '78THlAlCYRHZ5rDnea3TRSRZGr3crjab'  # Your 256-bit key

# JWT Configuration
app.config['JWT_SECRET_KEY'] = '78THlAlCYRHZ5rDnea3TRSRZGr3crjab'
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(minutes=15)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = timedelta(days=30)

CORS(app,
     supports_credentials=True,
     origins=["http://localhost:3000", "http://127.0.0.1:5000", "http://10.0.2.2:5000"],
     expose_headers=["Set-Cookie"],
     allow_headers=["Content-Type", "Authorization", "Cookie"])

# Database configuration
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Rl4e25rh',
    'database': 'iot_app'
}

# Helper Functions
def get_db_connection():
    try:
        return mysql.connector.connect(
            host='localhost',
            user='root',
            password='Rl4e25rh',
            database='iot_app',
            autocommit=False,  # Important for transactions
            buffered=True      # Helps prevent unread results
        )
    except mysql.connector.Error as err:
        print(f"Database connection failed: {err}")
        raise

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def create_tokens(user_id, remember_me=False):
    access_token = jwt.encode(
        {
            'user_id': user_id,
            'exp': datetime.utcnow() + app.config['JWT_ACCESS_TOKEN_EXPIRES']
        },
        app.config['JWT_SECRET_KEY'],
        algorithm='HS256'
    )
    
    refresh_token = jwt.encode(
        {
            'user_id': user_id,
            'exp': datetime.utcnow() + (
                app.config['JWT_REFRESH_TOKEN_EXPIRES'] if remember_me 
                else timedelta(hours=1)
            )
        },
        app.config['JWT_SECRET_KEY'],
        algorithm='HS256'
    )
    
    return {
        'access_token': access_token,
        'refresh_token': refresh_token,
        'token_type': 'bearer'
    }

# Authentication Decorator
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        if 'Authorization' in request.headers:
            token = request.headers['Authorization'].split()[1]
            
        if not token:
            return jsonify({"error": "Token is missing"}), 401

        try:
            data = jwt.decode(token, app.config['JWT_SECRET_KEY'], algorithms=['HS256'])
            current_user = data['user_id']
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token has expired"}), 401
        except Exception as e:
            return jsonify({"error": "Token is invalid"}), 401

        return f(current_user, *args, **kwargs)
    return decorated

# Routes

@app.route('/iot-data', methods=['POST'])
def receive_iot_data():
    data = request.json  # Exemplo esperado: {'station_id': '1wtest', 'location': 'Lab', 'measurements': [{'type': 'humidity', 'value': 45.0, 'recorded_at': '2025-05-06 12:00:00'}, ...]}
    print(f"Received IoT data: {data}")

    station_id = data.get('station_id')
    location = data.get('location', None)
    measurements = data.get('measurements', [])

    if not station_id or not measurements:
        return jsonify({"error": "station_id and measurements are required"}), 400

    conn = get_db_connection()
    try:
        cursor = conn.cursor()

        # Insere a estação se não existir
        cursor.execute("SELECT 1 FROM iot_stations WHERE station_id = %s", (station_id,))
        if not cursor.fetchone():
            cursor.execute(
                "INSERT INTO iot_stations (station_id, location) VALUES (%s, %s)",
                (station_id, location)
            )

        # Insere as medições
        for m in measurements:
            m_type = m.get('type')
            value = m.get('value')
            recorded_at = m.get('recorded_at')  # Deve ser string no formato 'YYYY-MM-DD HH:MM:SS'
            if not (m_type and value is not None and recorded_at):
                continue  # Pula medições incompletas

            cursor.execute(
                "INSERT INTO measurements (station_id, measurement_type, value, recorded_at) VALUES (%s, %s, %s, %s)",
                (station_id, m_type, value, recorded_at)
            )

        conn.commit()
        return jsonify({"status": "success"}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error inserting IoT data: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')
    user_type = data.get('type', 1)

    if not all([username, email, password]):
        return jsonify({"error": "Missing fields"}), 400

    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE username = %s OR email = %s", 
                      (username, email))
        if cursor.fetchone():
            return jsonify({"error": "Username or email already exists"}), 409

        cursor.execute(
            "INSERT INTO users (username, email, password_hash, type) VALUES (%s, %s, %s, %s)",
            (username, email, hash_password(password), user_type))
        conn.commit()
        user_id = cursor.lastrowid
        
        tokens = create_tokens(user_id)
        return jsonify({
            "status": "success",
            "user": {
                "id": user_id,
                "username": username,
                "email": email,
                "type": user_type
            },
            "tokens": tokens
        }), 201
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        cursor.close()
        conn.close()

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    remember_me = data.get('remember_me', False)

    if not all([username, password]):
        return jsonify({"error": "Username and password required"}), 400

    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT id, username, email, type, points FROM users WHERE username = %s AND password_hash = %s",
            (username, hash_password(password)))
        user = cursor.fetchone()

        if user:
            tokens = create_tokens(user['id'], remember_me)
            
            response = jsonify({
                "status": "success",
                "user": user,
                "tokens": tokens
            })
            response.headers.add("Access-Control-Allow-Credentials", "true")
            return response, 200
        return jsonify({"error": "Invalid credentials"}), 401
    except Error as e:
        return jsonify({"error": str(e)}), 400
    finally:
        cursor.close()
        conn.close()

@app.route('/check-session', methods=['GET'])
@token_required
def check_session(current_user):
    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT username, email FROM users WHERE id = %s",
            (current_user,)
        )
        user = cursor.fetchone()
        return jsonify({"status": "active", "user": user}), 200 if user else 404
    except Error as e:
        return jsonify({"error": str(e)}), 400
    finally:
        cursor.close()
        conn.close()

@app.route('/user-profile', methods=['GET'])
@token_required
def get_user_profile(current_user):
    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database error"}), 500

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT username, email, points FROM users WHERE id = %s",
            (current_user,))
        user = cursor.fetchone()
        return jsonify(user or {"error": "User not found"}), 200 if user else 404
    except Error as e:
        return jsonify({"error": str(e)}), 400
    finally:
        cursor.close()
        conn.close()

@app.route('/api/stations', methods=['GET'])
@token_required
def get_stations(current_user):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Fetch unique station IDs from the iot_stations table
        cursor.execute("""
            SELECT DISTINCT station_id 
            FROM iot_stations
        """)
        
        stations = [row['station_id'] for row in cursor.fetchall()]
        return jsonify(stations)  # Return as a simple array
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/measurement-types', methods=['GET'])
@token_required
def get_measurement_types(current_user):
    # Return types matching your database enum
    return jsonify([
        "humidity",
        "max_wind",
        "wind_speed",
        "precipitation",
        "pressure",
        "temperature",
        "wind_direction",
        "soil_moisture"
    ])

@app.route('/api/measurements', methods=['GET'])
@token_required
def get_measurements(current_user):
    conn = None
    cursor = None
    try:
        # Get query parameters
        station_id = request.args.get('station_id')
        measurement_type = request.args.get('type')
        print(f"Station ID: {station_id}, Measurement Type: {measurement_type}")

        if not station_id or not measurement_type:
            return jsonify({"error": "Missing required parameters"}), 400

        # Parse optional date parameters as UNIX timestamps
        start_timestamp = request.args.get('start')
        end_timestamp = request.args.get('end')

        if not start_timestamp or not end_timestamp:
            return jsonify({"error": "Missing start or end timestamp"}), 400

        # Convert UNIX timestamps to datetime objects
        start_date = datetime.fromtimestamp(int(start_timestamp))
        end_date = datetime.fromtimestamp(int(end_timestamp))
        print(f"Start Date: {start_date}, End Date: {end_date}")

        # Verify user has access to this station
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT 1 FROM user_station_access 
            WHERE user_id = %s AND station_id = %s
        """, (current_user, station_id))
        
        if not cursor.fetchone():
            return jsonify({"error": "No access to this station"}), 403

        # Get measurements within date range
        cursor.execute("""
            SELECT 
                recorded_at,
                value 
            FROM measurements 
            WHERE 
                station_id = %s AND 
                measurement_type = %s AND
                recorded_at BETWEEN %s AND %s
            ORDER BY recorded_at
        """, (station_id, measurement_type, start_date, end_date))
        print(f"Query executed successfully")

        # Format response with UNIX timestamps
        data = []
        for row in cursor.fetchall():
            recorded_at = row['recorded_at']  # Use directly as datetime
            data.append({
                "x": int(recorded_at.timestamp()),  # Convert to UNIX timestamp
                "y": float(row['value'])
            })
        print(f"Data: {data}")

        return jsonify(data)

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route('/api/validate-qr', methods=['POST'])
@token_required
def validate_qr_code(current_user):
    data = request.json
    qr_content = data.get('qr_content')
    
    if not qr_content:
        return jsonify({"error": "QR content required"}), 400

    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        
        # Check if QR code exists and hasn't been used
        cursor.execute("""
            SELECT qr_id, points_awarded 
            FROM qr_codes 
            WHERE code_hash = SHA2(%s, 256) 
            AND scanned_at IS NULL
        """, (qr_content,))
        
        qr_data = cursor.fetchone()
        
        if not qr_data:
            return jsonify({
                "valid": False,
                "error": "Invalid or already used QR code"
            }), 400
        
        # Mark QR code as scanned
        cursor.execute("""
            UPDATE qr_codes 
            SET user_id = %s, scanned_at = NOW() 
            WHERE qr_id = %s
        """, (current_user, qr_data['qr_id']))
        
        # Update user points
        cursor.execute("""
            UPDATE users 
            SET points = points + %s 
            WHERE id = %s
        """, (qr_data['points_awarded'], current_user))
        
        conn.commit()
        return jsonify({
            "valid": True,
            "points_awarded": qr_data['points_awarded'],
            "message": "QR code validated successfully"
        }), 200
        
    except Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/generate-qr', methods=['POST'])
@token_required
def generate_qr_code(current_user):
    conn = None
    cursor = None
    try:
        # Validate input
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400
            
        points = data.get('points', 10)
        if not isinstance(points, int) or points <= 0:
            return jsonify({"error": "Points must be positive integer"}), 400

        # Generate QR code
        qr_code = secrets.token_urlsafe(32)
        
        # Get database connection
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Verify user exists
        cursor.execute("SELECT id FROM users WHERE id = %s", (current_user,))
        if not cursor.fetchone():
            return jsonify({"error": "User not found"}), 404
        
        # Insert QR code
        cursor.execute("""
            INSERT INTO qr_codes 
            (user_id, code_hash, points_awarded, location_name)
            VALUES (%s, SHA2(%s, 256), %s, 'Generated Code')
            """, 
            (current_user, qr_code, points))
        
        if cursor.rowcount != 1:
            raise Exception("No rows affected")
            
        conn.commit()
        
        return jsonify({
            "status": "success",
            "qr_code": qr_code,
            "points": points
        }), 201
        
    except mysql.connector.Error as db_err:
        if conn:
            conn.rollback()
        return jsonify({
            "error": "Database error",
            "code": db_err.errno,
            "sql_state": db_err.sqlstate,
            "message": db_err.msg
        }), 500
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({
            "error": "Operation failed",
            "details": str(e)
        }), 500
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

@app.route('/logout', methods=['POST'])
@token_required
def logout(current_user):
    # With JWT, logout is client-side (just delete the token)
    return jsonify({"status": "success"}), 200

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=True)