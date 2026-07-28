import threading
import time
import uuid
from datetime import datetime, timedelta
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Drishti Setu API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# In-memory stores
# ---------------------------------------------------------------------------
_alerts: list[dict] = []
_volunteers: dict[str, dict] = {}
_alerts_lock = threading.Lock()
_volunteers_lock = threading.Lock()


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------
class SOSRequest(BaseModel):
    lat: float
    lng: float
    issue_type: str
    language: str = "en"


class VolunteerLocationRequest(BaseModel):
    volunteer_id: str
    lat: float
    lng: float
    name: str


class AssignRequest(BaseModel):
    alert_id: str
    volunteer_id: str


# ---------------------------------------------------------------------------
# Helper to import camera stats (lazy so API can run without camera)
# ---------------------------------------------------------------------------
def _get_camera_stats():
    try:
        from camera_worker import stats
        return stats.snapshot()
    except Exception:
        return {"total_count": 0, "hotspots": [], "frame_count": 0}


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.get("/status")
def get_status():
    cam = _get_camera_stats()
    with _alerts_lock:
        active_alerts = [a for a in _alerts if a.get("status") != "resolved"]
    return {
        "total_count": cam["total_count"],
        "active_hotspot_count": len(cam["hotspots"]),
        "active_alert_count": len(active_alerts),
    }


@app.get("/hotspots")
def get_hotspots():
    cam = _get_camera_stats()
    return {"hotspots": cam["hotspots"]}


@app.post("/sos")
def create_sos(req: SOSRequest):
    alert = {
        "id": str(uuid.uuid4()),
        "lat": req.lat,
        "lng": req.lng,
        "issue_type": req.issue_type,
        "language": req.language,
        "timestamp": datetime.utcnow().isoformat(),
        "status": "active",
        "assigned_to": None,
    }
    with _alerts_lock:
        _alerts.append(alert)
    return {"success": True, "alert_id": alert["id"]}


@app.get("/alerts/active")
def get_active_alerts():
    cutoff = datetime.utcnow() - timedelta(minutes=30)
    with _alerts_lock:
        recent = [
            a for a in _alerts
            if a.get("status") != "resolved"
            and datetime.fromisoformat(a["timestamp"]) > cutoff
        ]
    return {"alerts": recent}


@app.post("/volunteer/location")
def update_volunteer_location(req: VolunteerLocationRequest):
    with _volunteers_lock:
        _volunteers[req.volunteer_id] = {
            "volunteer_id": req.volunteer_id,
            "name": req.name,
            "lat": req.lat,
            "lng": req.lng,
            "last_update": datetime.utcnow().isoformat(),
        }
    return {"success": True}


@app.get("/volunteers/active")
def get_active_volunteers():
    cutoff = datetime.utcnow() - timedelta(minutes=5)
    with _volunteers_lock:
        active = [
            v for v in _volunteers.values()
            if datetime.fromisoformat(v["last_update"]) > cutoff
        ]
    return {"volunteers": active}


@app.post("/volunteer/assign")
def assign_volunteer(req: AssignRequest):
    with _alerts_lock:
        for a in _alerts:
            if a["id"] == req.alert_id:
                a["assigned_to"] = req.volunteer_id
                a["status"] = "assigned"
                return {"success": True}
    raise HTTPException(status_code=404, detail="Alert not found")
