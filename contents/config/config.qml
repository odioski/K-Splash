import QtQuick 6.0
import QtQuick.Controls 6.0
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: root

    property alias cfg_intervalMinutes: intervalSpin.value
    property alias cfg_category: categoryField.text
    property alias cfg_resolutionWidth: widthSpin.value
    property alias cfg_resolutionHeight: heightSpin.value
    property alias cfg_unsplashAccessKey: keyField.text

    Kirigami.Heading {
        text: "Unsplash Settings"
        level: 3
    }

    SpinBox {
        id: intervalSpin
        Kirigami.FormData.label: "Refresh interval (minutes)"
        from: 1
        to: 1440
    }

    TextField {
        id: categoryField
        Kirigami.FormData.label: "Category / query"
        placeholderText: "e.g. nature, city, mountains"
    }

    SpinBox {
        id: widthSpin
        Kirigami.FormData.label: "Resolution width"
        from: 640
        to: 7680
    }

    SpinBox {
        id: heightSpin
        Kirigami.FormData.label: "Resolution height"
        from: 480
        to: 4320
    }

    TextField {
        id: keyField
        Kirigami.FormData.label: "Unsplash Access Key"
        placeholderText: "Paste your Unsplash API access key"
        echoMode: TextInput.Password
    }
}
