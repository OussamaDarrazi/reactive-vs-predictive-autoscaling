from locust import HttpUser, task, constant_throughput

class CpuWorkloadUser(HttpUser):
	wait_time = constant_throughput(1)

	@task
	def cpu(self):
		self.client.get("/cpu")