import QtQuick 6.0
import QtQuick.Controls 6.0
import Qt5Compat.GraphicalEffects
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as P5Support
import "../code/logic.js" as Logic

PlasmoidItem {
    id: root
    width: 220
    height: 250

    property bool busy: false
    property string attributionText: ""
    property string currentDescription: ""
    property string lastStatus: ""
    property int remainingSeconds: plasmoid.configuration.intervalMinutes * 60
    property string currentTempImagePath: ""
    property string currentPhotoId: ""
    property var currentFetchConfig: ({})
    property int currentRetryAttempt: 0
    readonly property int maxImageRetryAttempts: 3

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: openSettings()
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var exitCode = data["exit code"];
            var stderr = data["stderr"];
            var stdout = data["stdout"];
            var errorText = stderr || stdout || "Wallpaper update command failed";

            if (exitCode === 0) {
                lastStatus = "Wallpaper updated";
                currentRetryAttempt = 0;
                busy = false;
            } else if (Logic.shouldRetryImageDownload(errorText)
                    && currentRetryAttempt < maxImageRetryAttempts) {
                currentTempImagePath = "";
                lastStatus = "Image unavailable, trying another photo...";
                refreshNow(currentRetryAttempt + 1, true);
            } else {
                lastStatus = "Error: " + errorText;
                currentRetryAttempt = 0;
                busy = false;
            }

            disconnectSource(sourceName);
        }
    }

    P5Support.DataSource {
        id: fetchExec
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var exitCode = data["exit code"];
            var stderr = data["stderr"];
            var stdout = data["stdout"];

            if (exitCode === 0) {
                handleUnsplashHtml(stdout || "", currentFetchConfig);
            } else {
                busy = false;
                currentRetryAttempt = 0;
                lastStatus = "Unsplash page fetch failed: " + (stderr || stdout || "HTTP request failed");
                clearPhotoDetails();
            }

            disconnectSource(sourceName);
        }
    }

    P5Support.DataSource {
        id: saveExec
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var exitCode = data["exit code"];
            var stderr = data["stderr"];
            var stdout = data["stdout"];

            if (exitCode === 0) {
                lastStatus = "Saved wallpaper copy to " + String(stdout || "").trim();
            } else {
                lastStatus = "Save failed: " + (stderr || stdout || "Unable to copy wallpaper");
            }

            disconnectSource(sourceName);
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        repeat: true
        running: true

        onTriggered: {
            if (remainingSeconds > 0) {
                remainingSeconds--;
            } else {
                refreshNow();
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 10
        width: parent.width - 16

        Rectangle {
            id: iconCard
            width: 118
            height: 118
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 10
            color: "#1a1f2b"
            border.width: 1
            border.color: saveMouseArea.containsMouse && saveMouseArea.enabled ? "#7cc4ff" : "#394055"
            scale: 1.0

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: "#262d3d"
            }

            Rectangle {
                id: flashOverlay
                anchors.fill: parent
                radius: 10
                color: "#bfe6ff"
                opacity: 0.0
            }

            Image {
                id: widgetIcon
                source: Qt.resolvedUrl("../icons/K-Splash.png")
                anchors.centerIn: parent
                width: 96
                height: 96
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Glow {
                anchors.fill: widgetIcon
                source: widgetIcon
                radius: 10
                samples: 17
                color: "#6bc8ff"
                spread: 0.2
                opacity: saveMouseArea.containsMouse && saveMouseArea.enabled ? 0.6 : 0.2
            }

            MouseArea {
                id: saveMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: plasmoid.configuration.enableSavedDownloads
                    && currentTempImagePath.length > 0
                    && !busy

                onClicked: {
                    pulseAnimation.restart();
                    flashAnimation.restart();
                    saveCurrentWallpaper();
                }
            }

            SequentialAnimation {
                id: pulseAnimation
                NumberAnimation { target: iconCard; property: "scale"; to: 1.08; duration: 110 }
                NumberAnimation { target: iconCard; property: "scale"; to: 0.98; duration: 90 }
                NumberAnimation { target: iconCard; property: "scale"; to: 1.0; duration: 110 }
            }

            SequentialAnimation {
                id: flashAnimation
                NumberAnimation { target: flashOverlay; property: "opacity"; to: 0.4; duration: 70 }
                NumberAnimation { target: flashOverlay; property: "opacity"; to: 0.0; duration: 180 }
            }
        }

        Text {
            text: "K-Splash"
            font.pixelSize: 16
            font.bold: true
            color: "#f2f5fb"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: busy
                ? "Updating wallpaper..."
                : (plasmoid.configuration.enableSavedDownloads
                    ? "Auto-refresh KDE wallpaper\nfrom Unsplash\nClick icon to save current wallpaper"
                    : "Auto-refresh KDE wallpaper\nfrom Unsplash")
            font.pixelSize: 11
            color: "#c7d1e3"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.Wrap
        }

        Text {
            text: busy
                ? "Next refresh resets after update"
                : "Next refresh: " + Math.floor(remainingSeconds / 60) + "m " + (remainingSeconds % 60) + "s"
            font.pixelSize: 10
            color: "#8d9ab3"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.Wrap
        }

        Text {
            visible: lastStatus.length > 0
            text: lastStatus
            font.pixelSize: 10
            color: "#b4c1d8"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.Wrap
        }

        Text {
            visible: currentDescription.length > 0
            text: currentDescription
            font.pixelSize: 10
            color: "#d0d6e2"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.Wrap
        }

        Rectangle {
            visible: attributionText.length > 0
            width: parent.width
            height: attributionLabel.implicitHeight + 12
            radius: 8
            color: "#141926"
            border.width: 1
            border.color: "#293145"

            Text {
                id: attributionLabel
                anchors.fill: parent
                anchors.margins: 6
                text: attributionText
                textFormat: Text.RichText
                color: "#7cc4ff"
                linkColor: "#7cc4ff"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                onLinkActivated: function(link) {
                    Qt.openUrlExternally(link);
                }
            }
        }

        Button {
            width: 132
            anchors.horizontalCenter: parent.horizontalCenter
            text: busy ? "Working..." : "Refresh now"
            enabled: !busy
            onClicked: refreshNow()
        }
    }

    function clearPhotoDetails() {
        attributionText = "";
        currentDescription = "";
    }

    function openSettings() {
        var configureAction = Plasmoid.internalAction("configure");

        if (configureAction) {
            configureAction.trigger();
        } else {
            lastStatus = "Settings are unavailable in this launcher";
        }
    }

    function saveCurrentWallpaper() {
        var targetDirectory = plasmoid.configuration.downloadDirectory
            ? String(plasmoid.configuration.downloadDirectory).trim()
            : "";

        if (!plasmoid.configuration.enableSavedDownloads) {
            lastStatus = "Enable saved downloads in settings";
            return;
        }

        if (!targetDirectory || targetDirectory.length === 0) {
            lastStatus = "Set a download folder in settings";
            return;
        }

        if (!currentTempImagePath || currentTempImagePath.length === 0) {
            lastStatus = "Refresh a wallpaper before saving it";
            return;
        }

        lastStatus = "Saving wallpaper copy...";
        var command = Logic.buildSaveCopyCommand(currentTempImagePath, targetDirectory, {
            photoId: currentPhotoId,
            description: currentDescription
        });
        saveExec.connectSource(command);
    }

    function handleUnsplashHtml(html, config) {
        try {
            var details = Logic.extractDomPhotoDetails(html, config, currentRetryAttempt);

            if (!details.imageUrl || details.imageUrl.length === 0) {
                busy = false;
                currentRetryAttempt = 0;
                lastStatus = "Unsplash page did not include an image URL";
                clearPhotoDetails();
                return;
            }

            attributionText = details.attributionMarkup;
            currentDescription = details.description;
            currentPhotoId = details.photoId;
            if (plasmoid.configuration.changeWallpaper) {
                currentTempImagePath = Logic.buildTempFilePath(details.photoId);
                lastStatus = "Downloading image...";
                var cmd = Logic.buildCommand(details);
                exec.connectSource(cmd);
            } else {
                currentTempImagePath = "";
                busy = false;
                currentRetryAttempt = 0;
                lastStatus = "Photo loaded; enable wallpaper updates in settings";
            }
        } catch (e) {
            busy = false;
            currentRetryAttempt = 0;
            lastStatus = "Parse error: " + e;
            clearPhotoDetails();
        }
    }

    function refreshNow(retryAttempt, preserveCountdown) {
        var nextRetryAttempt = retryAttempt || 0;
        var keepCountdown = preserveCountdown === true;

        busy = true;
        currentRetryAttempt = nextRetryAttempt;
        lastStatus = "Loading Unsplash page...";
        if (!keepCountdown) {
            remainingSeconds = plasmoid.configuration.intervalMinutes * 60;
        }

        var config = {
            category: plasmoid.configuration.category,
            customCategories: plasmoid.configuration.customCategories,
            resolutionWidth: plasmoid.configuration.resolutionWidth,
            resolutionHeight: plasmoid.configuration.resolutionHeight
        };

        var url = Logic.buildUnsplashDomUrl(config, nextRetryAttempt);
        currentFetchConfig = config;
        fetchExec.connectSource(Logic.buildDomFetchCommand(url));
    }

    Component.onCompleted: {
        remainingSeconds = plasmoid.configuration.intervalMinutes * 60;
    }
}
