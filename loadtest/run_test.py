import argparse
import os
import subprocess
from pathlib import Path

RESULTS_DIR = Path("results")

def available_modules(directory):
    return sorted(f.stem for f in Path(directory).glob("*.py") if f.stem != "__init__")

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--user", required=True, choices=available_modules("users"), help="User module to use")
    parser.add_argument("--workload", required=True, choices=available_modules("workloads"), help="Workload module to use")

    parser.add_argument("--host", required=True, help="Target host for the load test")

    arguments = parser.parse_args()

    output_dir = RESULTS_DIR / f"{arguments.user}_{arguments.workload}"
    output_dir.mkdir(parents=True, exist_ok=True)

    environment = os.environ.copy()
    environment["LOCUST_USER"] = (arguments.user)
    environment["LOCUST_WORKLOAD"] = (arguments.workload)
    subprocess.run( [ "locust", "-f", "locustfile.py", "--headless", "--host", arguments.host, "--csv", str(output_dir), "--csv-full-history", "--only-summary", ], env=environment, check=True, )

if __name__ == "__main__":
    main()