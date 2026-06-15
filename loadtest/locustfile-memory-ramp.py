from locust import HttpUser, task, between, LoadTestShape


class WorkloadUser(HttpUser):

	@task
	def memory(self):
		self.client.get("/memory")
