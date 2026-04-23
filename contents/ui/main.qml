import QtQuick 6.0
import QtQuick.Controls 6.0
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
    property string localAccessKey: ""
    property int remainingSeconds: plasmoid.configuration.intervalMinutes * 60

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var exitCode = data["exit code"];
            var stderr = data["stderr"];
            var stdout = data["stdout"];
            var errorText = stderr || stdout || "Wallpaper update command failed";
            lastStatus = exitCode === 0 ? "Wallpaper updated" : ("Error: " + errorText);
            busy = false;
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
            width: 118
            height: 118
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 10
            color: "#1a1f2b"
            border.width: 1
            border.color: "#394055"

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: "#262d3d"
            }

            Image {
                source: Qt.resolvedUrl("../icons/com.mrod.k-splash.png")
                anchors.centerIn: parent
                width: 96
                height: 96
                fillMode: Image.PreserveAspectFit
                smooth: true
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
                : "Auto-refresh KDE wallpaper\nfrom Unsplash"
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

    function activeAccessKey() {
        if (plasmoid.configuration.unsplashAccessKey
                && plasmoid.configuration.unsplashAccessKey.length > 0) {
            return plasmoid.configuration.unsplashAccessKey;
        }

        return localAccessKey;
    }

    function loadLocalConfig() {
        try {
            var request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("../config/local.json"), false);
            request.send();

            if ((request.status !== 0 && request.status !== 200) || !request.responseText) {
                return;
            }

            var json = JSON.parse(request.responseText);
            if (json.unsplashAccessKey) {
                localAccessKey = String(json.unsplashAccessKey).trim();
            }
        } catch (e) {
            // Local config is optional.
        }
    }

    function trackDownload(downloadLocation, accessKey) {
        if (!downloadLocation || downloadLocation.length === 0) {
            return;
        }

        try {
            var trackingRequest = new XMLHttpRequest();
            trackingRequest.open("GET", downloadLocation);
            trackingRequest.setRequestHeader("Accept-Version", "v1");
            trackingRequest.setRequestHeader("Authorization", "Client-ID " + accessKey);
            trackingRequest.send();
        } catch (e) {
            // Download tracking is advisory; wallpaper updates should continue.
        }
    }

    function refreshNow() {
        var accessKey = activeAccessKey();

        if (!accessKey || accessKey.length === 0) {
            lastStatus = "Set Unsplash Access Key in settings";
            return;
        }

        busy = true;
        lastStatus = "Contacting Unsplash...";
        remainingSeconds = plasmoid.configuration.intervalMinutes * 60;

        var config = {
            category: plasmoid.configuration.category,
            resolutionWidth: plasmoid.configuration.resolutionWidth,
            resolutionHeight: plasmoid.configuration.resolutionHeight
        };

        var url = Logic.buildUnsplashRequestUrl(config);

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Accept-Version", "v1");
        xhr.setRequestHeader("Authorization", "Client-ID " + accessKey);

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var json = JSON.parse(xhr.responseText);
                        var photo = (json instanceof Array) ? json[0] : json;
                        var details = Logic.extractPhotoDetails(photo, config);

                        if (!details.imageUrl || details.imageUrl.length === 0) {
                            busy = false;
                            lastStatus = "Unsplash did not return an image URL";
                            clearPhotoDetails();
                            return;
                        }

                        attributionText = details.attributionMarkup;
                        currentDescription = details.description;
                        trackDownload(details.downloadLocation, accessKey);
                        if (plasmoid.configuration.changeWallpaper) {
                            lastStatus = "Downloading image...";
                            var cmd = Logic.buildCommand(details);
                            exec.connectSource(cmd);
                        } else {
                            busy = false;
                            lastStatus = "Photo loaded; enable wallpaper updates in settings";
                        }
                    } catch (e) {
                        busy = false;
                        lastStatus = "Parse error: " + e;
                        clearPhotoDetails();
                    }
                } else {
                    busy = false;
                    lastStatus = Logic.buildApiErrorMessage(xhr.responseText, xhr.status);
                    clearPhotoDetails();
                }
            }
        };

        xhr.send();
    }

    Component.onCompleted: {
        loadLocalConfig();
        remainingSeconds = plasmoid.configuration.intervalMinutes * 60;
    }
}
