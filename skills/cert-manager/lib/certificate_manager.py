#!/usr/bin/env python3
"""
Certificate Manager - Core Business Logic
"""

import subprocess
import paramiko
import sqlite3
import json
import yaml
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Pfade
BASE_DIR = Path(__file__).parent.parent
CONFIG_PATH = BASE_DIR / "config" / "settings.yaml"
DB_PATH = BASE_DIR / "data" / "cert_manager.db"

class CertificateManager:
    """Verwaltet SSL-Zertifikate für step-ca und Let's Encrypt"""

    def __init__(self):
        self.config = self._load_config()
        self.db_path = DB_PATH

    def _load_config(self) -> Dict:
        """Lade Konfiguration"""
        with open(CONFIG_PATH, 'r') as f:
            return yaml.safe_load(f)

    def _get_db_connection(self) -> sqlite3.Connection:
        """Erstelle DB-Connection"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _log_audit(self, action: str, hostname: str, user: str,
                   status: str, message: str, details: Optional[Dict] = None):
        """Schreibe Audit-Log"""
        conn = self._get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO audit_log (action, hostname, user, status, message, details)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (action, hostname, user, status, message,
              json.dumps(details) if details else None))

        conn.commit()
        conn.close()

    def _ssh_execute(self, host: str, user: str, key_path: str, command: str, need_pty: bool = False) -> Tuple[str, str, int]:
        """Führe SSH-Befehl aus via subprocess (zuverlässiger als paramiko)"""
        import re

        # Verwende subprocess mit ssh command statt paramiko
        # Grund: paramiko hat Probleme mit Key-Formaten und Permissions
        ssh_command = [
            'ssh',
            '-i', key_path,
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'BatchMode=yes',
            '-T',  # Disable PTY allocation
            f'{user}@{host}',
            command
        ]

        try:
            result = subprocess.run(
                ssh_command,
                stdin=subprocess.PIPE,
                capture_output=True,
                text=True,
                timeout=60
            )

            stdout_text = result.stdout
            stderr_text = result.stderr
            exit_code = result.returncode

            # Entferne ANSI-Color-Codes
            ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
            stdout_text = ansi_escape.sub('', stdout_text)
            stderr_text = ansi_escape.sub('', stderr_text)

            # Filtere SSH-Warnings aus stderr
            stderr_lines = stderr_text.split('\n')
            filtered_stderr = []
            for line in stderr_lines:
                if not any(warning in line for warning in [
                    'Warning: Permanently added',
                    'Warning: Identity file',
                    'Pseudo-terminal will not be allocated'
                ]):
                    filtered_stderr.append(line)
            stderr_text = '\n'.join(filtered_stderr).strip()

            return stdout_text, stderr_text, exit_code

        except subprocess.TimeoutExpired:
            raise Exception(f"SSH-Command timeout nach 60s")
        except FileNotFoundError:
            raise Exception(f"SSH-Key nicht gefunden: {key_path}")
        except Exception as e:
            raise Exception(f"SSH-Verbindung fehlgeschlagen: {str(e)}")

    def create_certificate(self, hostname: str, cert_type: str,
                          backend_ip: Optional[str] = None,
                          auto_renew: bool = True,
                          create_traefik_config: bool = False,
                          user: str = "web-ui") -> Dict:
        """
        Erstelle neues Zertifikat

        Args:
            hostname: Hostname (z.B. myapp.internal)
            cert_type: 'step-ca' oder 'letsencrypt'
            backend_ip: Backend-IP für Traefik (optional, z.B. https://192.168.1.50:8080)
            auto_renew: Auto-Renewal aktivieren
            create_traefik_config: Traefik-Konfiguration automatisch erstellen
            user: User der die Aktion ausführt

        Returns:
            Dict mit Zertifikats-Informationen
        """

        # Validierung
        if not hostname:
            raise ValueError("Hostname darf nicht leer sein")

        if cert_type not in ['step-ca', 'letsencrypt']:
            raise ValueError("cert_type muss 'step-ca' oder 'letsencrypt' sein")

        # Automatische Traefik-Integration bei step-ca + Backend-IP
        if cert_type == 'step-ca' and backend_ip and not create_traefik_config:
            create_traefik_config = True

        if create_traefik_config and not backend_ip:
            raise ValueError("Backend-IP ist erforderlich wenn Traefik-Konfiguration erstellt werden soll")

        # Prüfe ob bereits existiert
        conn = self._get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT hostname FROM certificates WHERE hostname = ?", (hostname,))
        if cursor.fetchone():
            conn.close()
            raise ValueError(f"Zertifikat für {hostname} existiert bereits")
        conn.close()

        try:
            if cert_type == 'step-ca':
                result = self._create_step_ca_cert(hostname, backend_ip, auto_renew, user)
            else:
                result = self._create_letsencrypt_cert(hostname, backend_ip, auto_renew, user)

            # Traefik-Konfiguration erstellen wenn gewünscht
            if create_traefik_config and backend_ip:
                try:
                    self._create_traefik_service(hostname, backend_ip, user)
                    result['traefik_config_created'] = True
                    result['traefik_url'] = f"https://{hostname}"

                    # Pi-hole DNS-Eintrag erstellen (nach erfolgreicher Traefik-Config)
                    try:
                        self._add_pihole_dns(hostname, user)
                        result['pihole_dns_created'] = True
                    except Exception as pihole_error:
                        # Traefik funktioniert, aber DNS-Eintrag fehlgeschlagen
                        result['pihole_dns_created'] = False
                        result['pihole_error'] = str(pihole_error)
                        self._log_audit(
                            action="add_pihole_dns",
                            hostname=hostname,
                            user=user,
                            status="warning",
                            message=f"Traefik-Config erstellt, aber Pi-hole DNS fehlgeschlagen: {str(pihole_error)}",
                            details={"hostname": hostname}
                        )

                except Exception as traefik_error:
                    # Zertifikat wurde erstellt, aber Traefik-Integration fehlgeschlagen
                    result['traefik_config_created'] = False
                    result['traefik_error'] = str(traefik_error)
                    self._log_audit(
                        action="create_traefik_service",
                        hostname=hostname,
                        user=user,
                        status="warning",
                        message=f"Zertifikat erstellt, aber Traefik-Integration fehlgeschlagen: {str(traefik_error)}",
                        details={"backend_ip": backend_ip}
                    )

            return result

        except Exception as e:
            self._log_audit(
                action="create_certificate",
                hostname=hostname,
                user=user,
                status="failed",
                message=str(e),
                details={"type": cert_type}
            )
            raise

    def _create_step_ca_cert(self, hostname: str, backend_ip: Optional[str], auto_renew: bool, user: str) -> Dict:
        """Erstelle step-ca Zertifikat"""

        step_ca_config = self.config['certificate']['step_ca']

        # Hostname-Teil extrahieren (ohne .internal)
        hostname_short = hostname.replace('.internal', '')

        # SSH zu step-ca Server
        command = f"{step_ca_config['script_path']} {hostname_short}"

        stdout, stderr, exit_code = self._ssh_execute(
            host=step_ca_config['host'],
            user=step_ca_config['user'],
            key_path=step_ca_config['ssh_key'],
            command=command,
            need_pty=True  # step-ca benötigt PTY
        )

        if exit_code != 0:
            raise Exception(f"Zertifikatserstellung fehlgeschlagen: {stderr}")

        # Verifiziere Zertifikat
        cert_dir = f"{step_ca_config['output_path']}/{hostname_short}"
        verify_command = f"ls -la {cert_dir}/*.crt {cert_dir}/*.key"

        stdout, stderr, exit_code = self._ssh_execute(
            host=step_ca_config['host'],
            user=step_ca_config['user'],
            key_path=step_ca_config['ssh_key'],
            command=verify_command
        )

        if exit_code != 0:
            raise Exception(f"Zertifikat nicht gefunden in {cert_dir}")

        # Zertifikat in DB speichern
        cert_path = f"{cert_dir}/fullchain.crt"
        key_path = f"{cert_dir}/{hostname_short}.key"
        expires_at = datetime.now() + timedelta(days=step_ca_config['default_validity_days'])

        conn = self._get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO certificates (hostname, type, backend_ip, cert_path, key_path, expires_at, auto_renew, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (hostname, 'step-ca', backend_ip, cert_path, key_path, expires_at, auto_renew, 'valid'))

        conn.commit()

        # Renewal-Job erstellen
        if auto_renew:
            renew_days_before = self.config['renewal']['renew_days_before']
            next_run = datetime.now() + timedelta(days=1)  # Erster Check morgen

            cursor.execute("""
                INSERT INTO renewal_jobs (hostname, enabled, renew_days_before, next_run, status)
                VALUES (?, ?, ?, ?, ?)
            """, (hostname, True, renew_days_before, next_run, 'pending'))

            conn.commit()

        conn.close()

        # Audit-Log
        self._log_audit(
            action="create_certificate",
            hostname=hostname,
            user=user,
            status="success",
            message=f"step-ca Zertifikat erfolgreich erstellt",
            details={
                "type": "step-ca",
                "cert_path": cert_path,
                "key_path": key_path,
                "expires_at": expires_at.isoformat(),
                "auto_renew": auto_renew
            }
        )

        return {
            "hostname": hostname,
            "type": "step-ca",
            "backend_ip": backend_ip,
            "cert_path": cert_path,
            "key_path": key_path,
            "expires_at": expires_at.isoformat(),
            "auto_renew": auto_renew,
            "status": "valid"
        }

    def _create_letsencrypt_cert(self, hostname: str, backend_ip: Optional[str], auto_renew: bool, user: str) -> Dict:
        """
        Registriere Let's Encrypt Zertifikat
        (Wird durch Traefik erstellt beim ersten HTTPS-Zugriff)
        """

        # Für Let's Encrypt: Nur DB-Eintrag, Traefik macht den Rest
        expires_at = datetime.now() + timedelta(days=90)  # Let's Encrypt Standard

        conn = self._get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO certificates (hostname, type, backend_ip, cert_path, key_path, expires_at, auto_renew, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (hostname, 'letsencrypt', backend_ip, None, None, expires_at, auto_renew, 'pending'))

        conn.commit()

        # Renewal-Job erstellen
        if auto_renew:
            renew_days_before = self.config['renewal']['renew_days_before']
            next_run = datetime.now() + timedelta(days=1)

            cursor.execute("""
                INSERT INTO renewal_jobs (hostname, enabled, renew_days_before, next_run, status)
                VALUES (?, ?, ?, ?, ?)
            """, (hostname, True, renew_days_before, next_run, 'pending'))

            conn.commit()

        conn.close()

        # Audit-Log
        self._log_audit(
            action="create_certificate",
            hostname=hostname,
            user=user,
            status="success",
            message=f"Let's Encrypt Zertifikat registriert (wird durch Traefik erstellt)",
            details={
                "type": "letsencrypt",
                "expires_at": expires_at.isoformat(),
                "auto_renew": auto_renew
            }
        )

        return {
            "hostname": hostname,
            "type": "letsencrypt",
            "backend_ip": backend_ip,
            "cert_path": "managed_by_traefik",
            "key_path": "managed_by_traefik",
            "expires_at": expires_at.isoformat(),
            "auto_renew": auto_renew,
            "status": "pending"
        }

    def list_certificates(self) -> List[Dict]:
        """Liste alle Zertifikate"""
        conn = self._get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT hostname, type, backend_ip, cert_path, key_path, created_at,
                   expires_at, auto_renew, last_renewed_at, status
            FROM certificates
            ORDER BY expires_at ASC
        """)

        certs = []
        for row in cursor.fetchall():
            expires_at = datetime.fromisoformat(row['expires_at'])
            days_until_expiry = (expires_at - datetime.now()).days

            certs.append({
                "hostname": row['hostname'],
                "type": row['type'],
                "backend_ip": row['backend_ip'],
                "cert_path": row['cert_path'],
                "key_path": row['key_path'],
                "created_at": row['created_at'],
                "expires_at": row['expires_at'],
                "days_until_expiry": days_until_expiry,
                "auto_renew": bool(row['auto_renew']),
                "last_renewed_at": row['last_renewed_at'],
                "status": row['status']
            })

        conn.close()
        return certs

    def get_certificate(self, hostname: str) -> Optional[Dict]:
        """Hole einzelnes Zertifikat"""
        conn = self._get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT hostname, type, backend_ip, cert_path, key_path, created_at,
                   expires_at, auto_renew, last_renewed_at, status
            FROM certificates
            WHERE hostname = ?
        """, (hostname,))

        row = cursor.fetchone()
        conn.close()

        if not row:
            return None

        expires_at = datetime.fromisoformat(row['expires_at'])
        days_until_expiry = (expires_at - datetime.now()).days

        return {
            "hostname": row['hostname'],
            "type": row['type'],
            "backend_ip": row['backend_ip'],
            "cert_path": row['cert_path'],
            "key_path": row['key_path'],
            "created_at": row['created_at'],
            "expires_at": row['expires_at'],
            "days_until_expiry": days_until_expiry,
            "auto_renew": bool(row['auto_renew']),
            "last_renewed_at": row['last_renewed_at'],
            "status": row['status']
        }

    def renew_certificate(self, hostname: str, user: str = "manual") -> Dict:
        """Erneuere Zertifikat"""

        cert = self.get_certificate(hostname)
        if not cert:
            raise ValueError(f"Zertifikat für {hostname} nicht gefunden")

        try:
            if cert['type'] == 'step-ca':
                return self._renew_step_ca_cert(hostname, user)
            else:
                return self._renew_letsencrypt_cert(hostname, user)

        except Exception as e:
            self._log_audit(
                action="renew_certificate",
                hostname=hostname,
                user=user,
                status="failed",
                message=str(e)
            )
            raise

    def _renew_step_ca_cert(self, hostname: str, user: str) -> Dict:
        """Erneuere step-ca Zertifikat"""

        # Gleicher Prozess wie create
        step_ca_config = self.config['certificate']['step_ca']
        hostname_short = hostname.replace('.internal', '')

        command = f"{step_ca_config['script_path']} {hostname_short}"

        stdout, stderr, exit_code = self._ssh_execute(
            host=step_ca_config['host'],
            user=step_ca_config['user'],
            key_path=step_ca_config['ssh_key'],
            command=command,
            need_pty=True  # step-ca benötigt PTY
        )

        if exit_code != 0:
            raise Exception(f"Renewal fehlgeschlagen: {stderr}")

        # Update DB
        expires_at = datetime.now() + timedelta(days=step_ca_config['default_validity_days'])

        conn = self._get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            UPDATE certificates
            SET expires_at = ?, last_renewed_at = ?, status = 'valid'
            WHERE hostname = ?
        """, (expires_at, datetime.now(), hostname))

        conn.commit()
        conn.close()

        # Audit-Log
        self._log_audit(
            action="renew_certificate",
            hostname=hostname,
            user=user,
            status="success",
            message="Zertifikat erfolgreich erneuert",
            details={"new_expires_at": expires_at.isoformat()}
        )

        return {
            "hostname": hostname,
            "renewed_at": datetime.now().isoformat(),
            "expires_at": expires_at.isoformat()
        }

    def _renew_letsencrypt_cert(self, hostname: str, user: str) -> Dict:
        """Erneuere Let's Encrypt (via Traefik)"""

        # Traefik erneuert automatisch, wir aktualisieren nur DB
        expires_at = datetime.now() + timedelta(days=90)

        conn = self._get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            UPDATE certificates
            SET expires_at = ?, last_renewed_at = ?, status = 'valid'
            WHERE hostname = ?
        """, (expires_at, datetime.now(), hostname))

        conn.commit()
        conn.close()

        self._log_audit(
            action="renew_certificate",
            hostname=hostname,
            user=user,
            status="success",
            message="Let's Encrypt Renewal-Datum aktualisiert",
            details={"new_expires_at": expires_at.isoformat()}
        )

        return {
            "hostname": hostname,
            "renewed_at": datetime.now().isoformat(),
            "expires_at": expires_at.isoformat()
        }

    def _delete_step_ca_files(self, hostname: str):
        """Lösche Zertifikatsdateien vom step-ca Server"""
        step_ca_config = self.config['certificate']['step_ca']
        hostname_short = hostname.replace('.internal', '')

        # Verzeichnis auf dem step-ca Server löschen
        cert_dir = f"{step_ca_config['output_path']}/{hostname_short}"
        command = f"rm -rf {cert_dir}"

        stdout, stderr, exit_code = self._ssh_execute(
            host=step_ca_config['host'],
            user=step_ca_config['user'],
            key_path=step_ca_config['ssh_key'],
            command=command
        )

        if exit_code != 0:
            raise Exception(f"Dateien konnten nicht gelöscht werden: {stderr}")

    def _restart_traefik(self):
        """Starte Traefik Container neu"""
        traefik_config = self.config.get('traefik', {})

        if not traefik_config:
            # Fallback auf Standardwerte wenn nicht in config
            traefik_host = "192.168.1.23"
            traefik_user = "root"
            traefik_ssh_key = self.config['certificate']['step_ca']['ssh_key']
            traefik_container = "traefik"
        else:
            traefik_host = traefik_config['host']
            traefik_user = traefik_config['user']
            traefik_ssh_key = traefik_config['ssh_key']
            traefik_container = traefik_config.get('container_name', 'traefik')

        command = f"docker restart {traefik_container}"

        stdout, stderr, exit_code = self._ssh_execute(
            host=traefik_host,
            user=traefik_user,
            key_path=traefik_ssh_key,
            command=command
        )

        if exit_code != 0:
            raise Exception(f"Traefik-Neustart fehlgeschlagen: {stderr}")

    def delete_certificate(self, hostname: str, user: str = "web-ui") -> bool:
        """Lösche Zertifikat"""

        conn = self._get_db_connection()
        cursor = conn.cursor()

        # Prüfe ob existiert und ob Traefik-Integration vorhanden
        cursor.execute("SELECT type, cert_path, backend_ip FROM certificates WHERE hostname = ?", (hostname,))
        row = cursor.fetchone()

        if not row:
            conn.close()
            raise ValueError(f"Zertifikat für {hostname} nicht gefunden")

        cert_type = row['type']
        cert_path = row['cert_path']
        had_traefik_config = row['backend_ip'] is not None

        # Lösche physische Zertifikatsdateien bei step-ca
        deletion_errors = []
        if cert_type == 'step-ca' and cert_path:
            try:
                self._delete_step_ca_files(hostname)
            except Exception as e:
                deletion_errors.append(f"Dateien konnten nicht gelöscht werden: {str(e)}")

        # Entferne Pi-hole DNS-Eintrag falls Traefik-Integration vorhanden war
        if had_traefik_config:
            try:
                self._remove_pihole_dns(hostname, user)
            except Exception as e:
                deletion_errors.append(f"Pi-hole DNS-Eintrag konnte nicht entfernt werden: {str(e)}")
                # Nicht abbrechen, andere Cleanup-Schritte fortsetzen

        # Lösche aus DB
        cursor.execute("DELETE FROM certificates WHERE hostname = ?", (hostname,))
        cursor.execute("DELETE FROM renewal_jobs WHERE hostname = ?", (hostname,))

        conn.commit()
        conn.close()

        # Starte Traefik neu um Zertifikatsänderungen zu laden
        try:
            self._restart_traefik()
        except Exception as e:
            deletion_errors.append(f"Traefik-Neustart fehlgeschlagen: {str(e)}")

        # Audit-Log
        status = "success" if not deletion_errors else "partial_success"
        message = f"Zertifikat ({cert_type}) gelöscht"
        if deletion_errors:
            message += f" (Warnungen: {', '.join(deletion_errors)})"

        self._log_audit(
            action="delete_certificate",
            hostname=hostname,
            user=user,
            status=status,
            message=message,
            details={
                "cert_type": cert_type,
                "cert_path": cert_path,
                "errors": deletion_errors if deletion_errors else None
            }
        )

        return True

    def list_renewal_jobs(self) -> List[Dict]:
        """Liste alle Renewal-Jobs"""
        conn = self._get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT id, hostname, enabled, renew_days_before, last_run, next_run, status, error_message
            FROM renewal_jobs
            ORDER BY next_run ASC
        """)

        jobs = []
        for row in cursor.fetchall():
            jobs.append({
                "id": row['id'],
                "hostname": row['hostname'],
                "enabled": bool(row['enabled']),
                "renew_days_before": row['renew_days_before'],
                "last_run": row['last_run'],
                "next_run": row['next_run'],
                "status": row['status'],
                "error_message": row['error_message']
            })

        conn.close()
        return jobs

    def get_audit_log(self, limit: int = 100, hostname: Optional[str] = None) -> List[Dict]:
        """Hole Audit-Log"""
        conn = self._get_db_connection()
        cursor = conn.cursor()

        if hostname:
            cursor.execute("""
                SELECT timestamp, action, hostname, user, status, message, details
                FROM audit_log
                WHERE hostname = ?
                ORDER BY timestamp DESC
                LIMIT ?
            """, (hostname, limit))
        else:
            cursor.execute("""
                SELECT timestamp, action, hostname, user, status, message, details
                FROM audit_log
                ORDER BY timestamp DESC
                LIMIT ?
            """, (limit,))

        logs = []
        for row in cursor.fetchall():
            logs.append({
                "timestamp": row['timestamp'],
                "action": row['action'],
                "hostname": row['hostname'],
                "user": row['user'],
                "status": row['status'],
                "message": row['message'],
                "details": json.loads(row['details']) if row['details'] else None
            })

        conn.close()
        return logs

    def _create_traefik_service(self, hostname: str, backend_ip: str, user: str):
        """
        Erstelle Traefik-Config direkt (Zertifikat wurde bereits von cert-manager erstellt)

        Args:
            hostname: Service-Hostname
            backend_ip: Backend-Server URL (z.B. https://192.168.1.50:8080)
            user: User der die Aktion ausführt
        """
        traefik_config = self.config.get('traefik', {})

        if not traefik_config:
            raise Exception("Traefik-Konfiguration fehlt in settings.yaml")

        traefik_host = traefik_config['host']
        traefik_user = traefik_config['user']
        traefik_ssh_key = traefik_config['ssh_key']
        traefik_config_path = traefik_config.get('config_path', '/docker/volume/traefik/dynamic')

        # Bestimme Zertifikats-Pfade (wurden bereits von step-ca erstellt)
        hostname_short = hostname.replace('.internal', '')
        cert_path = f"/srv/pki/{hostname_short}/fullchain.crt"
        key_path = f"/srv/pki/{hostname_short}/{hostname_short}.key"

        # Erstelle Traefik-Config YAML
        config_yaml = f"""http:
  routers:
    {hostname_short}:
      rule: "Host(`{hostname}`)"
      entryPoints:
        - websecure
      service: {hostname_short}
      tls:
        certResolver: internal
        domains:
          - main: "{hostname}"

  services:
    {hostname_short}:
      loadBalancer:
        servers:
          - url: "{backend_ip}"
"""

        # Schreibe Config auf Traefik-Server
        config_file = f"{traefik_config_path}/{hostname_short}.yml"
        command = f"cat > {config_file} <<'EOF'\n{config_yaml}\nEOF"

        try:
            stdout, stderr, exit_code = self._ssh_execute(
                host=traefik_host,
                user=traefik_user,
                key_path=traefik_ssh_key,
                command=command
            )

            if exit_code != 0:
                error_msg = stderr if stderr else stdout
                self._log_audit(
                    action="create_traefik_service",
                    hostname=hostname,
                    user=user,
                    status="failed",
                    message=f"Traefik-Config konnte nicht erstellt werden: {error_msg}",
                    details={"backend_ip": backend_ip}
                )
                raise Exception(f"Traefik-Config konnte nicht erstellt werden: {error_msg}")

            # Traefik Container neustarten um Config zu laden
            self._restart_traefik()

            self._log_audit(
                action="create_traefik_service",
                hostname=hostname,
                user=user,
                status="success",
                message=f"Traefik-Service erstellt: https://{hostname} → {backend_ip}",
                details={"backend_ip": backend_ip, "config_file": config_file}
            )

        except subprocess.TimeoutExpired:
            self._log_audit(
                action="create_traefik_service",
                hostname=hostname,
                user=user,
                status="failed",
                message="Timeout beim Erstellen des Traefik-Service",
                details={"backend_ip": backend_ip}
            )
            raise Exception("Timeout beim Erstellen des Traefik-Service")

    def _add_pihole_dns(self, hostname: str, user: str):
        """
        Füge DNS-Eintrag zu Pi-hole hinzu

        Args:
            hostname: Service-Hostname (z.B. myapp.internal)
            user: User der die Aktion ausführt
        """
        pihole_manager_script = BASE_DIR.parent / "pihole-dns-manager" / "pihole-dns-manager.sh"

        if not pihole_manager_script.exists():
            self._log_audit(
                action="add_pihole_dns",
                hostname=hostname,
                user=user,
                status="failed",
                message="pihole-dns-manager Script nicht gefunden",
                details={"expected_path": str(pihole_manager_script)}
            )
            raise Exception(f"pihole-dns-manager Script nicht gefunden: {pihole_manager_script}")

        # Führe pihole-dns-manager add aus (IP = Traefik aus config)
        command = [
            str(pihole_manager_script),
            "add",
            "--hostname", hostname
        ]

        try:
            result = subprocess.run(
                command,
                stdin=subprocess.PIPE,
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode != 0:
                error_msg = result.stderr if result.stderr else result.stdout
                self._log_audit(
                    action="add_pihole_dns",
                    hostname=hostname,
                    user=user,
                    status="failed",
                    message=f"pihole-dns-manager fehlgeschlagen: {error_msg}",
                    details={"command": " ".join(command)}
                )
                raise Exception(f"Pi-hole DNS-Eintrag konnte nicht erstellt werden: {error_msg}")

            # Erfolgreich
            self._log_audit(
                action="add_pihole_dns",
                hostname=hostname,
                user=user,
                status="success",
                message="Pi-hole DNS-Eintrag erfolgreich erstellt",
                details={"dns_record": f"{hostname} -> 192.168.1.23 (Traefik)"}
            )

        except subprocess.TimeoutExpired:
            self._log_audit(
                action="add_pihole_dns",
                hostname=hostname,
                user=user,
                status="failed",
                message="Timeout beim Erstellen des Pi-hole DNS-Eintrags"
            )
            raise Exception("Timeout beim Erstellen des Pi-hole DNS-Eintrags")
        except Exception as e:
            self._log_audit(
                action="add_pihole_dns",
                hostname=hostname,
                user=user,
                status="failed",
                message=f"Fehler beim Erstellen: {str(e)}"
            )
            raise

    def _remove_pihole_dns(self, hostname: str, user: str):
        """
        Entferne DNS-Eintrag aus Pi-hole

        Args:
            hostname: Service-Hostname (z.B. myapp.internal)
            user: User der die Aktion ausführt
        """
        pihole_manager_script = BASE_DIR.parent / "pihole-dns-manager" / "pihole-dns-manager.sh"

        if not pihole_manager_script.exists():
            self._log_audit(
                action="remove_pihole_dns",
                hostname=hostname,
                user=user,
                status="failed",
                message="pihole-dns-manager Script nicht gefunden",
                details={"expected_path": str(pihole_manager_script)}
            )
            raise Exception(f"pihole-dns-manager Script nicht gefunden: {pihole_manager_script}")

        # Führe pihole-dns-manager remove aus
        command = [
            str(pihole_manager_script),
            "remove",
            "--hostname", hostname
        ]

        try:
            result = subprocess.run(
                command,
                stdin=subprocess.PIPE,
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode != 0:
                error_msg = result.stderr if result.stderr else result.stdout
                self._log_audit(
                    action="remove_pihole_dns",
                    hostname=hostname,
                    user=user,
                    status="failed",
                    message=f"pihole-dns-manager fehlgeschlagen: {error_msg}",
                    details={"command": " ".join(command)}
                )
                raise Exception(f"Pi-hole DNS-Eintrag konnte nicht entfernt werden: {error_msg}")

            # Erfolgreich
            self._log_audit(
                action="remove_pihole_dns",
                hostname=hostname,
                user=user,
                status="success",
                message="Pi-hole DNS-Eintrag erfolgreich entfernt",
                details={"dns_record_removed": hostname}
            )

        except subprocess.TimeoutExpired:
            self._log_audit(
                action="remove_pihole_dns",
                hostname=hostname,
                user=user,
                status="failed",
                message="Timeout beim Entfernen des Pi-hole DNS-Eintrags"
            )
            raise Exception("Timeout beim Entfernen des Pi-hole DNS-Eintrags")
        except Exception as e:
            self._log_audit(
                action="remove_pihole_dns",
                hostname=hostname,
                user=user,
                status="failed",
                message=f"Fehler beim Entfernen: {str(e)}"
            )
            raise
