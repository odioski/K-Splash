import QtQuick
import QtQuick.Controls
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property var defaultCategories: [
        "collections",
        "dark",
        "fun",
        "skyline",
        "happy",
        "nature",
        "city"
    ]

    property alias cfg_changeWallpaper: wallpaperCheck.checked
    property alias cfg_intervalMinutes: intervalSpin.value
    property alias cfg_category: categoryCombo.editText
    property alias cfg_customCategories: customCategoriesField.text
    property alias cfg_userCollections: userCollectionsField.text
    property alias cfg_resolutionWidth: widthSpin.value
    property alias cfg_resolutionHeight: heightSpin.value
    property alias cfg_username: usernameField.text
    property alias cfg_password: passwordField.text
    property alias cfg_enableSavedDownloads: saveDownloadCheck.checked
    property alias cfg_downloadDirectory: downloadDirectoryField.text
    readonly property string defaultPicturesPath: StandardPaths.writableLocation(StandardPaths.PicturesLocation)

    function parseCustomCategories(text) {
        return text
            .split(",")
            .map(function(category) {
                return category.trim();
            })
            .filter(function(category, index, categories) {
                return category.length > 0 && categories.indexOf(category) === index;
            });
    }

    function rebuildCategoryModel() {
        var categories = defaultCategories.slice();
        var customCategories = parseCustomCategories(customCategoriesField.text);
        var currentCategory = categoryCombo.editText ? categoryCombo.editText.trim() : "";

        for (var i = 0; i < customCategories.length; i++) {
            if (categories.indexOf(customCategories[i]) === -1) {
                categories.push(customCategories[i]);
            }
        }

        if (currentCategory.length > 0 && categories.indexOf(currentCategory) === -1) {
            categories.unshift(currentCategory);
        }

        categoryCombo.model = categories;
    }

    Kirigami.FormLayout {
        CheckBox {
            id: wallpaperCheck
            Kirigami.FormData.label: "Desktop background"
            text: "Change wallpaper after each refresh"
        }

        SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: "Refresh interval (minutes)"
            from: 1
            to: 1440
        }

        ComboBox {
            id: categoryCombo
            Kirigami.FormData.label: "Category / query"
            editable: true
            model: defaultCategories
            onEditTextChanged: rebuildCategoryModel()
        }

        TextField {
            id: customCategoriesField
            Kirigami.FormData.label: "Saved custom categories"
            placeholderText: "Comma-separated, for example: mountains, night city, minimal"
            onTextChanged: rebuildCategoryModel()
        }

        TextField {
            id: userCollectionsField
            Kirigami.FormData.label: "Collection URLs / IDs"
            placeholderText: "Optional: comma-separated collection URLs, IDs, or slugs"
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
            id: usernameField
            Kirigami.FormData.label: "Unsplash username"
            placeholderText: "Used for collections: https://unsplash.com/@username/collections"
        }

        TextField {
            id: passwordField
            Kirigami.FormData.label: "Password"
            echoMode: TextInput.Password
            placeholderText: "Password"
        }

        CheckBox {
            id: saveDownloadCheck
            Kirigami.FormData.label: "Saved downloads"
            text: "Enable saving the current wallpaper from the widget icon"
        }

        TextField {
            Kirigami.FormData.label: "Download folder"
            enabled: saveDownloadCheck.checked
            id: downloadDirectoryField
            placeholderText: defaultPicturesPath.length > 0
                ? defaultPicturesPath
                : "/home/user/Pictures/K-Splash"
        }
    }

    Component.onCompleted: rebuildCategoryModel()
}
