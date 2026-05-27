"""
main.py — entry point for the HELIX ESP32 Simulator.

Run:
    python main.py
"""
from app import SimulatorApp


def main() -> None:
    app = SimulatorApp()
    app.mainloop()


if __name__ == "__main__":
    main()
