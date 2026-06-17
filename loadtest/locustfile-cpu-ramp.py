from locust import HttpUser, task, constant_throughput

class WorkloadUser(HttpUser):
	wait_time = constant_throughput(1)  # 1 request per second

	@task
	def cpu(self):
		self.client.get("/cpu")