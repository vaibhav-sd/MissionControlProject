from flask import Flask, request, jsonify, abort
import redis
import uuid
import pika
import json
from threading import Thread
import threading
import time
from datetime import datetime, timedelta
from flask_cors import CORS

app = Flask(__name__)
CORS(app, origins=["http://localhost:3000"])

REDIS_URL = 'redis'
ORDERS_QUEUE = 'orders_queue'
STATUS_QUEUE = 'status_queue'
RABBITMQ_URL = 'rabbitmq'
RABBITMQ_USER = 'guest'
RABBITMQ_PASSWORD = 'guest'
TOKEN_ROTATION_INTERVAL = 30
RABBITMQ_PORT = 5672

mission_status = {}
active_tokens = {}
token_lock = threading.Lock()

try:
    redis_conn = redis.Redis(REDIS_URL, port=6379)
    redis_conn.ping()
except Exception as e:
    print(f"Failed to connect to Redis: {e}")
    redis_conn = None

def get_rabbitmq_conn(retries=5, delay=3):
    for attempt in range(retries):
        try:
            credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
            parameters = pika.ConnectionParameters(RABBITMQ_URL, RABBITMQ_PORT, '/', credentials)
            rmq_conn = pika.BlockingConnection(parameters)
            print("Connected to RabbitMQ.")
            return rmq_conn
        except Exception as e:
            print(f"Attempt {attempt+1}/{retries}: Failed to connect to RabbitMQ - {e}")
            time.sleep(delay)
    print("All attempts to connect to RabbitMQ failed.")
    return None

def setup_queues():
    try:
        rmq_conn = get_rabbitmq_conn()
        channel  = rmq_conn.channel()
        channel.queue_declare(queue=ORDERS_QUEUE, durable=True)
        channel.queue_declare(queue=STATUS_QUEUE, durable=True)
        rmq_conn.close()
        print("Queues are setuped.")

    except Exception as e:
        print('Failed to setup Queues.')

def generate_token():
    token = str(uuid.uuid4())
    expiry = datetime.now() + timedelta(seconds=TOKEN_ROTATION_INTERVAL)
    
    with token_lock:
        active_tokens[token] = expiry
        # Clean up expired tokens
        current_time = datetime.now()
        expired_tokens = [t for t, exp in active_tokens.items() if exp < current_time]
        for expired_token in expired_tokens:
            del active_tokens[expired_token]
    
    print(f"Generated new token: {token[:8]}... (expires at {expiry})")
    return token, expiry

def is_token_valid(token):
    with token_lock:
        if token in active_tokens:
            return active_tokens[token] > datetime.now()
        return False

def get_status(mission_id):
    if redis_conn:
        try:
            status = redis_conn.hget('missions', mission_id)
            if status:
                return json.loads(status.decode())
        except Exception as e:
            print(f"Getting error {e}")

    return mission_status.get(mission_id)

def publish_order(queue_name, data):
    rmq_conn = get_rabbitmq_conn()
    if rmq_conn:
        try:
            channel = rmq_conn.channel()
            channel.queue_declare(queue=queue_name, durable=True)

            channel.basic_publish(exchange='', routing_key=queue_name, body=json.dumps(data))
            
            rmq_conn.close()
            print(f'Published the data to {queue_name}')
            return True
        
        except Exception as e:
            return False

def store_mission_status(mission_id, status):
    mission_status[mission_id] = {
        'status': status,
    }
    if redis_conn:
        try:
            redis_conn.hset('missions', mission_id, json.dumps(mission_status[mission_id]))

        except Exception as e:
            print(f'Getting issue {e}')

def status_updates_listener():
    rmq_conn = get_rabbitmq_conn()
    if not rmq_conn:
        print("Error while starting RMQ")
        return 

    try:
        channel = rmq_conn.channel()

        channel.queue_declare(queue=STATUS_QUEUE, durable=True)

        def callback(ch, method, properties, body):
            message = json.loads(body)
            print(f"Status update received in Flask app: {message}")  

            mission_id = message.get('mission_id')
            status = message.get('mission_status')
            token = message.get('token')

            if not token or not is_token_valid(token):
                print(f"Invalid token received for mission {mission_id}")
                ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
                return
            
            store_mission_status(mission_id, status)
            ch.basic_ack(delivery_tag=method.delivery_tag)  


        channel.basic_qos(prefetch_count=1)
        channel.basic_consume(queue=STATUS_QUEUE, on_message_callback=callback)
        channel.start_consuming()

    except Exception as e:
        print(f'Getting error {e}')

@app.route('/', methods=['GET'])
def home():
    return "Hello, World!"

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'services': {
            'redis': redis_conn is not None,
            'rabbitmq': get_rabbitmq_conn() is not None
        }
    }), 200

@app.route('/auth/token', methods=['POST'])
def get_auth_token():
    try:
        token, expiry = generate_token()
        
        return jsonify({
            'token': token,
            'expires_at': expiry.isoformat(),
            'expires_in_seconds': TOKEN_ROTATION_INTERVAL
        }), 200
        
    except Exception as e:
        print(f"Error generating token: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/missions', methods=['POST'])
def create_mission():
    try:
        data = request.get_json()
        
        mission_id = str(uuid.uuid4())

        mission_order = {
            'mission_id':mission_id,
            'mission_data': data,
            'timestamp': datetime.now().isoformat()
        }

        store_mission_status(mission_id, "QUEUED")
        if publish_order(ORDERS_QUEUE, mission_order):
            print(f"Mission {mission_id} queued successfully")
            return jsonify({
                'mission_id': mission_id,
                'status': 'QUEUED',
                'message': 'Mission queued successfully',
                'timestamp': datetime.now().isoformat()
            }), 202
        else:
            return jsonify({'error': 'Failed to queue mission'}), 500
            
    except Exception as e:
        print(f"Error creating mission: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/missions', methods=['GET'])
def list_missions():
    try:
        missions = []
        if redis_conn:
            try:
                data = redis_conn.hgetall('missions')
                for mission_id, status_json in data.items():
                    status_data = json.loads(status_json.decode())
                    missions.append({
                        'mission_id': mission_id.decode(),
                        'status': status_data.get('status'),
                        'timestamp': datetime.now().isoformat()
                    })
            except Exception as e:
                print(f"Issue with redis")
                for mission_id, status_json in data.items():
                    status_data = json.loads(status_json.decode())
                    missions.append({
                        'mission_id': mission_id.decode(),
                        'status':status_data.get('status'),
                        'timestamp': datetime.now().isoformat()
                    })

        else:
            for mission_id, status_json in mission_status.items():
                missions.append({
                    'mission_id': mission_id,
                    'status': mission_status[mission_id].get('status'),
                    'timestamp': datetime.now().isoformat()
                })

        return jsonify({"missions":missions}), 200

    except Exception as e:
        print(f'Having Error {e}')



@app.route('/missions/<mission_id>', methods=['GET'])
def get_mission_status(mission_id):
    
    try:
        status_data = get_status(mission_id)
        
        if not status_data:
            return jsonify({'error': 'Mission not found'}), 404
        
        return jsonify({
            'mission_id': mission_id,
            'status': status_data['status'],
            'timestamp': datetime.now().isoformat()
        }), 200
        
    except Exception as e:
        print(f"Error getting mission status: {e}")
        return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':  
    setup_queues()      
    Thread(target=status_updates_listener, daemon=True).start()
    app.run(host='0.0.0.0', port=5000, debug=False)