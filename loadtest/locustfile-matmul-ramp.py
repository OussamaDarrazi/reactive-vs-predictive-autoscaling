from locust import HttpUser, task, between, LoadTestShape


class WorkloadUser(HttpUser):

	@task
	def matmul(self):
		self.client.get("/matmul")
