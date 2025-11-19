#!/usr/bin/env python3
import json
import random
import os
from datetime import datetime, timedelta

# Create test_data directory if it doesn't exist
os.makedirs('test_data', exist_ok=True)

# Sample data for generating random content
names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry", "Iris", "Jack"]
cities = ["New York", "London", "Tokyo", "Paris", "Berlin", "Sydney", "Toronto", "Mumbai", "Seoul", "Dubai"]
products = ["laptop", "phone", "tablet", "monitor", "keyboard", "mouse", "headphones", "camera", "speaker", "charger"]
colors = ["red", "blue", "green", "yellow", "purple", "orange", "pink", "black", "white", "silver"]
status_values = ["active", "inactive", "pending", "completed", "cancelled", "processing"]

def random_date():
    """Generate a random date in ISO format"""
    start = datetime(2020, 1, 1)
    end = datetime(2025, 12, 31)
    delta = end - start
    random_days = random.randint(0, delta.days)
    return (start + timedelta(days=random_days)).isoformat()

def generate_random_json():
    """Generate a random JSON structure"""
    structure_type = random.randint(1, 5)

    if structure_type == 1:
        # User profile structure
        return {
            "id": random.randint(1000, 9999),
            "name": random.choice(names),
            "email": f"{random.choice(names).lower()}{random.randint(1, 999)}@example.com",
            "age": random.randint(18, 80),
            "city": random.choice(cities),
            "active": random.choice([True, False]),
            "score": round(random.uniform(0, 100), 2)
        }
    elif structure_type == 2:
        # Product structure
        return {
            "product_id": f"PROD-{random.randint(10000, 99999)}",
            "name": random.choice(products),
            "price": round(random.uniform(10, 2000), 2),
            "color": random.choice(colors),
            "in_stock": random.choice([True, False]),
            "quantity": random.randint(0, 500),
            "category": random.choice(["electronics", "accessories", "computers", "audio"])
        }
    elif structure_type == 3:
        # Transaction structure
        return {
            "transaction_id": f"TXN-{random.randint(100000, 999999)}",
            "user_id": random.randint(1000, 9999),
            "amount": round(random.uniform(1, 10000), 2),
            "currency": random.choice(["USD", "EUR", "GBP", "JPY"]),
            "status": random.choice(status_values),
            "timestamp": random_date()
        }
    elif structure_type == 4:
        # Event structure
        return {
            "event_id": random.randint(1, 99999),
            "event_type": random.choice(["login", "logout", "purchase", "view", "click", "search"]),
            "user": random.choice(names),
            "location": random.choice(cities),
            "timestamp": random_date(),
            "metadata": {
                "browser": random.choice(["Chrome", "Firefox", "Safari", "Edge"]),
                "device": random.choice(["desktop", "mobile", "tablet"])
            }
        }
    else:
        # Nested structure
        return {
            "department": random.choice(["Engineering", "Sales", "Marketing", "HR", "Finance"]),
            "data": {
                "employees": random.randint(5, 100),
                "budget": round(random.uniform(50000, 5000000), 2),
                "projects": [
                    {
                        "name": f"Project-{random.randint(1, 100)}",
                        "status": random.choice(status_values),
                        "priority": random.choice(["low", "medium", "high", "critical"])
                    } for _ in range(random.randint(1, 5))
                ]
            },
            "last_updated": random_date()
        }

def add_golden_value(data):
    """Add 'golden' string somewhere in the JSON structure"""
    modification_type = random.randint(1, 4)

    if modification_type == 1:
        # Add as a new field
        data["treasure"] = "golden"
    elif modification_type == 2:
        # Replace a random string value
        for key in data.keys():
            if isinstance(data[key], str):
                data[key] = "golden"
                break
    elif modification_type == 3:
        # Add in nested structure if exists
        for key in data.keys():
            if isinstance(data[key], dict):
                data[key]["special"] = "golden"
                return data
        data["special"] = "golden"
    else:
        # Add as a list item
        data["tags"] = ["special", "golden", "rare"]

    return data

# Generate 100 files
golden_file_index = random.randint(0, 99)

for i in range(100):
    data = generate_random_json()

    # Add "golden" to the randomly selected file
    if i == golden_file_index:
        data = add_golden_value(data)

    filename = f"test_data/test_file_{i:03d}.json"
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)

print(f"✓ Generated 100 test JSON files in 'test_data/' directory")
print(f"✓ The string 'golden' is hidden in: test_file_{golden_file_index:03d}.json")
