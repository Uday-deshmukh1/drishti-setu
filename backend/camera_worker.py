import sys
import threading
import time

import cv2

from detector import detect_people
from clustering import find_hotspots


class SharedStats:
    def __init__(self):
        self._lock = threading.Lock()
        self.total_count = 0
        self.hotspots = []
        self.frame_count = 0

    def update(self, total_count, hotspots):
        with self._lock:
            self.total_count = total_count
            self.hotspots = hotspots
            self.frame_count += 1

    def snapshot(self):
        with self._lock:
            return {
                "total_count": self.total_count,
                "hotspots": list(self.hotspots),
                "frame_count": self.frame_count,
            }


stats = SharedStats()


def run_worker(source=0):
    cap = cv2.VideoCapture(source)
    if not cap.isOpened():
        print(f"[ERROR] Cannot open video source: {source}")
        return

    print(f"[INFO] Camera worker started. Source: {source}")
    print("[INFO] Press 'q' to quit.")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("[WARN] Frame read failed, retrying...")
            time.sleep(0.5)
            continue

        centers, annotated = detect_people(frame)
        hotspots = find_hotspots(centers)

        stats.update(len(centers), hotspots)

        for hs in hotspots:
            cx, cy = int(hs["center"]["x"]), int(hs["center"]["y"])
            radius = max(40, hs["count"] * 5)
            cv2.circle(annotated, (cx, cy), radius, (0, 0, 255), 3)
            cv2.putText(
                annotated,
                f"Crowd: {hs['count']}",
                (cx - 30, cy - radius - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.7,
                (0, 0, 255),
                2,
            )

        cv2.putText(
            annotated,
            f"People: {len(centers)} | Hotspots: {len(hotspots)}",
            (10, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (255, 255, 0),
            2,
        )

        cv2.imshow("Drishti Setu - Live Crowd Monitor", annotated)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cap.release()
    cv2.destroyAllWindows()
    print("[INFO] Camera worker stopped.")


if __name__ == "__main__":
    source = 0
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        try:
            source = int(arg)
        except ValueError:
            source = arg

    run_worker(source)
