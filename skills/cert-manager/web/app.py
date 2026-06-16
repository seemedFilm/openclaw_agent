#!/usr/bin/env python3
"""
Cert-Manager Web-UI
Flask-basiertes Dashboard
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for
import requests
import sys
from pathlib import Path

app = Flask(__name__)

# API Base URL
API_BASE = "http://localhost:5001/api"

# ============================================================================
# Routes
# ============================================================================

@app.route("/")
def index():
    """Dashboard"""
    try:
        # Hole Statistiken
        stats_response = requests.get(f"{API_BASE}/stats")
        stats = stats_response.json() if stats_response.status_code == 200 else {}

        # Hole Zertifikate
        certs_response = requests.get(f"{API_BASE}/certs")
        certificates = certs_response.json().get('certificates', []) if certs_response.status_code == 200 else []

        return render_template('index.html', stats=stats, certificates=certificates)
    except Exception as e:
        return render_template('error.html', error=str(e))

@app.route("/certificates")
def certificates():
    """Zertifikats-Übersicht"""
    try:
        response = requests.get(f"{API_BASE}/certs")
        certs = response.json().get('certificates', []) if response.status_code == 200 else []
        return render_template('certificates.html', certificates=certs)
    except Exception as e:
        return render_template('error.html', error=str(e))

@app.route("/certificates/new", methods=['GET', 'POST'])
def new_certificate():
    """Neues Zertifikat erstellen"""
    if request.method == 'POST':
        try:
            hostname = request.form.get('hostname')
            cert_type = request.form.get('type')
            backend_ip = request.form.get('backend_ip', '').strip()
            auto_renew = request.form.get('auto_renew') == 'on'

            # Automatische Traefik-Integration bei step-ca + Backend-IP
            create_traefik_config = False
            if cert_type == 'step-ca' and backend_ip:
                create_traefik_config = True

            response = requests.post(f"{API_BASE}/certs", json={
                'hostname': hostname,
                'type': cert_type,
                'backend_ip': backend_ip if backend_ip else None,
                'auto_renew': auto_renew,
                'create_traefik_config': create_traefik_config
            })

            if response.status_code == 200:
                result = response.json()

                # Zeige Warnung wenn Traefik-Integration fehlgeschlagen ist
                if result.get('traefik_config_created') == False and 'traefik_error' in result:
                    # Zertifikat wurde erstellt, aber Traefik-Integration fehlgeschlagen
                    warning_msg = f"Zertifikat wurde erstellt, aber Traefik-Integration fehlgeschlagen: {result['traefik_error']}"
                    return render_template('new_certificate.html',
                                         warning=warning_msg,
                                         success_partial=True)

                return redirect(url_for('certificates'))
            else:
                error = response.json().get('detail', 'Unknown error')
                return render_template('new_certificate.html', error=error)

        except Exception as e:
            return render_template('new_certificate.html', error=str(e))

    return render_template('new_certificate.html')

@app.route("/certificates/<hostname>/renew", methods=['POST'])
def renew_certificate(hostname):
    """Zertifikat erneuern"""
    try:
        response = requests.post(f"{API_BASE}/certs/{hostname}/renew")
        return jsonify(response.json())
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route("/certificates/<hostname>/delete", methods=['POST'])
def delete_certificate(hostname):
    """Zertifikat löschen"""
    try:
        response = requests.delete(f"{API_BASE}/certs/{hostname}")
        return jsonify(response.json())
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route("/renewal-jobs")
def renewal_jobs():
    """Renewal-Jobs Übersicht"""
    try:
        response = requests.get(f"{API_BASE}/renewal-jobs")
        jobs = response.json().get('jobs', []) if response.status_code == 200 else []
        return render_template('renewal_jobs.html', jobs=jobs)
    except Exception as e:
        return render_template('error.html', error=str(e))

@app.route("/audit-log")
def audit_log():
    """Audit-Log"""
    try:
        limit = request.args.get('limit', 100, type=int)
        hostname = request.args.get('hostname', None)

        params = {'limit': limit}
        if hostname:
            params['hostname'] = hostname

        response = requests.get(f"{API_BASE}/audit-log", params=params)
        logs = response.json().get('logs', []) if response.status_code == 200 else []

        return render_template('audit_log.html', logs=logs)
    except Exception as e:
        return render_template('error.html', error=str(e))

# ============================================================================
# Run
# ============================================================================

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
