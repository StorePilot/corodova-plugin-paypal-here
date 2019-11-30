echo "running CDVPayPalHere before_plugin_install hook, setting Podfile iOS version to 9.0 and enabling use_frameworks...";

sed -i.bak 's/platform :ios, \\'\''8.0\\'\''\\n'\'' +/platform :ios, \\'\''9.0\\'\''\\n'\'' +\
            '\''use_frameworks!\\n'\'' +/' "platforms/ios/cordova/lib/Podfile.js" && rm "platforms/ios/cordova/lib/Podfile.js.bak";

