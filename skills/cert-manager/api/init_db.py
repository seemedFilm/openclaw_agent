#!/usr/bin/env python3
"""
Datenbank-Initialisierung für Cert-Manager
"""

import sqlite3
import os
from pathlib import Path

# Pfade
BASE_DIR = Path(__file__).parent.parent
DB_PATH = BASE_DIR / "data" / "cert_manager.db"

# Erstelle data-Verzeichnis
DB_PATH.parent.mkdir(parents=True, exist_ok=True)

def init_database():
    """Initialisiere SQLite-Datenbank mit allen Tabellen"""

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Tabelle: certificates
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS certificates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hostname TEXT UNIQUE NOT NULL,
            type TEXT NOT NULL,
            backend_ip TEXT,
            cert_path TEXT,
            key_path TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NOT NULL,
            auto_renew BOOLEAN DEFAULT 1,
            last_renewed_at TIMESTAMP,
            status TEXT DEFAULT 'valid'
        )
    """)

    # Index für schnellere Queries
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_hostname ON certificates(hostname)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_expires_at ON certificates(expires_at)
    """)

    # Tabelle: renewal_jobs
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS renewal_jobs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hostname TEXT NOT NULL,
            enabled BOOLEAN DEFAULT 1,
            renew_days_before INTEGER DEFAULT 30,
            last_run TIMESTAMP,
            next_run TIMESTAMP,
            status TEXT,
            error_message TEXT,
            FOREIGN KEY (hostname) REFERENCES certificates(hostname) ON DELETE CASCADE
        )
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_renewal_hostname ON renewal_jobs(hostname)
    """)

    # Tabelle: audit_log
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            action TEXT NOT NULL,
            hostname TEXT NOT NULL,
            user TEXT,
            status TEXT NOT NULL,
            message TEXT,
            details TEXT
        )
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp DESC)
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_audit_hostname ON audit_log(hostname)
    """)

    # Migration: Füge backend_ip Spalte hinzu wenn nicht existiert
    try:
        cursor.execute("ALTER TABLE certificates ADD COLUMN backend_ip TEXT")
        print("   Migration: backend_ip Spalte hinzugefügt")
    except sqlite3.OperationalError:
        pass  # Spalte existiert bereits

    conn.commit()
    conn.close()

    print(f"✅ Datenbank erfolgreich initialisiert: {DB_PATH}")
    print(f"   Tabellen: certificates, renewal_jobs, audit_log")

if __name__ == "__main__":
    init_database()
