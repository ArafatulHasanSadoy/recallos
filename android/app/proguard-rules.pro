# google_mlkit_text_recognition's plugin references a recognizer class for every
# script ML Kit supports — Chinese, Devanagari, Japanese, Korean — and picks one
# at runtime. We only depend on the Latin bundle, so the other four classes are
# genuinely absent and R8 fails the build over it.
#
# Suppressing rather than adding the dependencies is deliberate: each script
# bundle is several MB, and RecallOS is Latin-only by design (see the plan's
# "Future work: other languages"). The code path that would touch them is never
# reached, because the OCR engine always requests Script.latin.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit finds its components by reflection, and R8 cannot see that it does.
#
# Each ML Kit module ships a manifest entry of the form
#
#   <meta-data android:name="com.google.firebase.components:com.google.mlkit.vision.text.internal.TextRegistrar"/>
#
# and the runtime instantiates the class named in that *attribute*. R8 keeps
# classes named as manifest components — services, providers, activities — but
# a class name buried in a meta-data name attribute is just a string to it, so
# the registrars were being renamed and the reflective lookup returned null.
# The result was a NullPointerException deep inside minified ML Kit and, from
# the outside, OCR silently returning zero blocks in release builds while
# working perfectly in debug. Nothing failed loudly; every scan just came back
# empty.
#
# Keeping the registrars by interface rather than by name covers the three in
# use today (Common, VisionCommon, Text) and any that arrive with a future ML
# Kit dependency — the document scanner included.
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keep class com.google.mlkit.common.internal.MlKitComponentDiscoveryService { *; }
-keep class com.google.mlkit.common.internal.MlKitInitProvider { *; }
