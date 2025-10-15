import pika
import json
import time
import random
from concurrent.futures import ThreadPoolExecutor

REDIS_URL = 'redis'
ORDERS_QUEUE = 'orders_queue'
STATUS_QUEUE = 'status_queue'
RABBITMQ_URL = 'rabbitmq'
RABBITMQ_USER = 'guest'
RABBITMQ_PASSWORD = 'guest'
RABBITMQ_PORT = 5672
TOKEN_ROTATION_INTERVAL = 30
MISSION_MIN_DURATION = 5
MISSION_MAX_DURATION = 15
SUCCESS_RATE = 0.9


executor = ThreadPoolExecutor(max_workers=5)

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


def publish_status(mission_id, mission_status):
    rmq_conn = get_rabbitmq_conn()

    if not rmq_conn:
        return False
    
    try:
        channel = rmq_conn.channel()
        channel.queue_declare(queue=STATUS_QUEUE, durable=True)

        data = {"mission_id":mission_id, "mission_status":mission_status}

        channel.basic_publish(exchange='', routing_key=STATUS_QUEUE, body=json.dumps(data))
        
        rmq_conn.close()
        return True
    

    except Exception as e:
        print(f"Exception {e}")
        return False


def execute_mission(mission):
    mission_id = mission['mission_id']
    mission_data = mission['mission_data']

    publish_status(mission_id, 'IN_PROGRESS')

    try:
        execution_time = random.uniform(MISSION_MIN_DURATION, MISSION_MAX_DURATION)
        print(f"Mission {mission_id} will take {execution_time:.2f} seconds to execute")
        
        time.sleep(execution_time)
        
        success = random.random() < SUCCESS_RATE
        final_status = 'COMPLETED' if success else 'FAILED'
        
        print(f"Mission {mission_id} {final_status.lower()}")
        
        if not publish_status(mission_id, final_status):
            print(f"Failed to publish final status for mission {mission_id}")
        
    except Exception as e:
        print(f"Error executing mission {mission_id}: {e}")
        publish_status(mission_id, 'FAILED')


def check_orders():
    rmq_conn = get_rabbitmq_conn()
    
    try:
        channel = rmq_conn.channel()
        channel.queue_declare(ORDERS_QUEUE, durable=True)

        def callback(ch, method, properties, body):

            message = json.loads(body)
            print(f"Received message from queue: {message}")  

            mission_id = message.get('mission_id')
            mission_data = message.get('mission_data')

            executor.submit(execute_mission, message)

            ch.basic_ack(delivery_tag=method.delivery_tag)
            

        channel.basic_qos(prefetch_count=5)
        channel.basic_consume(queue=ORDERS_QUEUE, on_message_callback=callback)

        channel.start_consuming()

    except Exception as e:
        print(f'{e}')


if __name__ == '__main__':
    check_orders()