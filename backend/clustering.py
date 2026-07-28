import numpy as np
from sklearn.cluster import DBSCAN


def find_hotspots(coordinates, eps=80, min_samples=5):
    if len(coordinates) < min_samples:
        return []

    points = np.array(coordinates, dtype=float)
    clustering = DBSCAN(eps=eps, min_samples=min_samples).fit(points)
    labels = clustering.labels_

    hotspots = []
    for label in set(labels):
        if label == -1:
            continue
        mask = labels == label
        cluster_points = points[mask]
        center = cluster_points.mean(axis=0).tolist()
        count = int(mask.sum())
        hotspots.append({
            "center": {"x": round(center[0], 1), "y": round(center[1], 1)},
            "count": count,
        })

    hotspots.sort(key=lambda h: h["count"], reverse=True)
    return hotspots
