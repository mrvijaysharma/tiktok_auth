# The TikTok OpenSDK is compiled with the Kotlin Parcelize plugin. Its classes
# reference Parcelize annotations that are not needed at runtime and are not
# declared as dependencies in the SDK's POM.
-dontwarn kotlinx.parcelize.**
