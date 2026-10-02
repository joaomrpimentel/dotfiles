import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Left pill: CPU, GPU, RAM, package temperature. Replaces waybar's cpu,
// custom/gpu, memory and temperature modules.
RowLayout {
    id: root

    spacing: 0

    property int cpu: 0
    property int gpu: 0
    property int ram: 0
    property int temp: 0
    readonly property int tempCritical: 85

    property var _lastCpu: null

    function parse(out) {
        for (const line of out.trim().split("\n")) {
            const [key, ...rest] = line.trim().split(/\s+/);
            const v = rest.map(Number);
            if (key === "cpu") {
                // busy = everything except idle and iowait, over the delta
                // since the previous sample.
                const total = v.reduce((a, b) => a + b, 0);
                const idle = v[3] + v[4];
                if (_lastCpu) {
                    const dt = total - _lastCpu.total;
                    if (dt > 0)
                        cpu = Math.round(100 * (1 - (idle - _lastCpu.idle) / dt));
                }
                _lastCpu = { total, idle };
            } else if (key === "mem" && v[0] > 0) {
                ram = Math.round(100 * (1 - v[1] / v[0]));
            } else if (key === "gpu") {
                gpu = v[0] || 0;
            } else if (key === "temp") {
                temp = Math.round((v[0] || 0) / 1000);
            }
        }
    }

    Process {
        id: sampler
        command: [`${Quickshell.shellDir}/scripts/stats.sh`]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }

    component Stat: Txt {
        Layout.fillHeight: true
        leftPadding: Theme.padX
        rightPadding: Theme.padX
    }

    Stat { text: `CPU ${root.cpu}%` }
    Stat { text: `GPU ${root.gpu}%` }
    Stat { text: `RAM ${root.ram}%` }
    Stat {
        text: `${root.temp}°C`
        color: root.temp >= root.tempCritical ? Theme.urgent : Theme.dim
    }
}
