import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// Fan speed control for ASUS laptops, backed by the privileged root helper
// /usr/local/bin/omarchy-fanctl (installed by this repository's install.sh).
//
// The bar shows a fan glyph; while a manual duty is active it also shows the
// percentage. The popup carries a 0-100% slider plus an Automatic button that
// hands control back to the embedded controller.
//
// All embedded-controller writes go through the helper via `sudo -n`, so the
// shell itself never needs root. If the helper or its sudoers rule is missing,
// the panel degrades to read-only. If the hardware is not supported, the helper
// reports it and the widget stays read-only too.
Panel {
  id: root
  moduleName: "io.github.argo1619.asus-fan"
  ipcTarget: "io.github.argo1619.asus-fan"

  readonly property string helper: "/usr/local/bin/omarchy-fanctl"

  property bool available: false
  property string reason: ""         // "helper-missing" | "unsupported" | ""
  property string mode: "auto"       // "auto" | "manual"
  property int percent: 0
  property int cpuRpm: 0
  property int gpuRpm: 0
  property int cpuTemp: -1

  readonly property bool manual: mode === "manual"

  function refresh() {
    statusProc.command = ["/usr/bin/sudo", "-n", root.helper, "status"]
    if (!statusProc.running) statusProc.running = true
  }

  function applyStatus(text) {
    var data = null
    try { data = JSON.parse(String(text || "").trim()) } catch (e) { data = null }
    if (!data) { root.available = false; root.reason = "helper-missing"; return }
    root.available = data.available === true
    if (!root.available) {
      root.reason = String(data.reason || "")
      return
    }
    root.reason = ""
    root.mode = data.mode === "manual" ? "manual" : "auto"
    var p = Number(data.percent)
    if (isFinite(p) && p >= 0) root.percent = Math.round(p)
    root.cpuRpm = Math.max(0, Math.round(Number(data.cpu_rpm) || 0))
    root.gpuRpm = Math.max(0, Math.round(Number(data.gpu_rpm) || 0))
    var t = Number(data.temp)
    root.cpuTemp = isFinite(t) ? Math.round(t) : -1
  }

  function previewPercent(value) {
    root.percent = Math.max(0, Math.min(100, Math.round(value)))
  }

  function setPercent(value) {
    if (!root.available) return
    var p = Math.max(0, Math.min(100, Math.round(value)))
    root.percent = p
    root.mode = "manual"
    setProc.command = ["/usr/bin/sudo", "-n", root.helper, "set", String(p)]
    if (!setProc.running) setProc.running = true
  }

  function setAuto() {
    if (!root.available) return
    root.mode = "auto"
    autoProc.command = ["/usr/bin/sudo", "-n", root.helper, "auto"]
    if (!autoProc.running) autoProc.running = true
  }

  function adjustPercent(delta) {
    root.setPercent(root.percent + delta)
  }

  function statusLine() {
    if (!root.available)
      return root.reason === "unsupported" ? "Fan control not supported on this device" : "Fan helper not installed"
    return (root.manual ? "Manual" : "Automatic") + " · " + root.percent + "% · CPU " + root.cpuRpm +
           " rpm · GPU " + root.gpuRpm + " rpm" + (root.cpuTemp >= 0 ? " · " + root.cpuTemp + "°C" : "")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  // Fail-safe: whenever the widget is torn down (shell restart, config reload,
  // logout) hand the fans back to the EC so a manual duty can never outlive the
  // UI that set it. Best effort -- a hard shell crash may skip it.
  Component.onDestruction: if (root.manual) {
    resetProc.command = ["/usr/bin/sudo", "-n", root.helper, "auto"]
    resetProc.running = true
  }

  Timer {
    interval: 2000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    onExited: function(code) { if (code !== 0) root.available = false }
  }

  Process {
    id: setProc
    command: []
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) root.refresh()
  }

  Process {
    id: autoProc
    command: []
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) root.refresh()
  }

  Process {
    id: resetProc
    command: []
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈐" + (root.manual ? " " + root.percent + "%" : "")
    fontSize: Style.font.bodySmall
    active: root.manual
    useActiveColor: false
    tooltipText: root.statusLine()

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && root.available) root.setAuto()
      else { root.refresh(); root.toggle() }
    }
    onWheelMoved: function(delta) {
      if (!root.available) return
      root.adjustPercent(delta > 0 ? 1 : -1)
    }
  }

  KeyboardPanel {
    id: panel

    KeyboardPanel {
    }

    Column {
      id: column
      width: parent.width
      spacing: Style.space(12)

      PanelHero {
        width: parent.width
        title: "Fan"
        meta: root.available ? (root.manual ? "MANUAL" : "AUTOMATIC") : (root.reason === "unsupported" ? "NOT SUPPORTED" : "HELPER NOT AVAILABLE")
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Column {
        width: parent.width
        spacing: Style.space(12)

        Column {
          width: parent.width
          spacing: Style.spacing.controlGap

          Row {
            width: parent.width

            Text {
              textFormat: Text.PlainText
              text: "Speed"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
            }

            Item { width: 1; height: 1; Layout.fillWidth: true }

            Text {
              textFormat: Text.PlainText
              text: root.percent + "%"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
            }
          }

          CursorSurface {
            width: parent.width
            height: fanSlider.implicitHeight + Style.spacing.controlGap
            hasCursor: false
            foreground: root.bar.foreground
            outline: true

            PanelSlider {
              id: fanSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              enabled: root.available
              minimum: 0
              maximum: 100
              step: 1
              integer: true
              value: root.percent
              onMoved: function(v) { root.previewPercent(v) }
              onReleased: function(v) { root.setPercent(v) }
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Row {
          width: parent.width
          spacing: Style.space(18)

          Text {
            textFormat: Text.PlainText
            text: "CPU  " + root.cpuRpm + " rpm"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            textFormat: Text.PlainText
            text: "GPU  " + root.gpuRpm + " rpm"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }

          Item { width: 1; height: 1 }

          Text {
            textFormat: Text.PlainText
            text: root.cpuTemp >= 0 ? root.cpuTemp + "°C" : ""
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            visible: root.cpuTemp >= 0
          }
        }

        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Button {
            width: (parent.width - Style.spacing.sm) / 2
            text: "Automatic"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            active: !root.manual
            enabled: root.available
            onClicked: root.setAuto()
          }

          Button {
            width: (parent.width - Style.spacing.sm) / 2
            text: root.manual ? ("Manual " + root.percent + "%") : "Manual"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            active: root.manual
            enabled: root.available
            onClicked: root.setPercent(root.percent)
          }
        }

        Text {
          visible: !root.available
          width: parent.width
          textFormat: Text.PlainText
          text: root.reason === "unsupported"
            ? "Fan control is not supported on this device. The helper answered, but the embedded controller is not compatible."
            : "Fan helper not installed. Run install.sh from the repository with sudo to enable control."
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          opacity: 0.7
        }
      }
    }
  }
}
