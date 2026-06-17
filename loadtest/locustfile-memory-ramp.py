from locust import HttpUser, task, constant_throughput


class WorkloadUser(HttpUser):
	wait_time = constant_throughput(1)

	@task
	def memory(self):
		self.client.get("/memory")
