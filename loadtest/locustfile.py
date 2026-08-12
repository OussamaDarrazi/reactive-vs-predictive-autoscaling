import importlib
import os
USER_MODULE = os.environ["LOCUST_USER"]
WORKLOAD_MODULE = os.environ["LOCUST_WORKLOAD"]

user_module = importlib.import_module(f"users.{USER_MODULE}")
workload_module = importlib.import_module(f"workloads.{WORKLOAD_MODULE}")

globals().update(user_module.__dict__)
globals().update(workload_module.__dict__)