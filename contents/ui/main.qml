import QtQuick 6.0
import QtQuick.Controls 6.0
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as P5Support
import "../code/logic.js" as Logic

PlasmoidItem {
    id: root
    width: 220
    height: 180

    property bool busy: false
    property string attributionText: ""
    property string currentDescription: ""
    property string lastStatus: ""
    property string localAccessKey: ""
    property int remainingSeconds: plasmoid.configuration.intervalMinutes * 60

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var exitCode = data["exit code"];
            var stderr = data["stderr"];
            lastStatus = exitCode === 0 ? "Wallpaper updated" : ("Error: " + stderr);
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
        spacing: 4
        width: parent.width - 16

        Image {
            source: "image://icon/com.mrod.k-unsplashwidget"
            width: 32
            height: 32
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: busy ? "Updating wallpaper..." : "K-Unsplash Widget"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: "Next refresh: " + Math.floor(remainingSeconds / 60) + "m " + (remainingSeconds % 60) + "s"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: lastStatus
            font.pixelSize: 10
            color: "#aaaaaa"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.Wrap
        }

        Text {
            visible: currentDescription.length > 0
            text: currentDescription
            font.pixelSize: 10
            color: "#d0d0d0"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.Wrap
        }

        Text {
            visible: attributionText.length > 0
            text: attributionText
            textFormat: Text.RichText
            color: "#7cc4ff"
            linkColor: "#7cc4ff"
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.Wrap
            onLinkActivated: function(link) {
                Qt.openUrlExternally(link);
            }
        }

        Button {
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
                        lastStatus = "Downloading image...";
                        var cmd = Logic.buildCommand(details.imageUrl);
                        exec.connectSource(cmd);
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
