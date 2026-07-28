from ultralytics import YOLO
import numpy as np

_model = None

def _get_model():
    global _model
    if _model is None:
        _model = YOLO("yolov8n.pt")
    return _model

def detect_people(frame: np.ndarray):
    model = _get_model()
    results = model(frame, verbose=False)
    centers = []
    annotated = frame.copy()
    for r in results:
        for box in r.boxes:
            cls = int(box.cls[0])
            if cls != 0:
                continue
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
            centers.append((cx, cy))
            cv2.rectangle(annotated, (x1, y1), (x2, y2), (0, 255, 0), 2)
    return centers, annotated

import cv2
