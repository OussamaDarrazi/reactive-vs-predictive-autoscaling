from .config import *
from locust import LoadTestShape
import math

class CyclicalStable(LoadTestShape):

    def tick(self):
        elapsed = self.get_run_time()

        if elapsed >= EXPERIMENT_DURATION:
            return None

        target_rps = self.get_target_rps(elapsed)

        return (
            self.rps_to_users(target_rps),
            self.spawn_rate,
        )

    @property
    def spawn_rate(self):
        return SPAWN_RATE

    @staticmethod
    def rps_to_users(target_rps):
        """
        Converts target RPS into VUs.

        This assumes approximately one VU generates one RPS.
        """
        return max(1, math.ceil(target_rps))
    
    def get_target_rps(self, elapsed):
        """
        Each 15-minute cycle moves gradually through:

            0.5S > 1.5S > 2.5S > 3.5S
            > 2.5S > 1.5S > 0.5S

        The transitions are smooth rather than abrupt.
        """

        phase = (elapsed % CYCLE_TIME) / CYCLE_TIME

        # Triangular wave between 0 and 1.
        triangle = 1 - abs(2 * phase - 1)

        return MIN_RPS + triangle * (
            MAX_RPS - MIN_RPS
        )
