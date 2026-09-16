# A510Player CarPlay Stage 4 (experimental)

Baseline Stage 3 RTSP/H.264 player is preserved.

This build adds:
- CarPlay framework linkage
- a CarPlay template scene declaration
- `CarPlaySceneDelegate`
- an experimental attempt to attach `PlayerViewController` to the CarPlay-provided `CPWindow`

Test on the jailbroken phone with wired CarPlay. The first goal is to determine whether
A510Player becomes launchable on CarPlay and whether the CarPlay window accepts the UIKit renderer.
