import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// App launcher, calculator, command runner and clipboard history. Replaces
// walker + elephant and walker/scripts/clipboard.sh. Opens out of the clock pill.
//
// Same prefixes walker had:
//     (none)  apps, plus a calculator row when the query looks like math
//     =       calculator (qalc)     Enter copies the result
//     >       run a command         Enter runs, Shift+Enter runs in kitty
//     :       clipboard (cliphist)  Enter copies, Ctrl+D deletes
//     ;       list of prefixes
//
// The panel is as tall as its results, so typing makes the glass breathe on
// the Morph spring as the list grows and shrinks.
FocusScope {
    id: root

    property bool shown: false
    // "apps" or "clipboard": which mode an empty query means.
    property string startMode: "apps"
    signal done

    readonly property int pad: 14
    readonly property int innerWidth: 560
    readonly property int rowH: 46
    readonly property int maxRows: 8

    implicitWidth: innerWidth + pad * 2
    implicitHeight: pad + 40 + (results.length ? 10 + Math.min(results.length, maxRows) * rowH : 0) + pad

    // ── Query and mode ──────────────────────────────────────────────────────
    property string query: ""
    readonly property string prefix: [";", ">", "=", ":"].includes(query.charAt(0)) ? query.charAt(0) : ""
    readonly property string term: (prefix ? query.slice(1) : query).trim()
    readonly property string mode: prefix === ";" ? "prefixes"
                                  : prefix === ">" ? "run"
                                  : prefix === "=" ? "calc"
                                  : prefix === ":" ? "clipboard"
                                  : startMode

    onShownChanged: {
        if (!shown)
            return;
        input.text = "";
        current = 0;
        lastPointer = Qt.point(-1, -1);
        if (startMode === "clipboard")
            clipProc.running = true;
    }
    onModeChanged: {
        current = 0;
        if (mode === "clipboard")
            clipProc.running = true;
    }

    // ── Usage counts, for ranking apps you actually open ────────────────────
    FileView {
        id: usageFile
        path: `${Quickshell.stateDir}/launcher-usage.json`
        printErrors: false
        watchChanges: false
        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }
    function bump(id) {
        const c = Object.assign({}, usage.counts);
        c[id] = (c[id] ?? 0) + 1;
        usage.counts = c;
        usageFile.writeAdapter();
    }

    // ── Matching ────────────────────────────────────────────────────────────
    // Prefix beats word-start beats substring beats scattered subsequence.
    function score(q, s) {
        if (!s)
            return 0;
        s = s.toLowerCase();
        const i = s.indexOf(q);
        if (i === 0)
            return 100 - s.length * 0.2;
        if (i > 0)
            return " -_.".includes(s[i - 1]) ? 80 : 60;
        let qi = 0, gaps = 0, last = -1;
        for (let k = 0; k < s.length && qi < q.length; k++) {
            if (s[k] === q[qi]) {
                if (last >= 0)
                    gaps += k - last - 1;
                last = k;
                qi++;
            }
        }
        return qi === q.length ? Math.max(1, 40 - gaps) : 0;
    }

    function appResults() {
        const q = term.toLowerCase();
        const counts = usage.counts;
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay)
                continue;
            let s = 1;
            if (q) {
                s = Math.max(score(q, e.name),
                             score(q, e.genericName) * 0.6,
                             score(q, (e.keywords ?? []).join(" ")) * 0.5);
                if (s <= 0)
                    continue;
            }
            const used = counts[e.id] ?? 0;
            out.push({
                key: `app:${e.id}`,
                title: e.name,
                subtitle: e.genericName || e.comment || "",
                icon: e.icon,
                glyph: "󰀻",
                rank: s + Math.log(used + 1) * 8,
                run: () => { bump(e.id); e.execute(); }
            });
        }
        out.sort((a, b) => b.rank - a.rank || a.title.localeCompare(b.title));
        return out.slice(0, 40);
    }

    readonly property bool looksLikeMath: /\d/.test(term) && /[+\-*/^%()]|sqrt|sin|cos|tan|log|ln|pi/.test(term)

    property string calcResult: ""
    Timer {
        id: calcDebounce
        interval: 120
        onTriggered: {
            if ((root.mode === "calc" || root.looksLikeMath) && root.term)
                calcProc.exec(["qalc", "-t", root.term]);
            else
                root.calcResult = "";
        }
    }
    onTermChanged: calcDebounce.restart()
    Process {
        id: calcProc
        stdout: StdioCollector {
            onStreamFinished: root.calcResult = text.trim()
        }
    }

    function calcRow() {
        if (!calcResult || !term)
            return [];
        return [{
            key: "calc",
            title: calcResult,
            subtitle: `${term}  ·  Enter copia`,
            icon: "",
            glyph: "󰃬",
            run: () => Quickshell.execDetached(["wl-copy", calcResult])
        }];
    }

    // Clipboard: `cliphist list` is "<id>\t<preview>" per line, and decode and
    // delete both read that whole line back on stdin.
    property var clipLines: []
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clipLines = text.split("\n").filter(l => l.includes("\t")).slice(0, 200)
        }
    }
    function clipResults() {
        const q = term.toLowerCase();
        return clipLines
            .filter(l => !q || l.toLowerCase().includes(q))
            .slice(0, 60)
            .map(l => {
                const preview = l.slice(l.indexOf("\t") + 1);
                const isImage = preview.startsWith("[[ binary data");
                return {
                    key: `clip:${l.slice(0, l.indexOf("\t"))}`,
                    title: preview.replace(/\s+/g, " ").slice(0, 120),
                    subtitle: isImage ? "imagem" : "",
                    icon: "",
                    glyph: isImage ? "󰋩" : "󰅍",
                    line: l,
                    run: () => Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", l])
                };
            });
    }
    function deleteClip(r) {
        if (!r?.line)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", r.line]);
        clipLines = clipLines.filter(l => l !== r.line);
    }

    readonly property var results: {
        switch (mode) {
        case "prefixes":
            return [
                { key: "p=", title: "=  Calculadora", subtitle: "qalc", glyph: "󰃬", icon: "", fill: "=" },
                { key: "p>", title: ">  Executar comando", subtitle: "Shift+Enter abre no terminal", glyph: "󰆍", icon: "", fill: ">" },
                { key: "p:", title: ":  Clipboard", subtitle: "Ctrl+D apaga", glyph: "󰅍", icon: "", fill: ":" }
            ].map(p => Object.assign(p, { run: () => { input.text = p.fill; return true; } }));
        case "run":
            return term ? [{
                key: "run",
                title: term,
                subtitle: "Enter executa  ·  Shift+Enter no terminal",
                icon: "",
                glyph: "󰆍",
                run: () => Quickshell.execDetached(["sh", "-c", term]),
                runTerm: () => Quickshell.execDetached(["kitty", "-e", "sh", "-c", term])
            }] : [];
        case "calc":
            return calcRow();
        case "clipboard":
            return clipResults();
        default:
            return looksLikeMath ? [...calcRow(), ...appResults()] : appResults();
        }
    }

    // Every keystroke puts the selection back on the best match, so Enter
    // always means "the top result".
    property int current: 0
    onQueryChanged: current = 0
    onResultsChanged: current = Math.min(current, Math.max(0, results.length - 1))

    // Hover only selects when the pointer actually moves. Rows reflow under a
    // resting cursor as you type, and a plain onEntered would hand the
    // selection to whatever row slid beneath it — usually one near the bottom.
    property point lastPointer: Qt.point(-1, -1)
    function hoverSelect(item, x, y, index) {
        const p = item.mapToGlobal(x, y);
        if (p.x === lastPointer.x && p.y === lastPointer.y)
            return;
        const first = lastPointer.x < 0;
        lastPointer = p;
        // The first event after opening is just where the pointer already was.
        if (!first)
            current = index;
    }

    function activate(i, alt) {
        const r = results[i];
        if (!r)
            return;
        const stay = alt && r.runTerm ? r.runTerm() : r.run();
        if (stay !== true)
            done();
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    Column {
        x: root.pad
        y: root.pad
        width: root.innerWidth
        spacing: 10

        Reveal {
            shown: root.shown
            order: 0
            width: root.innerWidth
            implicitHeight: 40

            Rectangle {
                width: root.innerWidth
                height: 40
                radius: 14
                color: Theme.hover
                border.width: 1
                border.color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.22) : Theme.border
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Txt {
                    id: modeGlyph
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({ calc: "󰃬", run: "󰆍", clipboard: "󰅍", prefixes: "󰘳" })[root.mode] ?? "󰍉"
                    color: Theme.faint
                    font.pixelSize: 16
                }

                TextInput {
                    id: input
                    anchors {
                        left: modeGlyph.right
                        leftMargin: 10
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    focus: true
                    color: Theme.fg
                    selectionColor: Qt.rgba(1, 1, 1, 0.25)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    clip: true
                    onTextChanged: root.query = text

                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: root.startMode === "clipboard" ? "Clipboard" : "Buscar apps, digite contas…"
                        color: Theme.faint
                        font.pixelSize: Theme.fontSize + 1
                    }

                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        const n = root.results.length;
                        if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J) || event.key === Qt.Key_Tab) {
                            root.current = n ? (root.current + 1) % n : 0;
                        } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K) || event.key === Qt.Key_Backtab) {
                            root.current = n ? (root.current - 1 + n) % n : 0;
                        } else if (event.key === Qt.Key_PageDown) {
                            root.current = Math.min(n - 1, root.current + root.maxRows);
                        } else if (event.key === Qt.Key_PageUp) {
                            root.current = Math.max(0, root.current - root.maxRows);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.current, event.modifiers & Qt.ShiftModifier);
                        } else if (ctrl && event.key === Qt.Key_D && root.mode === "clipboard") {
                            root.deleteClip(root.results[root.current]);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        ListView {
            id: list
            width: root.innerWidth
            height: Math.min(root.results.length, root.maxRows) * root.rowH
            visible: root.results.length > 0
            clip: true
            interactive: root.results.length > root.maxRows
            boundsBehavior: Flickable.StopAtBounds

            // Diffed by `key`, so results that survive a keystroke move to their
            // new rank instead of being rebuilt.
            model: ScriptModel {
                values: root.results
                objectProp: "key"
            }

            // The selection is `root.current` alone. ListView's own currentIndex
            // is deliberately unused: on every insert/remove above it, ListView
            // shifts currentIndex to follow the old item, which left the
            // highlight parked on the last row while `current` still said 0.
            //
            // Declared as a child, so it lives in the content item and scrolls
            // with the rows. One highlight springs between them.
            Rectangle {
                z: -1
                width: list.width
                height: root.rowH
                radius: 12
                color: Theme.hover
                border.width: 1
                border.color: Theme.border
                y: root.current * root.rowH
                Behavior on y { SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.3 } }
            }

            Connections {
                target: root
                function onCurrentChanged() { list.positionViewAtIndex(root.current, ListView.Contain); }
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                NumberAnimation { property: "opacity"; to: 1; duration: 120 }
            }
            move: Transition {
                NumberAnimation { property: "y"; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
            }

            delegate: Reveal {
                id: row
                required property var modelData
                required property int index

                shown: root.shown
                order: Math.min(index, 8) + 1
                rise: 4
                width: list.width
                implicitHeight: root.rowH

                Item {
                    width: row.width
                    height: root.rowH

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: mouse => root.hoverSelect(this, mouse.x, mouse.y, row.index)
                        onClicked: root.activate(row.index, false)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            IconImage {
                                id: appIcon
                                anchors.fill: parent
                                implicitSize: 26
                                source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                                visible: status === Image.Ready
                            }
                            Txt {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                text: row.modelData.glyph
                                font.pixelSize: 18
                                color: Theme.dim
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            color: row.index === root.current ? Theme.fg : Theme.dim
                            elide: Text.ElideRight
                        }
                        Txt {
                            Layout.maximumWidth: 220
                            text: row.modelData.subtitle ?? ""
                            color: Theme.faint
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
