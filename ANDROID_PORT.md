# Android Compatibility source snapshot

This unofficial fork preserves the Android-focused work on [Picnic in the Oblivion by Lekksii](https://github.com/Lekksii/picnic-in-the-oblivion), a remake of S.T.A.L.K.E.R. Mobile 3D.

## Recover the published source

Use branch `android-compatibility` or tag `android-compatibility-2026-10-04`. Both identify exact source commit `6516757d41739c7714759d7f2d163a553fa27ed3`. GitHub's release ZIP and tarball contain that frozen source. The `android-port` default branch adds only this documentation, a README introduction and the ownership notice.

Use **Godot 4.7.2 stable**, specifically `4.7.2.stable.official.ed1daf0bf`, with matching export templates. Import the project to regenerate Godot's local cache. Source-side `.import` descriptors and `.uid` metadata are retained; generated `.godot` data and signing credentials are excluded. Supply your own local signing credentials if you independently build an Android package.

## Included Android work

- Touch controls with independent simultaneous look, firing and interaction; automatic weapon hold-to-fire and weapon/reload gestures.
- Fullscreen and aspect handling, HUD layout fixes, touch-friendly menus, map/Back navigation and options scrolling.
- Android Help and English, Russian and Ukrainian localization updates.
- Adjustable world FOV that preserves held-weapon presentation, plus saved-game loading and UI/gameplay polish.
- Android lighting and muzzle-illumination work, with Compatibility-specific flashlight and lens-halo rendering and selected foliage lighting adaptations.
- Normal progress saving and writable, persistent settings.

## Configuration and limits

This snapshot uses the **Compatibility renderer** on Android and supports **x86_64**, alongside ARMv7 and ARM64, primarily for compatible emulator/BlueStacks environments. Desktop retains Forward+. The canonical Mobile/Vulkan phone configuration is separate and is not the source release published here.

An earlier Compatibility configuration ran in BlueStacks. Later foliage changes in this frozen snapshot have not received complete gameplay verification, and broad device support and sustained performance are not certified. The separately developed Mobile dithering correction is not included in this snapshot.

No APK is distributed with this release. This publication does not configure automatic synchronization, deployment or future updates.

## Attribution

Original project: [Lekksii/picnic-in-the-oblivion](https://github.com/Lekksii/picnic-in-the-oblivion). The upstream README's attribution to QPlaze, GSC and Nomoc is preserved. See [NOTICE.md](NOTICE.md); no new software license is applied to upstream code or third-party assets.
