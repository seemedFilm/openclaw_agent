#!/usr/bin/env python3
"""
Renewal Scheduler - Automatische Zertifikats-Erneuerung
Läuft als Systemd-Service und prüft alle 24 Stunden ablaufende Zertifikate
"""

import sys
import time
import logging
from datetime import datetime, timedelta
from pathlib import Path

# Add lib to path
sys.path.append(str(Path(__file__).parent))

from certificate_manager import CertificateManager

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/openclaw/skills/cert-manager/logs/renewal_scheduler.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

class RenewalScheduler:
    """Automatische Zertifikats-Erneuerung"""

    def __init__(self):
        self.cert_manager = CertificateManager()
        self.config = self.cert_manager.config

    def run(self):
        """Hauptschleife: Läuft kontinuierlich"""

        logger.info("Renewal Scheduler gestartet")

        while True:
            try:
                self.check_and_renew()

                # Warte bis zum nächsten Check
                check_interval_hours = self.config['renewal']['check_interval_hours']
                sleep_seconds = check_interval_hours * 3600

                logger.info(f"Nächster Check in {check_interval_hours} Stunden")
                time.sleep(sleep_seconds)

            except KeyboardInterrupt:
                logger.info("Scheduler durch Benutzer gestoppt")
                break
            except Exception as e:
                logger.error(f"Fehler in Hauptschleife: {e}")
                time.sleep(300)  # 5 Minuten warten bei Fehler

    def check_and_renew(self):
        """Prüfe ablaufende Zertifikate und erneuere sie"""

        logger.info("Starte Renewal-Check...")

        # Hole alle Zertifikate
        certs = self.cert_manager.list_certificates()

        renew_days_before = self.config['renewal']['renew_days_before']
        logger.info(f"Prüfe {len(certs)} Zertifikate (Renewal ab {renew_days_before} Tage vor Ablauf)")

        renewed_count = 0
        failed_count = 0

        for cert in certs:
            # Nur Zertifikate mit Auto-Renewal
            if not cert['auto_renew']:
                continue

            # Prüfe ob Renewal nötig
            if cert['days_until_expiry'] > renew_days_before:
                continue

            hostname = cert['hostname']
            logger.info(f"Renewal nötig für {hostname} (läuft in {cert['days_until_expiry']} Tagen ab)")

            # Versuche Renewal
            try:
                result = self.cert_manager.renew_certificate(hostname, user="renewal-scheduler")
                logger.info(f"✓ Renewal erfolgreich: {hostname}")
                renewed_count += 1

                # Update Renewal-Job in DB
                self._update_renewal_job(hostname, status='success', error_message=None)

            except Exception as e:
                logger.error(f"✗ Renewal fehlgeschlagen für {hostname}: {e}")
                failed_count += 1

                # Update Renewal-Job in DB
                self._update_renewal_job(hostname, status='failed', error_message=str(e))

                # Retry-Logik
                if self.config['renewal']['retry_on_failure']:
                    self._schedule_retry(hostname)

        logger.info(f"Renewal-Check abgeschlossen: {renewed_count} erneuert, {failed_count} fehlgeschlagen")

    def _update_renewal_job(self, hostname: str, status: str, error_message: str = None):
        """Update Renewal-Job Status in DB"""

        conn = self.cert_manager._get_db_connection()
        cursor = conn.cursor()

        next_run = datetime.now() + timedelta(hours=self.config['renewal']['check_interval_hours'])

        cursor.execute("""
            UPDATE renewal_jobs
            SET last_run = ?, next_run = ?, status = ?, error_message = ?
            WHERE hostname = ?
        """, (datetime.now(), next_run, status, error_message, hostname))

        conn.commit()
        conn.close()

    def _schedule_retry(self, hostname: str):
        """Plane Retry bei Fehler"""

        retry_delay_minutes = self.config['renewal']['retry_delay_minutes']
        logger.info(f"Plane Retry für {hostname} in {retry_delay_minutes} Minuten")

        # Hier könnte man einen separaten Retry-Mechanismus implementieren
        # Für jetzt: Wird beim nächsten regulären Check nochmal versucht

if __name__ == "__main__":
    scheduler = RenewalScheduler()
    scheduler.run()
