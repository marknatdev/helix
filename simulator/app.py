"""
app.py
────────────────────────────────────────────────────────────────────────────
HELIX ESP32 Simulator — customtkinter UI.
Single-window dashboard to configure and drive a simulated helmet node.
────────────────────────────────────────────────────────────────────────────
"""
from __future__ import annotations

import secrets
import time
import tkinter as tk
from typing import Callable

import customtkinter as ctk
from PIL import Image

from simulator import HelmetSimulator, SimConfig, THAI_PRESETS, GPS_MODES
from qr_generator import build_tr005, make_qr_image

# ─── Theme ───────────────────────────────────────────────────────────────
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

PRIMARY     = "#3b82f6"
SUCCESS     = "#22c55e"
SUCCESS_HV  = "#16a34a"
DANGER      = "#ef4444"
DANGER_HV   = "#dc2626"
MUTED       = "#94a3b8"
SECTION_BG  = ("#f3f4f6", "#1e293b")
ROW_LABEL_W = 110


class SimulatorApp(ctk.CTk):
    def __init__(self) -> None:
        super().__init__()
        self.title("HELIX  ESP32 Simulator")
        self.geometry("680x940")
        self.minsize(620, 720)

        self.cfg = SimConfig()
        self.sim = HelmetSimulator(self.cfg, log_fn=self._enqueue_log)

        # Internal: track entry vars so we can sync from sim state
        self._lat_var = tk.StringVar(value=f"{self.cfg.lat:.6f}")
        self._lng_var = tk.StringVar(value=f"{self.cfg.lng:.6f}")
        self._suppress_sync = False  # avoid feedback loops

        self._build_ui()
        self._tick_ui()  # start UI poll

    # ──────────────────────────────────────────────────────────────────
    #  UI BUILD
    # ──────────────────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        # Header bar
        header = ctk.CTkFrame(self, fg_color="transparent")
        header.pack(fill="x", padx=20, pady=(16, 6))

        ctk.CTkLabel(
            header,
            text="HELIX",
            font=ctk.CTkFont(size=20, weight="bold"),
            text_color=PRIMARY,
        ).pack(side="left")
        ctk.CTkLabel(
            header,
            text="  ESP32 Simulator",
            font=ctk.CTkFont(size=18, weight="normal"),
        ).pack(side="left")

        self.status_pill = ctk.CTkLabel(
            header,
            text="●  Idle",
            font=ctk.CTkFont(size=12, weight="bold"),
            text_color=MUTED,
        )
        self.status_pill.pack(side="right")

        ctk.CTkLabel(
            self,
            text="Send simulated LoRaWAN uplinks to your local webhook server.",
            font=ctk.CTkFont(size=11),
            text_color=MUTED,
        ).pack(anchor="w", padx=22, pady=(0, 8))

        # Scrollable content
        scroll = ctk.CTkScrollableFrame(self, fg_color="transparent")
        scroll.pack(fill="both", expand=True, padx=12, pady=(0, 8))

        # ─── Connection ─
        sec = self._section(scroll, "Connection")
        self._entry_row(
            sec, "Webhook URL", self.cfg.webhook_url,
            on_change=lambda v: setattr(self.cfg, "webhook_url", v),
        )
        self._entry_row(
            sec, "Auth token", self.cfg.auth_token, show="•",
            on_change=lambda v: setattr(self.cfg, "auth_token", v),
        )

        # ─── Device ─
        sec = self._section(scroll, "Device")
        self._entry_row(
            sec, "Helmet ID", self.cfg.helmet_id,
            on_change=lambda v: setattr(self.cfg, "helmet_id", v),
        )
        self._key_entry_row(sec, "DevEUI",  attr="dev_eui",  length_bytes=8,  masked=False)
        self._key_entry_row(sec, "JoinEUI", attr="join_eui", length_bytes=8,  masked=False)
        self._key_entry_row(sec, "AppKey",  attr="app_key",  length_bytes=16, masked=True)

        # QR code button row
        row = self._row(sec)
        self._row_label(row, "")
        ctk.CTkButton(
            row, text="📱  Generate ChirpStack QR Code",
            command=self._show_qr_dialog,
            fg_color=PRIMARY, hover_color="#2563eb",
            font=ctk.CTkFont(size=12, weight="bold"),
            height=34,
        ).pack(side="left", fill="x", expand=True)

        # ─── GPS ─
        sec = self._section(scroll, "GPS  ·  Thailand")

        # Preset selector
        row = self._row(sec)
        self._row_label(row, "Preset")
        self.preset_menu = ctk.CTkOptionMenu(
            row,
            values=list(THAI_PRESETS.keys()),
            command=self._apply_preset,
            fg_color=("#e5e7eb", "#0f172a"),
            button_color=("#d1d5db", "#1e293b"),
            button_hover_color=("#cbd5e1", "#334155"),
        )
        self.preset_menu.set("Bangkok")
        self.preset_menu.pack(side="left", fill="x", expand=True)

        # Lat/Lng entries (bound to vars so we can sync)
        row = self._row(sec)
        self._row_label(row, "Latitude")
        ctk.CTkEntry(row, textvariable=self._lat_var).pack(side="left", fill="x", expand=True)
        self._lat_var.trace_add("write", lambda *a: self._set_lat(self._lat_var.get()))

        row = self._row(sec)
        self._row_label(row, "Longitude")
        ctk.CTkEntry(row, textvariable=self._lng_var).pack(side="left", fill="x", expand=True)
        self._lng_var.trace_add("write", lambda *a: self._set_lng(self._lng_var.get()))

        # GPS mode
        row = self._row(sec)
        self._row_label(row, "Mode")
        self.mode_menu = ctk.CTkOptionMenu(
            row,
            values=list(GPS_MODES),
            command=lambda v: setattr(self.cfg, "gps_mode", v),
            fg_color=("#e5e7eb", "#0f172a"),
            button_color=("#d1d5db", "#1e293b"),
            button_hover_color=("#cbd5e1", "#334155"),
        )
        self.mode_menu.set(self.cfg.gps_mode)
        self.mode_menu.pack(side="left", fill="x", expand=True)

        # Speed / heading / sats sliders
        self.speed_slider, self.speed_lbl = self._slider_row(
            sec, "Speed", 0, 30, self.cfg.speed_mps,
            lambda v: setattr(self.cfg, "speed_mps", float(v)),
            fmt="{:.1f} m/s",
        )
        self.heading_slider, self.heading_lbl = self._slider_row(
            sec, "Heading", 0, 359, self.cfg.heading,
            lambda v: setattr(self.cfg, "heading", float(v)),
            fmt="{:.0f}°",
        )
        self.sats_slider, self.sats_lbl = self._slider_row(
            sec, "Satellites", 0, 16, self.cfg.satellites,
            lambda v: setattr(self.cfg, "satellites", int(float(v))),
            fmt="{:.0f}",
        )

        # ─── Sensors ─
        sec = self._section(scroll, "Sensors")
        self.battery_slider, self.battery_lbl = self._slider_row(
            sec, "Battery", 0, 100, self.cfg.battery,
            lambda v: setattr(self.cfg, "battery", float(v)),
            fmt="{:.0f}%",
        )
        row = self._row(sec)
        self._row_label(row, "")
        self.drain_switch = ctk.CTkSwitch(
            row, text=f"Auto-drain (-{self.cfg.drain_rate}%/tick)",
            command=lambda: setattr(self.cfg, "auto_drain", bool(self.drain_switch.get())),
        )
        self.drain_switch.pack(side="left")
        if self.cfg.auto_drain:
            self.drain_switch.select()

        self.hr_slider, self.hr_lbl = self._slider_row(
            sec, "Heart rate", 50, 180, self.cfg.heart_rate,
            lambda v: setattr(self.cfg, "heart_rate", float(v)),
            fmt="{:.0f} bpm",
        )

        # ─── Signal ─
        sec = self._section(scroll, "LoRaWAN Signal")
        self.rssi_slider, self.rssi_lbl = self._slider_row(
            sec, "RSSI", -120, -30, self.cfg.rssi,
            lambda v: setattr(self.cfg, "rssi", float(v)),
            fmt="{:.0f} dBm",
        )
        self.snr_slider, self.snr_lbl = self._slider_row(
            sec, "SNR", -10, 15, self.cfg.snr,
            lambda v: setattr(self.cfg, "snr", float(v)),
            fmt="{:.1f} dB",
        )
        row = self._row(sec)
        self._row_label(row, "")
        self.jitter_switch = ctk.CTkSwitch(
            row, text="Auto-jitter signal",
            command=lambda: setattr(self.cfg, "rssi_jitter", bool(self.jitter_switch.get())),
        )
        if self.cfg.rssi_jitter:
            self.jitter_switch.select()
        self.jitter_switch.pack(side="left")

        # ─── Transmit ─
        sec = self._section(scroll, "Transmit")
        self.tx_slider, self.tx_lbl = self._slider_row(
            sec, "Interval", 1, 60, self.cfg.tx_interval_s,
            lambda v: setattr(self.cfg, "tx_interval_s", float(v)),
            fmt="{:.0f} s",
        )

        row = self._row(sec)
        self.start_btn = ctk.CTkButton(
            row, text="▶  Start", command=self._toggle,
            fg_color=SUCCESS, hover_color=SUCCESS_HV,
            font=ctk.CTkFont(size=13, weight="bold"),
            width=140, height=34,
        )
        self.start_btn.pack(side="left", padx=(0, 8))
        ctk.CTkButton(
            row, text="⚡  Send Now", command=self.sim.send_now,
            fg_color="transparent", border_width=1,
            border_color=("#d1d5db", "#334155"),
            text_color=("#1f2937", "#e5e7eb"),
            hover_color=("#e5e7eb", "#1f2937"),
            width=130, height=34,
        ).pack(side="left")

        self.tx_status_lbl = ctk.CTkLabel(
            row, text="TX# 0   —", text_color=MUTED, anchor="e",
            font=ctk.CTkFont(family="Consolas", size=11),
        )
        self.tx_status_lbl.pack(side="right", fill="x", expand=True, padx=(8, 0))

        # ─── Activity Log ─
        sec = self._section(scroll, "Activity Log")
        self.log_box = ctk.CTkTextbox(
            sec, height=160,
            font=ctk.CTkFont(family="Consolas", size=11),
            fg_color=("#ffffff", "#0f172a"),
        )
        self.log_box.pack(fill="both", expand=True)
        self.log_box.configure(state="disabled")

        # Pending log lines (filled by background thread, drained by UI poll)
        self._log_queue: list[str] = []
        self._log_lock_dummy = False  # GIL-protected list, no real lock needed

    # ──────────────────────────────────────────────────────────────────
    #  QR code dialog
    # ──────────────────────────────────────────────────────────────────

    def _show_qr_dialog(self) -> None:
        """Open a top-level window showing a TR005 QR code that ChirpStack
        can scan to import the device."""
        QrDialog(self, self.cfg)

    # ──────────────────────────────────────────────────────────────────
    #  Layout helpers
    # ──────────────────────────────────────────────────────────────────

    def _section(self, parent, title: str) -> ctk.CTkFrame:
        outer = ctk.CTkFrame(parent, fg_color=SECTION_BG, corner_radius=10)
        outer.pack(fill="x", pady=6, padx=2)
        ctk.CTkLabel(
            outer, text=title.upper(),
            font=ctk.CTkFont(size=10, weight="bold"),
            text_color=MUTED, anchor="w",
        ).pack(fill="x", padx=14, pady=(10, 4))
        inner = ctk.CTkFrame(outer, fg_color="transparent")
        inner.pack(fill="both", expand=True, padx=12, pady=(0, 12))
        return inner

    def _row(self, parent) -> ctk.CTkFrame:
        f = ctk.CTkFrame(parent, fg_color="transparent")
        f.pack(fill="x", pady=3)
        return f

    def _row_label(self, row: ctk.CTkFrame, text: str) -> None:
        ctk.CTkLabel(row, text=text, width=ROW_LABEL_W, anchor="w").pack(side="left")

    def _entry_row(
        self,
        parent,
        label: str,
        value: str,
        show: str | None = None,
        on_change: Callable[[str], None] | None = None,
    ) -> ctk.CTkEntry:
        row = self._row(parent)
        self._row_label(row, label)
        var = tk.StringVar(value=str(value))
        entry = ctk.CTkEntry(row, textvariable=var, show=show)
        entry.pack(side="left", fill="x", expand=True)
        if on_change:
            var.trace_add("write", lambda *a: on_change(var.get()))
        return entry

    def _key_entry_row(
        self,
        parent,
        label: str,
        *,
        attr: str,
        length_bytes: int,
        masked: bool,
    ) -> ctk.CTkEntry:
        """Hex-key entry with 🎲 Generate, 👁 Show/Hide (if masked), 📋 Copy buttons.

        `attr` is the SimConfig attribute name to bind to.
        `length_bytes` controls how many bytes random keys have (8 for EUI, 16 for AppKey).
        """
        row = self._row(parent)
        self._row_label(row, label)

        var = tk.StringVar(value=getattr(self.cfg, attr))
        state = {"masked": masked}

        entry = ctk.CTkEntry(
            row, textvariable=var,
            show="•" if masked else "",
            font=ctk.CTkFont(family="Consolas", size=11),
        )
        entry.pack(side="left", fill="x", expand=True, padx=(0, 6))
        var.trace_add("write", lambda *a: setattr(self.cfg, attr, var.get()))

        eye_btn_holder: list[ctk.CTkButton] = []  # filled below if masked

        def gen() -> None:
            new_val = secrets.token_hex(length_bytes).upper()
            var.set(new_val)
            # Auto-reveal after generating, so the user actually sees the new key
            if state["masked"]:
                state["masked"] = False
                entry.configure(show="")
                if eye_btn_holder:
                    eye_btn_holder[0].configure(text="🙈")

        def toggle() -> None:
            state["masked"] = not state["masked"]
            entry.configure(show="•" if state["masked"] else "")
            if eye_btn_holder:
                eye_btn_holder[0].configure(text="👁" if state["masked"] else "🙈")

        def copy() -> None:
            self.clipboard_clear()
            self.clipboard_append(var.get())
            self.update()

        btn_kw = dict(
            width=34, height=28,
            font=ctk.CTkFont(size=13),
            fg_color="transparent", border_width=1,
            border_color=("#d1d5db", "#334155"),
            text_color=("#1f2937", "#e5e7eb"),
            hover_color=("#e5e7eb", "#1f2937"),
        )

        ctk.CTkButton(row, text="🎲", command=gen, **btn_kw).pack(side="left", padx=1)
        if masked:
            eye = ctk.CTkButton(row, text="👁", command=toggle, **btn_kw)
            eye.pack(side="left", padx=1)
            eye_btn_holder.append(eye)
        ctk.CTkButton(row, text="📋", command=copy, **btn_kw).pack(side="left", padx=1)

        return entry

    def _slider_row(
        self,
        parent,
        label: str,
        vmin: float,
        vmax: float,
        value: float,
        on_change: Callable[[float], None],
        fmt: str = "{:.1f}",
    ) -> tuple[ctk.CTkSlider, ctk.CTkLabel]:
        row = self._row(parent)
        self._row_label(row, label)
        slider = ctk.CTkSlider(row, from_=vmin, to=vmax)
        slider.set(value)
        slider.pack(side="left", fill="x", expand=True, padx=(0, 8))
        val_lbl = ctk.CTkLabel(
            row, text=fmt.format(value), width=80, anchor="e",
            font=ctk.CTkFont(family="Consolas", size=11),
            text_color=MUTED,
        )
        val_lbl.pack(side="right")

        def cmd(v: float) -> None:
            val_lbl.configure(text=fmt.format(float(v)))
            if not self._suppress_sync:
                on_change(float(v))

        slider.configure(command=cmd)
        # Stash formatter so we can re-format when syncing from sim state
        slider._fmt = fmt          # type: ignore[attr-defined]
        slider._lbl = val_lbl      # type: ignore[attr-defined]
        return slider, val_lbl

    # ──────────────────────────────────────────────────────────────────
    #  Handlers
    # ──────────────────────────────────────────────────────────────────

    def _set_lat(self, v: str) -> None:
        if self._suppress_sync:
            return
        try:
            self.cfg.lat = float(v)
        except ValueError:
            pass

    def _set_lng(self, v: str) -> None:
        if self._suppress_sync:
            return
        try:
            self.cfg.lng = float(v)
        except ValueError:
            pass

    def _apply_preset(self, name: str) -> None:
        lat, lng = THAI_PRESETS[name]
        self.cfg.lat = lat
        self.cfg.lng = lng
        # Default a route target ~1.5 km NE so 'route' mode has somewhere to go
        self.cfg.route_target_lat = lat + 0.012
        self.cfg.route_target_lng = lng + 0.012
        self._suppress_sync = True
        self._lat_var.set(f"{lat:.6f}")
        self._lng_var.set(f"{lng:.6f}")
        self._suppress_sync = False

    def _toggle(self) -> None:
        if self.sim.is_running():
            self.sim.stop()
            self.start_btn.configure(text="▶  Start", fg_color=SUCCESS, hover_color=SUCCESS_HV)
            self.status_pill.configure(text="●  Idle", text_color=MUTED)
        else:
            self.sim.start()
            self.start_btn.configure(text="■  Stop", fg_color=DANGER, hover_color=DANGER_HV)
            self.status_pill.configure(text="●  Live", text_color=SUCCESS)

    # ──────────────────────────────────────────────────────────────────
    #  Logging (thread-safe)
    # ──────────────────────────────────────────────────────────────────

    def _enqueue_log(self, msg: str) -> None:
        ts = time.strftime("%H:%M:%S")
        self._log_queue.append(f"[{ts}]  {msg}\n")

    def _drain_log(self) -> None:
        if not self._log_queue:
            return
        chunk = "".join(self._log_queue)
        self._log_queue.clear()
        self.log_box.configure(state="normal")
        self.log_box.insert("end", chunk)
        # Cap to ~300 lines
        text = self.log_box.get("1.0", "end")
        lines = text.splitlines()
        if len(lines) > 300:
            self.log_box.delete("1.0", f"{len(lines) - 300}.0")
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    # ──────────────────────────────────────────────────────────────────
    #  UI poll — keeps sliders/labels in sync with sim state
    # ──────────────────────────────────────────────────────────────────

    def _tick_ui(self) -> None:
        self._drain_log()

        # Update TX status pill
        self.tx_status_lbl.configure(
            text=f"TX# {self.sim.tx_count}   {self.sim.last_status}"
        )

        # Sync sliders/entries from sim state when running (so auto-drain,
        # jitter, and random-walk are visible in the UI).
        if self.sim.is_running():
            self._suppress_sync = True
            self._sync_slider(self.battery_slider, self.cfg.battery)
            self._sync_slider(self.rssi_slider, self.cfg.rssi)
            self._sync_slider(self.snr_slider, self.cfg.snr)
            self._sync_slider(self.heading_slider, self.cfg.heading)
            self._lat_var.set(f"{self.cfg.lat:.6f}")
            self._lng_var.set(f"{self.cfg.lng:.6f}")
            self._suppress_sync = False

        self.after(400, self._tick_ui)

    @staticmethod
    def _sync_slider(slider: ctk.CTkSlider, value: float) -> None:
        slider.set(value)
        fmt = getattr(slider, "_fmt", "{:.1f}")
        lbl: ctk.CTkLabel | None = getattr(slider, "_lbl", None)
        if lbl is not None:
            lbl.configure(text=fmt.format(value))


# ─────────────────────────────────────────────────────────────────────────
#  QR code dialog window
# ─────────────────────────────────────────────────────────────────────────

class QrDialog(ctk.CTkToplevel):
    """Modal-ish popup that shows a TR005 QR code for ChirpStack import,
    plus the underlying credentials in copy-friendly format."""

    def __init__(self, parent: ctk.CTk, cfg: SimConfig) -> None:
        super().__init__(parent)
        self.cfg = cfg
        self.title("ChirpStack Device QR Code")
        self.geometry("480x720")
        self.minsize(440, 640)
        self.transient(parent)
        # Bring to front (CTk windows can lag behind on Windows)
        self.after(100, self.lift)
        self.after(100, self.focus_force)

        # Build the TR005 QR string
        qr_text = build_tr005(
            dev_eui=cfg.dev_eui,
            join_eui=cfg.join_eui,
            profile_id="00000000",
        )

        # Header
        ctk.CTkLabel(
            self, text="ChirpStack Device QR",
            font=ctk.CTkFont(size=18, weight="bold"),
        ).pack(anchor="w", padx=24, pady=(20, 2))
        ctk.CTkLabel(
            self,
            text="Scan in ChirpStack → Devices → Add device → Scan QR.\n"
                 "AppKey is shown below — enter it manually after scanning.",
            font=ctk.CTkFont(size=11),
            text_color=MUTED, justify="left",
        ).pack(anchor="w", padx=24, pady=(0, 14))

        # QR image
        try:
            pil_img = make_qr_image(qr_text, size=320)
            ctk_img = ctk.CTkImage(
                light_image=pil_img, dark_image=pil_img, size=(320, 320)
            )
            qr_holder = ctk.CTkFrame(self, fg_color="white", corner_radius=8)
            qr_holder.pack(padx=24, pady=(0, 14))
            ctk.CTkLabel(qr_holder, image=ctk_img, text="").pack(padx=14, pady=14)
            self._qr_img_ref = ctk_img  # prevent GC
        except Exception as e:
            ctk.CTkLabel(
                self, text=f"Failed to render QR: {e}",
                text_color=DANGER,
            ).pack(padx=24, pady=10)

        # ─ TR005 string (copy-able) ─
        self._field_block(
            "TR005 string (encoded in QR)", qr_text, mono=True,
        )

        # ─ Device credentials ─
        creds_frame = ctk.CTkFrame(self, fg_color=SECTION_BG, corner_radius=10)
        creds_frame.pack(fill="x", padx=24, pady=(0, 10))
        ctk.CTkLabel(
            creds_frame, text="DEVICE CREDENTIALS",
            font=ctk.CTkFont(size=10, weight="bold"),
            text_color=MUTED,
        ).pack(anchor="w", padx=14, pady=(10, 6))

        self._cred_row(creds_frame, "DevEUI",  cfg.dev_eui.upper())
        self._cred_row(creds_frame, "JoinEUI", cfg.join_eui.upper())
        self._cred_row(creds_frame, "AppKey",  cfg.app_key.upper())

        ctk.CTkLabel(creds_frame, text="").pack(pady=2)  # bottom padding

        # Bottom buttons
        btn_row = ctk.CTkFrame(self, fg_color="transparent")
        btn_row.pack(fill="x", padx=24, pady=(0, 20))
        ctk.CTkButton(
            btn_row, text="Copy TR005 String",
            command=lambda: self._copy_to_clipboard(qr_text),
            fg_color=PRIMARY, hover_color="#2563eb",
            height=34,
        ).pack(side="left", fill="x", expand=True, padx=(0, 6))
        ctk.CTkButton(
            btn_row, text="Save QR as PNG…",
            command=lambda: self._save_qr_png(qr_text),
            fg_color="transparent", border_width=1,
            border_color=("#d1d5db", "#334155"),
            text_color=("#1f2937", "#e5e7eb"),
            hover_color=("#e5e7eb", "#1f2937"),
            height=34,
        ).pack(side="left", fill="x", expand=True)

    # ── helpers ───────────────────────────────────────────────────────

    def _field_block(self, title: str, value: str, mono: bool = False) -> None:
        wrapper = ctk.CTkFrame(self, fg_color=SECTION_BG, corner_radius=8)
        wrapper.pack(fill="x", padx=24, pady=(0, 10))
        ctk.CTkLabel(
            wrapper, text=title.upper(),
            font=ctk.CTkFont(size=10, weight="bold"),
            text_color=MUTED, anchor="w",
        ).pack(fill="x", padx=14, pady=(10, 4))
        font = (ctk.CTkFont(family="Consolas", size=11)
                if mono else ctk.CTkFont(size=11))
        entry = ctk.CTkEntry(
            wrapper, font=font,
            fg_color=("#ffffff", "#0f172a"),
            border_width=0,
        )
        entry.insert(0, value)
        entry.configure(state="readonly")
        entry.pack(fill="x", padx=12, pady=(0, 12))

    def _cred_row(self, parent, label: str, value: str) -> None:
        row = ctk.CTkFrame(parent, fg_color="transparent")
        row.pack(fill="x", padx=14, pady=2)
        ctk.CTkLabel(
            row, text=label, width=80, anchor="w",
            font=ctk.CTkFont(size=11, weight="bold"),
        ).pack(side="left")
        val_lbl = ctk.CTkLabel(
            row, text=value,
            font=ctk.CTkFont(family="Consolas", size=11),
            anchor="w",
        )
        val_lbl.pack(side="left", fill="x", expand=True, padx=(4, 6))
        ctk.CTkButton(
            row, text="Copy", width=54, height=24,
            font=ctk.CTkFont(size=10),
            fg_color="transparent", border_width=1,
            border_color=("#d1d5db", "#334155"),
            text_color=("#1f2937", "#e5e7eb"),
            hover_color=("#e5e7eb", "#1f2937"),
            command=lambda v=value: self._copy_to_clipboard(v),
        ).pack(side="right")

    def _copy_to_clipboard(self, text: str) -> None:
        self.clipboard_clear()
        self.clipboard_append(text)
        self.update()  # required on Windows so clipboard persists after close

    def _save_qr_png(self, qr_text: str) -> None:
        from tkinter import filedialog
        path = filedialog.asksaveasfilename(
            parent=self,
            title="Save QR code",
            defaultextension=".png",
            filetypes=[("PNG image", "*.png")],
            initialfile=f"{self.cfg.helmet_id}_qr.png",
        )
        if not path:
            return
        try:
            img = make_qr_image(qr_text, size=512)
            img.save(path, "PNG")
        except Exception as e:
            ctk.CTkLabel(self, text=f"Save failed: {e}",
                         text_color=DANGER).pack(padx=24, pady=4)
