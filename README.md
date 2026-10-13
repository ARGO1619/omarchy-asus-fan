# ASUS Fan — an Omarchy bar widget

A bar widget for [Omarchy](https://omarchy.org) that adds a fan-speed slider for
ASUS laptops: it shows the current fan RPM and CPU temperature, and lets you put
the fans in manual mode at a duty you choose, or hand control back to the
embedded controller (EC).

It is a thin QML front-end over
[**asus-fan-control-ec**](https://github.com/Keyitdev/asus-fan-control-ec) by
Keyitdev, driven through a narrowly-scoped privileged helper.

> **Status: early / personal hardware.** The underlying EC protocol has been
> confirmed by upstream on a handful of AMD TUF models, plus this widget's
> author's Vivobook M7600QC. It is **not** verified on "all ASUS laptops". Run
> the compatibility check (below) before trusting it on your machine.

---

## ⚠️ Safety

This software writes to **undocumented registers of the embedded controller**.
Used carelessly it can stop the fans, overheat the machine, or leave the cooling
system in a state the firmware does not expect. It is distributed with **no
warranty**; you run it as root, on your own hardware, at your own risk. See
`LICENSE` and the upstream project's safety notes.

Practical points:

- **Manual mode freezes both fans** where the EC's curve last put them. Setting a
  low duty on a hot machine can overheat it.
- Manual mode is **not persisted by the hardware** and the widget hands control
  back to the EC when the shell restarts or you log out — but a hard crash or a
  power event can leave the EC in an unexpected state.
- If in doubt, run `omarchy-fanctl auto` (or press **Automatic**) to return to
  the EC's own curve.

---

## Requirements

- Omarchy with the Quattro shell (plugin API `schemaVersion: 1`).
- An ASUS laptop whose EC is compatible with `asus-fan-control-ec` (see below).
- `sudo`, and build tools (`git`, `make`, a C compiler) unless you already have
  the `asus-fan-control-ec` binary or install it from the AUR.

## Supported hardware

`asus-fan-control-ec` does the actual hardware access. Compatibility is
determined by that project, not by this widget:

- **Confirmed by upstream:** ASUS TUF Gaming A15 `FA507NV`, `FA506IU`, `FA506II`
  (AMD). Intel `FX608JHR` works partially.
- **Confirmed by this widget's author:** ASUS Vivobook `M7600QC` (AMD). Note that
  on this model the MMIO telemetry aperture is wrong, so RPM/temperature are read
  from `hwmon` instead — the widget does this automatically.

Anything else: run the check and see.

### Compatibility check

```sh
sudo /usr/local/bin/omarchy-fanctl status
```

- `{"available":true, ...}` — the EC answered; fan control should work.
- `{"available":false,"reason":"unsupported"}` — the EC did not answer; **do not**
  write to it.
- `{"available":false,"reason":"helper-missing"}` — helper not installed.

Writing anything to an unsupported EC can be harmful. If you are not sure, stop.

---

## Install

### 1. The upstream binary (root, once)

The widget drives [`asus-fan-control-ec`](https://github.com/Keyitdev/asus-fan-control-ec).
Install it first, from the AUR (`asus-fan-control-ec-git`) or by building upstream
yourself.

Then install `omarchy-fanctl` and a `sudoers` rule that grants **only your user**
passwordless access to **only that wrapper**:

```sh
git clone https://github.com/ARGO1619/omarchy-asus-fan.git
cd omarchy-asus-fan
sudo ./install.sh
```

`install.sh` never downloads anything. It uses an already installed
`/usr/local/bin/asus-fan-control-ec`, or one you point it at:

- `sudo AFC_BINARY=/path/to/asus-fan-control-ec ./install.sh` — install a prebuilt binary.
- `sudo AFC_SOURCE=/path/to/cloned/upstream ./install.sh` — build a **local** checkout.

### 2. The widget (user)

```sh
omarchy plugin add https://github.com/ARGO1619/omarchy-asus-fan.git --enable
```

Then place **ASUS Fan** in a bar section (defaults to the right).

---

## Usage

- **Click** the fan icon — opens a popup with a 0–100% slider, live RPM, CPU
  temperature, and **Automatic** / **Manual** buttons.
- **Drag the slider** — sets a manual duty (mouse wheel over the popup changes it
  in 1% steps).
- **Automatic** (or right-click the bar icon) — returns control to the EC.
- While manual, the bar icon shows the percentage.

When the helper is missing or the hardware is unsupported, the widget is
read-only and explains why in the popup.

---

## Uninstall

```sh
sudo ./uninstall.sh          # removes helper + sudoers rule
sudo ./uninstall.sh --purge  # also removes asus-fan-control-ec
omarchy plugin remove io.github.argo1619.asus-fan
```

---

## How it works

- `Panel.qml` — the Omarchy bar widget. It calls the helper with `sudo -n` and
  never touches the hardware itself.
- `helper/omarchy-fanctl` — the only privileged surface. It accepts exactly
  `status`, `set <0-100>`, and `auto`, validates its arguments, and shells out to
  `asus-fan-control-ec`.
- `install.sh` — installs the wrapper and a `sudoers` rule scoped to the wrapper
  and to your user, using an already installed (or supplied)
  `asus-fan-control-ec` binary. It never downloads anything itself.

Telemetry (RPM, temperature) is read from `hwmon` with automatic driver
detection (`k10temp`/`coretemp`/`zenpower`, any `fan1_input` sensor, or the ACPI
thermal zone), so the widget works even on models where the tool's MMIO
telemetry aperture is unusable.

---

## Security notes

The helper runs as **root**. The design keeps that surface as small as possible:

- Only three fixed operations are accepted; the percent argument is validated as
  an integer in `0..100`.
- `sudoers` grants `NOPASSWD` for the wrapper's path only, only to the desktop
  user. It does **not** grant general root.
- The wrapper and its sudoers rule are the files a reviewer should read; they are
  small on purpose.

If you are uncomfortable granting any passwordless root path, install the helper
yourself and grant access via a polkit rule or your own `sudo` setup instead of
`install.sh`.

---

## Credits

- [Keyitdev/asus-fan-control-ec](https://github.com/Keyitdev/asus-fan-control-ec)
  — the EC protocol implementation and CLI this widget drives. GPL-3.0.
- Omarchy's plugin API and UI toolkit (`qs.Ui`, `qs.Commons`).

## License

GPL-3.0-or-later. See `LICENSE` and `NOTICE`.
