from .config import *
from locust import LoadTestShape
import math

class CyclicalBursty(LoadTestShape):

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
        Each cycle contains short, distinct bursts at the
        four scaling levels.

        The system is given a plateau at each level so that
        the autoscaler has time to react.
        """

        phase = (elapsed % CYCLE_TIME) / CYCLE_TIME

        level = int(phase * 7)

        level = min(level, 6)

        return (
            MIN_RPS,
            LOAD_LEVELS[1],
            LOAD_LEVELS[2],
            LOAD_LEVELS[3],
            LOAD_LEVELS[2],
            LOAD_LEVELS[1],
            MIN_RPS,
        )[level]
