# Library Conversion Reference

Mapping tables and before/after code snippets for replacing sync I/O libraries with async equivalents.

---

## http.client / requests → aiohttp

### Import

```python
# Before
import requests
# or
from http.client import HTTPConnection

# After
import aiohttp
```

### Session

```python
# Before
session = requests.Session()
resp = session.get(url)

# After
async with aiohttp.ClientSession() as session:
    async with session.get(url) as resp:
        ...
```

### GET Request

```python
# Before
resp = requests.get(url)
text = resp.text
data = resp.json()

# After
async with aiohttp.ClientSession() as session:
    async with session.get(url) as resp:
        text = await resp.text()
        data = await resp.json()
```

### POST Request

```python
# Before
resp = requests.post(url, data=payload, json=body)

# After
async with aiohttp.ClientSession() as session:
    async with session.post(url, data=payload, json=body) as resp:
        result = await resp.json()
```

### Response Body

| Sync (`requests`) | Async (`aiohttp`) |
|---|---|
| `resp.text` | `await resp.text()` |
| `resp.json()` | `await resp.json()` |
| `resp.content` | `await resp.read()` |
| `resp.status_code` | `resp.status` (no await) |

### HTTPConnection Pattern

```python
# Before
conn = HTTPConnection(host)
conn.request("GET", path)
resp = conn.getresponse()
body = resp.read()

# After
async with aiohttp.ClientSession() as session:
    async with session.get(f"http://{host}{path}") as resp:
        body = await resp.read()
```

---

## pika → aio-pika

### Import

```python
# Before
import pika

# After
import aio_pika
```

### Connect

```python
# Before
connection = pika.BlockingConnection(pika.ConnectionParameters(host=host))

# After
connection = await aio_pika.connect_robust(f"amqp://guest:guest@{host}/")
# or with context manager:
async with await aio_pika.connect_robust(f"amqp://guest:guest@{host}/") as connection:
    ...
```

### Channel

```python
# Before
channel = connection.channel()

# After
channel = await connection.channel()
```

### Declare Queue

```python
# Before
channel.queue_declare(queue='my_queue')

# After
queue = await channel.declare_queue('my_queue', durable=True)
```

### Publish

```python
# Before
channel.basic_publish(
    exchange='',
    routing_key='my_queue',
    body=b'Hello'
)

# After
await channel.default_exchange.publish(
    aio_pika.Message(b'Hello'),
    routing_key='my_queue'
)
```

### Consume

```python
# Before
def callback(ch, method, properties, body):
    process(body)

channel.basic_consume(queue='my_queue', on_message_callback=callback)
channel.start_consuming()

# After
async def callback(message: aio_pika.IncomingMessage):
    async with message.process():
        process(message.body)

await queue.consume(callback)
```

### Close

```python
# Before
connection.close()

# After
await connection.close()
```

### Full Pattern with Context Manager

```python
async with await aio_pika.connect_robust("amqp://guest:guest@localhost/") as connection:
    async with connection.channel() as channel:
        queue = await channel.declare_queue("my_queue", durable=True)
        async with queue.iterator() as queue_iter:
            async for message in queue_iter:
                async with message.process():
                    process(message.body)
```

---

## botocore / boto3 → aiobotocore

### Import

```python
# Before
import boto3
# or
import botocore

# After
from aiobotocore.session import get_session
```

### Session and Client

```python
# Before
session = boto3.Session()
client = boto3.client('s3', region_name='us-east-1')

# After
session = get_session()
async with session.create_client('s3', region_name='us-east-1') as client:
    ...
```

### Method Calls

All service method calls must be awaited:

```python
# Before
response = client.get_object(Bucket='my-bucket', Key='my-key')
body = response['Body'].read()

# After
response = await client.get_object(Bucket='my-bucket', Key='my-key')
body = await response['Body'].read()
```

### Paginators

```python
# Before
paginator = client.get_paginator('list_objects_v2')
for page in paginator.paginate(Bucket='my-bucket'):
    for obj in page['Contents']:
        process(obj)

# After
paginator = client.get_paginator('list_objects_v2')
async for page in paginator.paginate(Bucket='my-bucket'):
    for obj in page['Contents']:
        process(obj)
```

### Common Method Mapping

| Sync (`boto3`) | Async (`aiobotocore`) |
|---|---|
| `client.get_object(...)` | `await client.get_object(...)` |
| `client.put_object(...)` | `await client.put_object(...)` |
| `client.list_objects_v2(...)` | `await client.list_objects_v2(...)` |
| `client.delete_object(...)` | `await client.delete_object(...)` |
| `response['Body'].read()` | `await response['Body'].read()` |

---

## queue.Queue / collections.deque → asyncio.Queue

For inter-coroutine communication, replace thread-safe `queue.Queue` with `asyncio.Queue`.

**Only replace when the queue is used exclusively within async functions. If the queue crosses a thread boundary, flag for manual review.**

### Import

```python
# Before
import queue

# After
import asyncio  # asyncio.Queue is part of asyncio
```

### Type Mapping

| Sync (`queue`) | Async (`asyncio`) |
|---|---|
| `queue.Queue()` | `asyncio.Queue()` |
| `queue.Queue(maxsize=N)` | `asyncio.Queue(maxsize=N)` |
| `queue.LifoQueue()` | `asyncio.LifoQueue()` |
| `queue.PriorityQueue()` | `asyncio.PriorityQueue()` |

### Method Mapping

| Sync | Async | Notes |
|---|---|---|
| `q.put(x)` | `await q.put(x)` | Blocks if full |
| `q.get()` | `await q.get()` | Blocks until item available |
| `q.put_nowait(x)` | `q.put_nowait(x)` | No await; raises `asyncio.QueueFull` |
| `q.get_nowait()` | `q.get_nowait()` | No await; raises `asyncio.QueueEmpty` |
| `q.task_done()` | `q.task_done()` | No await; call after each `get()` |
| `q.join()` | `await q.join()` | Wait until all items processed |
| `q.get(timeout=N)` | `await asyncio.wait_for(q.get(), timeout=N)` | Timeout pattern |
| `q.empty()` | `q.empty()` | No await |
| `q.qsize()` | `q.qsize()` | No await |

### Producer-Consumer Pattern

```python
# Before
import queue
import threading

q = queue.Queue()

def producer():
    for item in generate_items():
        q.put(item)
    q.join()  # wait for all items to be processed

def consumer():
    while True:
        item = q.get()
        process(item)
        q.task_done()

t1 = threading.Thread(target=producer)
t2 = threading.Thread(target=consumer)
t1.start(); t2.start()
t1.join(); t2.join()

# After
import asyncio

async def producer(q: asyncio.Queue):
    for item in generate_items():
        await q.put(item)

async def consumer(q: asyncio.Queue):
    while True:
        item = await q.get()
        process(item)
        q.task_done()

async def main():
    q = asyncio.Queue()
    await asyncio.gather(producer(q), consumer(q))

asyncio.run(main())
```

---

## kafka-python → aiokafka

### Import

```python
# Before
from kafka import KafkaProducer, KafkaConsumer

# After
from aiokafka import AIOKafkaProducer, AIOKafkaConsumer
```

### Producer

```python
# Before
producer = KafkaProducer(bootstrap_servers='localhost:9092')
producer.send('my-topic', value=b'message')
producer.close()

# After — explicit start/stop
producer = AIOKafkaProducer(bootstrap_servers='localhost:9092')
await producer.start()
try:
    await producer.send_and_wait('my-topic', b'message')
finally:
    await producer.stop()

# After — context manager (preferred)
async with AIOKafkaProducer(bootstrap_servers='localhost:9092') as producer:
    await producer.send_and_wait('my-topic', b'message')
```

### Producer Method Mapping

| Sync (`kafka-python`) | Async (`aiokafka`) |
|---|---|
| `KafkaProducer(...)` | `AIOKafkaProducer(...)` |
| *(none — implicit start)* | `await producer.start()` |
| `producer.send(topic, value)` | `await producer.send_and_wait(topic, value)` |
| `producer.flush()` | `await producer.flush()` |
| `producer.close()` | `await producer.stop()` |

### Consumer

```python
# Before
consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers='localhost:9092',
    group_id='my-group'
)
for message in consumer:
    process(message.value)
consumer.close()

# After — explicit start/stop
consumer = AIOKafkaConsumer(
    'my-topic',
    bootstrap_servers='localhost:9092',
    group_id='my-group'
)
await consumer.start()
try:
    async for message in consumer:
        process(message.value)
finally:
    await consumer.stop()

# After — context manager (preferred)
async with AIOKafkaConsumer(
    'my-topic',
    bootstrap_servers='localhost:9092',
    group_id='my-group'
) as consumer:
    async for message in consumer:
        process(message.value)
```

### Consumer Method Mapping

| Sync (`kafka-python`) | Async (`aiokafka`) |
|---|---|
| `KafkaConsumer(...)` | `AIOKafkaConsumer(...)` |
| *(none — implicit start)* | `await consumer.start()` |
| `for msg in consumer:` | `async for msg in consumer:` |
| `consumer.commit()` | `await consumer.commit()` |
| `consumer.close()` | `await consumer.stop()` |
