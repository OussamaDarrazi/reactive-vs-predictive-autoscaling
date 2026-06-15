from locust import HttpUser, task, between, LoadTestShape


class WorkloadUser(HttpUser):

	@task
	def cpu(self):
		self.client.get("/cpu")