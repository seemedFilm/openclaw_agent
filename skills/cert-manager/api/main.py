#!/usr/bin/env python3
"""
Cert-Manager REST API
FastAPI Backend für Web-UI und OpenClaw Integration
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import sys
from pathlib import Path

# Add lib to path
sys.path.append(str(Path(__file__).parent.parent / "lib"))

from certificate_manager import CertificateManager

# FastAPI App
app = FastAPI(
    title="Cert-Manager API",
    description="SSL Certificate Management für OpenClaw",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5000", "https://certs.internal"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Certificate Manager Instance
cert_manager = CertificateManager()

# ============================================================================
# Pydantic Models
# ============================================================================

class CreateCertificateRequest(BaseModel):
    hostname: str
    type: str  # 'step-ca' or 'letsencrypt'
    backend_ip: Optional[str] = None
    auto_renew: bool = True
    create_traefik_config: bool = False

class RenewalJobRequest(BaseModel):
    hostname: str
    renew_days_before: int = 30
    enabled: bool = True

# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/")
async def root():
    """Health Check"""
    return {
        "service": "cert-manager-api",
        "status": "running",
        "version": "1.0.0"
    }

@app.get("/api/certs")
async def list_certificates():
    """Liste alle Zertifikate"""
    try:
        certs = cert_manager.list_certificates()
        return {"certificates": certs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/certs/{hostname}")
async def get_certificate(hostname: str):
    """Hole einzelnes Zertifikat"""
    try:
        cert = cert_manager.get_certificate(hostname)
        if not cert:
            raise HTTPException(status_code=404, detail=f"Zertifikat für {hostname} nicht gefunden")
        return {"certificate": cert}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/certs")
async def create_certificate(req: CreateCertificateRequest):
    """Erstelle neues Zertifikat"""
    try:
        # Validierung
        if req.create_traefik_config and not req.backend_ip:
            raise ValueError("Backend-IP ist erforderlich wenn Traefik-Konfiguration erstellt werden soll")

        cert = cert_manager.create_certificate(
            hostname=req.hostname,
            cert_type=req.type,
            backend_ip=req.backend_ip,
            auto_renew=req.auto_renew,
            create_traefik_config=req.create_traefik_config,
            user="api"
        )
        return {
            "success": True,
            "message": "Certificate created successfully",
            "certificate": cert
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/certs/{hostname}/renew")
async def renew_certificate(hostname: str):
    """Erneuere Zertifikat"""
    try:
        result = cert_manager.renew_certificate(hostname, user="api")
        return {
            "success": True,
            "message": "Certificate renewed successfully",
            "result": result
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/certs/{hostname}")
async def delete_certificate(hostname: str):
    """Lösche Zertifikat"""
    try:
        cert_manager.delete_certificate(hostname, user="api")
        return {
            "success": True,
            "message": f"Certificate for {hostname} deleted successfully"
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/renewal-jobs")
async def list_renewal_jobs():
    """Liste alle Renewal-Jobs"""
    try:
        jobs = cert_manager.list_renewal_jobs()
        return {"jobs": jobs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/audit-log")
async def get_audit_log(limit: int = 100, hostname: Optional[str] = None):
    """Hole Audit-Log"""
    try:
        logs = cert_manager.get_audit_log(limit=limit, hostname=hostname)
        return {"logs": logs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/stats")
async def get_stats():
    """Statistiken"""
    try:
        certs = cert_manager.list_certificates()

        total = len(certs)
        valid = len([c for c in certs if c['status'] == 'valid'])
        expiring = len([c for c in certs if c['days_until_expiry'] < 30 and c['days_until_expiry'] > 0])
        expired = len([c for c in certs if c['days_until_expiry'] <= 0])
        step_ca = len([c for c in certs if c['type'] == 'step-ca'])
        letsencrypt = len([c for c in certs if c['type'] == 'letsencrypt'])

        return {
            "total": total,
            "valid": valid,
            "expiring_soon": expiring,
            "expired": expired,
            "by_type": {
                "step_ca": step_ca,
                "letsencrypt": letsencrypt
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# Run
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5001)
