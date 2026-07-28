# Drishti Setu — AI Backend

AI-powered crowd monitoring and emergency response backend for the Pandharpur Wari pilgrimage.

## Quick Start

### 1. Create virtual environment & install dependencies

```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS / Linux
pip install -r requirements.txt
```

### 2. Run the camera worker (live crowd detection demo)

```bash
python camera_worker.py
```

By default this opens webcam `0`. You can pass a video file path or RTSP URL:

```bash
python camera_worker.py video.mp4
python camera_worker.py rtsp://192.168.1.100:554/stream
```

A window titled **"Drishti Setu - Live Crowd Monitor"** will appear showing:
- Green bounding boxes around detected people
- Red circles highlighting crowd hotspots
- Live count overlay

Press `q` to quit.

### 3. Run the API server

```bash
uvicorn main_api:app --reload --host 0.0.0.0 --port 8000
```

Interactive docs available at http://localhost:8000/docs

### 4. Run both simultaneously

Open two terminals:

```bash
# Terminal 1 — camera worker
python camera_worker.py

# Terminal 2 — API server
uvicorn main_api:app --reload --host 0.0.0.0 --port 8000
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/status` | Total person count + active hotspot/alert count |
| GET | `/hotspots` | List of active crowd hotspots |
| POST | `/sos` | Create SOS alert (lat, lng, issue_type, language) |
| GET | `/alerts/active` | All active alerts from last 30 minutes |
| POST | `/volunteer/location` | Update volunteer GPS position |
| GET | `/volunteers/active` | Volunteers with recent location updates |
| POST | `/volunteer/assign` | Assign a volunteer to an alert |

## Architecture

```
camera_worker.py  →  detector.py (YOLOv8)  →  clustering.py (DBSCAN)
       ↓
  SharedStats (thread-safe)
       ↓
main_api.py (FastAPI)  ←  Flutter mobile app
```
